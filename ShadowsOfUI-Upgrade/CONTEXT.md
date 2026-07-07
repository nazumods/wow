# ShadowsOfUI-Upgrade

**Deps:** LibNAddOn, Warbandeer_Characters · **OptionalDeps:** ClassCodex (per-spec enchant source) · **SavedVars:** none · **Commands:** `/supgrade [name]` (dev dump), `/supgrade enchants [name]` (enchant-resolution dump) · **API:** reads `WarbandeerApi` (+ ClassCodex's global `ClassCodexGearData` when present), publishes `ShadowsOfUI_UpgradeApi`

Headless logic + tooltip addon. Computes per-character gear upgrades from the data layer
(equipped gear + loose gear in bags / personal bank / warband bank), plus future-action sources
— active world-quest rewards and bundled faction-quartermaster gear — gated by item level and
annotated with spec stat-priority fit. Also flags **missing permanent enchants** (parsed from the stored item
link), **wrong (non-recommended) enchants** (the stored applied-enchant name vs the recommendation),
and **empty gem sockets** (from the data layer's stored per-slot count) on equipped gear, all
warband-wide, and recommends the enchant/gem to apply (ClassCodex per-spec when installed, else a
bundled fallback). Assignment-form init (`local ns = LibNAddOn(...)`); no
LibNUI. The stat-priority and quartermaster-gear tables are small built-ins (`ns.StatPriority`,
`ns.VendorGear`), so the addon is fully standalone.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Bootstrap. `ns.api` = `WarbandeerApi` (X-NUI-API, consumed); creates + publishes the global `ShadowsOfUI_UpgradeApi` (`ns.UpgradeApi`); seeds `ns.StatPriority` |
| `changelog.lua` | `ns.changelog` — newest-first `{version, notes}` release history for the in-game **Changelog** viewer (LibNAddOn). **Generated** — `release.sh` prepends each release; not hand-edited |
| `data/statpriority.lua` | `ns.StatPriority[classToken] = { [specIndex] = { crit, haste, mastery, versatility } }` = stat→tier (1 = top), each class an array in `GetSpecialization()` index order. Precomputed offline from PvE secondary-stat weightings (ties within ~15% share a tier); the only stat data the addon carries |
| `data/primarystat.lua` | `ns.ClassPrimary[classToken] = { [specIndex] = "str"\|"agi"\|"int" }` — primary stat per spec, same array layout as `ns.StatPriority`. Gates out wrong-primary gear (an Intellect dagger for a Rogue) that class proficiency alone lets through |
| `data/classgear.lua` | `ns.ClassGear[classKey] = { shield, weapons = {[subClassID]=true} }` — bundled weapon/shield proficiency baseline (armour *type* comes from `ns.wow.Armor.byClass`, not repeated here) |
| `data/vendorgear.lua` | `ns.VendorGear` = bundled list of the expansion's faction-quartermaster gear pieces (`VendorGearEntry[]`); one entry per slot/quartermaster, each carrying `options` (armour-type variants / stat alternatives) + `quartermaster`/`zone`/`mapID`/`cost`/`ilvl`/`reqLevel`/`equipLoc`. Static game data, **regenerate each season** (note in-file) |
| `data/enchantslots.lua` | `ns.EnchantableSlots` = set of equipment-slot names that take a permanent enchant this expansion. Midnight (12.0.x): Head/Shoulder/Chest/Legs/Feet/Finger1/Finger2/MainHand — **Head/Shoulder are in, Back(cloak)/Wrist(bracer) are out** (Enchanting has no recipe for them); Legs stays (its enchant is a Tailoring/LW spellthread, not an Enchanting recipe). **Verify each expansion** — the set drifts. OffHand is deliberately absent (`enchants.lua` gates it on the equipped item being a weapon, not a shield/holdable). `enchants.lua`'s `ENCHANT_ORDER` is a top-down superset (Head→OffHand) gated against this set, so a listed-but-unenchantable slot is simply skipped |
| `data/gems.lua` | `ns.Gems` = the **fallback** recommended gem (used only without ClassCodex, whose per-spec primary gem is preferred). `byStat` maps a secondary stat → cut-gem itemId (Midnight "Flawless" gems; adjective = stat). ClassCodex's primary gem is role-specific so we don't mirror it; the fallback offers a universal secondary-stat gem by top stat. **Regenerate each season** |
| `data/enchants.lua` | `ns.Enchants` = the **fallback** recommended enchant per **canonical** enchant slot (used only when ClassCodex isn't installed; CC's per-spec data is preferred — see `enchants.lua`). (both rings → `Finger`, both weapons → `Weapon`; `enchants.lua`'s `ENCHANT_KEY` maps equipped slots onto these). Each row is either `byStat = { haste=id, crit=id, mastery=id, versatility=id }` (resolver picks the variant for the character's top secondary via `ns.StatRanks`) or `fixed = id` (non-variant slots — weapon proc/utility enchants, a primary-stat leg kit). Also exports **`ns.EnchantMinIlvl`** — the single season-wide floor (Midnight = 120): the lowest item level *any* enchant applies to, so an equipped item below it is **neither flagged as missing nor recommended** (can't be enchanted), for **every** enchantable slot — including Head/Shoulder/Legs/Feet, which carry no bundled stat pick. Gated via `ns.BelowEnchantMinIlvl(item)` (in `classcodex.lua`). `id` is the **enchanting recipe spellID**; names resolve live (`GetSpellInfo`) at the surface, so nothing is hardcoded/locale-bound. **Regenerate each season** — harvest live recipe ids in-game (see Gotchas → "Refreshing `ns.Enchants`"); **bump `ns.EnchantMinIlvl` per expansion** too. A slot absent here yields no recommendation |
| `resolve.lua` | `ns.StatRanks(charData)` → the spec's `{stat=tier}` table (or nil); `ns.PrimaryStat(charData)` → `"str"`/`"agi"`/`"int"` (or nil). Both via a lazily-built `specID → {token, index}` map (`GetSpecializationInfoForClassID`) indexing into `ns.StatPriority` / `ns.ClassPrimary` |
| `equip.lua` | `ns.CompetingSlots(equipLoc)` → equipment-slot names an item contests; `ns.CanEquip(classKey, equipLoc, classID, subClassID)` → armour-type / shield / weapon-proficiency check; `ns.IsTwoHand(equipLoc)` + `ns.WeaponRole(equipLoc)` → `"mh1h"`/`"mh2h"`/`"off"`/nil for the 2H ↔ dual-wield reconciliation |
| `evaluate.lua` | **Single-candidate evaluation primitives**, published on `ns` for `upgrade.lua` (aggregation) + `upgradesources.lua` (external sources). `ns.Evaluate(charData, cand)` → `(slot, ilvlGain, candIlvl)` or nil: the core test — `candInfo`/`ClassifyGearItem` → `ns.CanEquip` (proficiency) → `primaryFits` (`ns.PrimaryStat` match) → `ns.CompetingSlots` → upgrade iff candidate ilvl > the **lowest** equipped ilvl among competing slots (empty slot = 0). `ns.StatTag(link, ranks)` → `"good"`/`"off"`/nil (carries a tier-1 secondary?). `ns.EquippedTwoHand(charData)` (main hand holds a 2H — `slotEquipLoc`/`slotSubClass` fall back to `GetItemInfoInstant` for pre-equipLoc cached alts; a **wand** is excluded, being one-handed despite sharing `INVTYPE_RANGEDRIGHT` with guns/crossbows). `ns.EquippedDualTwoHand(charData)` (both hands hold a 2H — a Titan's-Grip Fury warrior). `ns.EvaluateExternal(charData, cand, twoHander)` (= `ns.Evaluate` + the lone-item 2H guard, for WQ/vendor candidates). `ns.PickHeadline` (prefer held; a strictly-higher warband copy wins + flags `betterElsewhere`). `ns.ResolveTwoHand(...)` (the 2H ↔ dual-wield reconciliation — see Algorithm). `isArtifact`/`primaryFits`/`candInfo` stay file-local (used only here + `ResolveTwoHand`). |
| `upgrade.lua` | **Per-character aggregation** + the held/warband published API. `computeUpgrades` collects the best held-vs-warband candidate per slot (`ns.Evaluate` → `ns.PickHeadline` → `ns.StatTag`), routing both weapon slots through `ns.ResolveTwoHand` when the character wields a 2H; a ~2s per-character memo (`cachedUpgrades`) so a view's per-slot calls compute once. Publishes `SlotUpgrade`/`CharacterUpgrades`/`CharacterUpgradeCount` |
| `upgradesources.lua` | **External-source published API** — `WorldQuestUpgrades` (reads `WarbandeerApi:GetWorldQuestRewards`), `VendorUpgrades` (`pickVendorOption` over the bundled `ns.VendorGear`, `reqLevel`-gated), and `ItemUpgrades` (the tooltip "upgrades `<alt>`" check; `boundTo` soulbound restriction + the lone-item 2H guard). Each runs candidates through `evaluate.lua`'s `ns.EvaluateExternal`/`ns.Evaluate` + `ns.StatTag` so they're held to the same bar as held/warband gear |
| `classcodex.lua` | **ClassCodex resolution layer + shared enchant/gem gates**, published on `ns` for `enchants.lua`/`gems.lua`. The two gates **every** enchant/gem surface consults: `ns.BelowMaxLevel(charData)` (still-levelling → suppress all surfaces; also used by `tooltip.lua`) and `ns.BelowEnchantMinIlvl(item)` (equipped item below `ns.EnchantMinIlvl` → can't be enchanted; gates only when ilvl is known). `ns.PickStat(ranks, byStat)` picks the top secondary among offered variants (`STAT_ORDER` tie-break). The CC layer — `ccClassSpec` (builds the `(CLASSTOKEN, specKey)` keys: classKey upper-cased; spec name lower-with-hyphens from the persisted numeric `id` via `GetSpecializationInfoByID`, **else** the stored `active`/`primary` name — prefers played over loot spec; locale-dependent), `ccNormalize`+`CC_SLOT`+`CC_ALIAS` (collapse "Ring"/"Rings"/"Boots"/"Helm"→canonical) — behind `ns.ClassCodexEnchant(charData, slot)` → `(name, itemId)` and `ns.ClassCodexGems(charData)` → the `.gems` table; both type-check every level and return nil on any shape mismatch (callers fall back to the bundled tables). `ns.StatTargets` (+ the published `StatTargets`/`StatRanks` wrappers) and `ns.ClassCodexConsumables(charData)` → the spec's raw `.consumables` block (`{ flask, combatPotion, food, weaponBuff, augmentRune }`, each `{ itemId, name }`) or nil — **wowhead-source-only** (the `ClassCodexGearData` global; Archon/IcyVeins globals carry no consumables), **no bundled fallback**, published as `Upgrade:RecommendedConsumables`. Defines the `EnchantSuggestion` type. `ns.DumpEnchants(charData)` → the `/supgrade enchants` text block (resolved class/spec key, CC presence, every CC enchant entry as **raw slot → `ccNormalize` → pick**, each missing-enchant slot → its recommendation) — reuses the real helpers so it mirrors live resolution |
| `enchants.lua` | **Enchant detection + recommendation + wrong-enchant detection** + their published API, gated on `ns.BelowMaxLevel`/`ns.BelowEnchantMinIlvl`. `ns.ItemEnchantID(link)` parses field 2 of the itemString (0 = unenchanted). `ns.MissingEnchants(charData)` walks equipped slots in a stable order → `{ slot, link }` for each enchantable slot whose link carries no enchant (pure string parse → warband-wide; off-hand counts only when it holds a weapon, `WEAPON_EQUIPLOC`; a slot below `ns.EnchantMinIlvl` is skipped). `ns.RecommendedEnchant(charData, slot)` → `EnchantSuggestion?`: **prefers** `ns.ClassCodexEnchant`, **falls back** to the bundled `ns.Enchants` recipe (maps the slot via `ENCHANT_KEY`; a `fixed` recipe or the `byStat` variant for the top secondary via `ns.PickStat`/`ns.StatRanks`). `ns.EnchantMismatches(charData)` → equipped slots whose **applied** enchant name (captured by Warbandeer_Characters into `equipment.slots[slot].enchant`) differs from the recommendation, each `{ slot, link, itemID, enchantID, applied, recommended }`. Compares via `normEnchant` (strips the "Enchant <Slot> - " prefix then lowercases/collapses whitespace; rank/quality-tier variants share a name so aren't flagged). **Spellthreads (leg enchants)** capture as a *stat line* ("+41 Intellect & +115 Stamina") not a name — `isStatLine` detects them and `statLineMatches` compares stat magnitudes against the recommendation's tooltip (`recTooltipLines`: a CC item's `C_TooltipInfo.GetItemByID` lines, gated on `C_Item.IsItemDataCachedByID` first so an **uncached** scroll is "can't judge"→not flagged + `RequestLoadItemDataByID`'d, the "refresh twice and it clears" #236; or a bundled spell's `C_Spell.GetSpellDescription`); an unresolvable tooltip is never flagged. Digit-group separators are stripped from both the applied line and the tooltip before the magnitude compare (`stripSeparators` — `LARGE_NUMBER_SEPERATOR` + `,`/`.`), so a stat ≥ 1,000 (or a grouping locale) reads as one number, not split fragments. `suggestionName` resolves a name (CC `.name` / spell `GetSpellName` / item `GetItemInfo`). Publishes `MissingEnchants`/`RecommendedEnchant`/`EnchantMismatches` |
| `gems.lua` | **Empty-socket detection + gem recommendation** + their published API, gated on `ns.BelowMaxLevel`. `ns.MissingGems(charData)` → `{ slot, link, sockets }[]` (equipped slots with ≥1 empty socket, from the stored `emptySockets` count — warband-wide but only as fresh as the last scan). `ns.RecommendedGems(charData)` → `primary, secondary` (two `EnchantSuggestion`s): the **primary** "diamond" (primary stat, **unique-equipped — socket one**) and a repeatable **secondary** fill gem. ClassCodex supplies both (`ns.ClassCodexGems` → `.gems.primary` + `.gems.secondary[1]` via `ccGem`); the bundled fallback returns `nil` primary + the `ns.Gems.byStat` top-stat gem (`ns.PickStat`). Publishes `MissingGems`/`RecommendedGems` |
| `tooltip.lua` | `ns:OnItemTooltip` (LibNAddOn) "Upgrade for:" block + an orange "Missing enchant" line when the hovered item is one of the **player's own equipped** enchantable items with no enchant (`equippedMissingSlot` — matches the displayed link against the live `GetInventoryItemLink` of each enchantable inventory slot, returning that slot; never fires on a loose bag/vendor copy; off-hand gated on holding a weapon). The line gains a "— recommend `<enchant>`" tail (`missingEnchantLine` → `ns.RecommendedEnchant` for the logged-in char, name via `GetSpellName`) when the bundled table has a pick. Also an **"Empty socket"** line for the player's own equipped item with an unfilled socket (`equippedEmptySockets` — `GetItemNumSockets` minus gemmed sockets via `GetItemGemID`, gated to equipped; **not** the `GetItemStats` `EMPTY_SOCKET_*` keys, which the Midnight Gem Manager leaves set on items it has gemmed) + a "— recommend `<gem>`" tail (`emptySocketLine` → `ns.RecommendedGems`, using the **secondary** fill gem — a lone item tooltip can't know if the one diamond is already placed elsewhere). Both reminder lines are gated on the logged-in character being max level (`ns.BelowMaxLevel`), mirroring the `ns.*` surfaces — the cross-character "Upgrade for:" block is unaffected. The missing-enchant line is **also** gated on `ns.BelowEnchantMinIlvl` (the tooltip's own `effectiveIlvl`), so a legacy sub-floor piece doesn't show a bare "Missing enchant" with no pick — matching `ns.MissingEnchants`' floor for the views. `/supgrade [name]` dev dump (upgrades); `/supgrade enchants [name]` → `ns.DumpEnchants` in a copyable `LibNUI.ShowCopyWindow` (LibNUI loaded transitively; falls back to chat) |
| `spec/upgrade.lua` | Busted harness: loads data + `resolve`/`equip`/`evaluate`/`upgrade`/`upgradesources`/`classcodex`/`enchants`/`gems` into a fresh `ns` with stubbed WoW globals (`C_Item`, `Enum`, `GetTime`, spec-info fns) and a fake `WarbandeerApi`. `up.harness()` returns `{ ns, Api, api, defItem, addChar, pools, warband, advance }`. Skips `core.lua` (LibNAddOn bootstrap) + `tooltip.lua` (frames). The `FILES` list must mirror the `.toc` load order when files are added/split |
| `spec/equip_spec.lua` | `CompetingSlots` / `IsTwoHand` / `WeaponRole` / `CanEquip` (armour-type, shield, weapon-proficiency gating) |
| `spec/resolve_spec.lua` | `StatRanks` / `PrimaryStat` spec-ID → tier/primary resolution |
| `spec/enhance_spec.lua` | `ItemEnchantID` link parsing (enchant id / 0 / nil / bare itemString), `MissingEnchants` (slot-order output, non-enchantable slots ignored, empty slots skipped, off-hand weapon flagged but shield/holdable not), the published `Upgrade:MissingEnchants` name resolution, and `RecommendedEnchant` — the bundled path (stat-variant pick from spec priority, Finger1/2 + MainHand/OffHand canonical-key mapping, `fixed` spec-independent, nil for unknown-spec variant slot / unbundled slot, next-best-stat fallback, **nil when the equipped item is below `ns.EnchantMinIlvl`** — and `MissingEnchants` skips that slot, including utility-only slots with no bundled pick (Head/Legs), while an unknown-ilvl item stays ungated) **and** the ClassCodex source (per-spec pick overrides bundled, singular/plural slot tolerance, weapon mapping, graceful fallback when CC's global is absent or malformed); plus `MissingGems` (empty-socket slot list from stored counts, order, ignores no-data slots) and `RecommendedGems` (bundled → nil primary + top-stat secondary; ClassCodex → primary diamond + first secondary; nil/nil when spec unknown + no CC) and `ClassCodexConsumables`/`Upgrade:RecommendedConsumables` (the spec's `.consumables` block from CC; nil without CC, nil on a malformed block, named-char resolution + nil for unknown char) |
| `spec/upgrade_spec.lua` | End-to-end published API: ilvl gating, equip/primary filters, multi-slot weaker-slot targeting, held-vs-warband (`betterElsewhere`), `statTag` good/off, sort/count, memo TTL, two-hand reconciliation, the one-hander guard (off-hand wielder never offered a 2H; 1H still upgrades; tooltip path), `ItemUpgrades` (soulbound `boundTo`, 2H lone-off-hand exclusion), `WorldQuestUpgrades` (ilvl gating, equip/primary filters, multi-slot, 2H guard, sort + quest metadata; harness `addWQ` / fake `GetWorldQuestRewards`), `VendorUpgrades` (ilvl gating, `reqLevel` player-level gating, armour-type/neck option pick, multi-slot, 2H guard, statTag, sort + purchase metadata; harness `addVendor` / synthetic `ns.VendorGear`) |

## `ShadowsOfUI_UpgradeApi`

```lua
ShadowsOfUI_UpgradeApi:SlotUpgrade(charName, slot)      → UpgradeResult|nil
    -- best available upgrade for one equipment slot (Head, Finger1, MainHand, …)
ShadowsOfUI_UpgradeApi:CharacterUpgrades(charName)      → UpgradeResult[]   (sorted by ilvlGain desc)
ShadowsOfUI_UpgradeApi:CharacterUpgradeCount(charName)  → integer
ShadowsOfUI_UpgradeApi:WorldQuestUpgrades(charName)     → WorldQuestUpgrade[]
    -- active world-quest gear rewards that would upgrade an equipped slot, sorted
    -- by ilvl gain.  Reads WarbandeerApi:GetWorldQuestRewards (the data layer's
    -- per-character WQ cache, already expiry-filtered) and runs each reward through
    -- the same `evaluate` the held/warband finder uses (proficiency, primary-stat,
    -- multi-slot targeting, two-hand guard, statTag).  WorldQuestUpgrade = UpgradeResult
    -- + { questID, title, zone, mapID } (no `where`/`betterElsewhere`); mapID drives
    -- the Suggested box's click-to-open-map.  Empty on an older data layer without
    -- GetWorldQuestRewards.
ShadowsOfUI_UpgradeApi:VendorUpgrades(charName)         → VendorUpgrade[]
    -- faction-quartermaster gear pieces that would upgrade an equipped slot, sorted
    -- by ilvl gain.  Reads the bundled `ns.VendorGear` (no data-layer cache); per
    -- entry picks the best option the character can equip (CanEquip → armour type
    -- for body slots, every option for necks) then the best stat fit, and runs it
    -- through the same `evaluate` (+ two-hand guard, statTag) as the other sources.
    -- A piece gated above the character's level (entry.reqLevel vs basic.level) is
    -- skipped — not viable until they ding into it.
    -- VendorUpgrade = UpgradeResult + { quartermaster, zone, mapID, cost } (no
    -- `where`/`betterElsewhere`); mapID drives the Suggested box's click-to-open-map.
    -- A character already equal-or-better in every slot yields nothing.
ShadowsOfUI_UpgradeApi:MissingEnchants(charName)       → { slot, link }[]
    -- equipped slots that should carry a permanent enchant but don't, in a stable
    -- slot order.  Reads only the stored item link (enchant id is encoded in it), so
    -- it works warband-wide for every character, not just the one logged in.  The
    -- off-hand counts only when it holds a weapon.  Consumers: Warbandeer's Detail
    -- gear-row "Missing enchant" note + Summary "Ench" column (warband-wide, via
    -- ns.MissingEnchantSlots), and this addon's own tooltip line (live equipped).
ShadowsOfUI_UpgradeApi:RecommendedEnchant(charName, slot)  → EnchantSuggestion?
    -- which enchant to apply to a slot, as { kind="item"|"spell", id, name?, stat? }.
    -- Prefers ClassCodex's per-spec pick (OptionalDep, read live from its global) and
    -- falls back to the bundled stat-derived recipe; nil when neither has one.  Resolve
    -- a display name from `.name` (ClassCodex carries it) else `.id` via GetSpellName
    -- (spell) / GetItemInfo (item).  Pairs with MissingEnchants (which slots are bare)
    -- to say which enchant to put on each.  Consumers: the tooltip "— recommend
    -- <enchant>" tail + Warbandeer's Detail note and Summary "Ench" hover (via
    -- Warbandeer's ns.RecommendedEnchant, which resolves the suggestion to a name).
ShadowsOfUI_UpgradeApi:StatRanks(charName)             → { stat = tier }?
    -- the spec's secondary-stat priority map (tier 1 = top), or nil when unknown.
    -- Lets a consumer highlight a character's best secondary (Warbandeer's Detail
    -- stat grid tints the tier-1 stat gold).
ShadowsOfUI_UpgradeApi:RecommendedConsumables(charName) → table?
    -- ClassCodex's recommended consumables for the spec, as the raw `.consumables` block:
    -- { flask = { itemId, name }, combatPotion = {...}, food, weaponBuff, augmentRune }.
    -- nil when ClassCodex isn't installed or has no data for the spec (NO bundled fallback —
    -- consumables are a ClassCodex-only surface, wowhead source). The consumer maps the known
    -- keys to display labels (Warbandeer's Detail Consumables box, each category toggleable).
ShadowsOfUI_UpgradeApi:StatTargets(charName, context?) → { stat = rating }?
    -- ClassCodex's Archon stat-rating targets for the spec (context = "Mythic+"
    -- default / "Raid"), or nil.  Same rating scale as the stored combat rating, so a
    -- consumer can show current/target (Warbandeer's Detail grid shows "571 / 869",
    -- status-coloured ±5%).  From the `ClassCodexArchonStats` global (OptionalDep).
ShadowsOfUI_UpgradeApi:MissingGems(charName)           → { slot, link, sockets }[]
    -- equipped slots with empty gem sockets, from the data layer's stored per-slot
    -- count (captured at scan time while the item is loaded).  Warband-wide, but a
    -- slot socketed since that character last logged in won't reflect until rescan.
ShadowsOfUI_UpgradeApi:EnchantMismatches(charName)     → { slot, link, itemID, enchantID, applied, recommended }[]
    -- equipped slots whose APPLIED enchant differs from the recommendation (a "wrong",
    -- not missing, enchant). Uses the applied-enchant name captured at scan time, so it's
    -- warband-wide but only as fresh as the character's last scan. itemID+enchantID give a
    -- stable per-item ignore key for a consumer (this addon holds no ignore state).
    -- Consumer: Warbandeer's Detail gear-row "Wrong enchant" note (via ns.EnchantMismatchSlots),
    -- filtered by the user's per-item accept list (WarbandeerDB.ignoredEnchants).
ShadowsOfUI_UpgradeApi:RecommendedGems(charName)       → primary?, secondary?
    -- which gems to socket, as two EnchantSuggestions: the `primary` "diamond" (primary
    -- stat, UNIQUE-EQUIPPED — socket exactly one) and a repeatable `secondary` stat gem
    -- for every other socket.  ClassCodex supplies both per spec; the bundled fallback has
    -- only the secondary (nil primary).  Resolve a name from `.name` / `.id` (item, via
    -- GetItemInfo).  Consumers split them: Detail puts the diamond on the first empty
    -- socket + the secondary on the rest; the tooltip uses the secondary.
ShadowsOfUI_UpgradeApi:ItemUpgrades(link, boundTo?, ilvl?)  → ItemUpgradeEntry[]|nil
    -- which characters a specific item would upgrade (drives the tooltip).
    -- boundTo = the holder's name for a soulbound item (restricts to that one
    -- character); nil for an unbound item (BoE / Warbound) that any char could use.
    -- ilvl = the item's effective (context-scaled) level; the tooltip reads it off
    -- the displayed "Item Level" line so a downscaled item is measured the same way
    -- equipped slots are (falls back to the link's unscaled ilvl when omitted)
```

`UpgradeResult` = `{ slot, link, ilvl, ilvlGain, statTag?, where, betterElsewhere?, pairSwap?, reqLevel? }`
where `statTag` ∈ `"good"`/`"off"`/nil, `where` ∈ `"held"`/`"warband"`, `reqLevel` is the candidate's
required character level (from the data layer's scan-time capture, nil when unknown — lets a consumer
gate "equippable now?" without a cold live lookup; Warbandeer's Summary "Up" column reads it),
`betterElsewhere` = a warband-bank copy beats the best held upgrade, `pairSwap` = the
MainHand/OffHand result is half of a 2H → (1H + off-hand) swap (see Algorithm).
`ItemUpgradeEntry` = `{ name, classKey, slot, ilvlGain, statTag? }`.

## Algorithm (`evaluate.lua` + `upgrade.lua`)

Per (character, candidate item): `WarbandeerApi:ClassifyGearItem`/stored fields give
equipLoc/classID/subClassID → `CanEquip` (class proficiency) → `primaryFits` (primary-stat
match via `ns.PrimaryStat`) → `CompetingSlots` → upgrade iff candidate ilvl > the **lowest**
equipped ilvl among competing slots (an empty slot = 0, so always an upgrade). `primaryFits`
reads `GetItemStats` and rejects only an item that carries some *other* primary (str/agi/int) and
not the spec's — items with no primary (rings/necks/cloaks/most off-hands), the flexible all-stat
primary, or unknown spec/stats pass through. Stat tag is lazy: `C_Item.GetItemStats(link)` mapped to crit/haste/mastery/
vers, looked up against the spec's `ns.StatPriority` tiers (`ns.StatRanks`); the item is `good`
if it carries a tier-1 secondary, else `off`. `computeUpgrades` aggregates the best held vs
warband candidate per slot (via `pickHeadline`); the warband one wins (and sets `betterElsewhere`)
only when strictly higher. Results are memoized per character (~2s TTL) so a view's per-slot calls
compute once.

**Two-hand reconciliation** (`resolveTwoHand`, gated by `equippedTwoHand` → `ns.IsTwoHand`): when
a character wields a 2H the off-hand slot is nominally empty, so the per-slot pass *skips* both
weapon slots (else any off-hand item — holdables are all-class — beats ilvl 0 and shows as a bogus
upgrade). `resolveTwoHand` instead picks the best equippable `mh1h`/`mh2h`/`off` candidate
(`ns.WeaponRole`) and scores configs in a doubled-ilvl budget (a 2H ≈ two hands): current = `2×`
the equipped 2H ilvl, a better 2H = `2× its ilvl`, a 1H+off-hand pair = `mh1h.ilvl + off.ilvl`. A
better 2H emits one normal MainHand result; a pair that beats both current and the 2H option emits
MainHand **and** OffHand results flagged `pairSwap`, each showing the average per-hand gain. The
tooltip path (`ItemUpgrades`) applies the same gate: a single item can't form a pair, so a lone
off-hand / 1H is not listed as an upgrade for a 2H wielder (only another 2H is).

**Titan's Grip (dual two-hander)** (`equippedDualTwoHand` — both hands hold a 2H): the off-hand
isn't nominally empty, so the doubled-budget pairing above doesn't apply. `resolveTwoHand` scores
current = `MH.ilvl + OH.ilvl` and a better 2H simply replaces the **weaker** of the two equipped
hands (gain vs that hand, emitted on its slot — no `pairSwap`). Across every source: the per-slot
guard in `evaluate` lets a 2H through for a dual-2H wielder (contesting **both** weapon slots,
targeting the weaker) instead of rejecting it, and the external/tooltip guards allow a 2H (still
rejecting a lone 1H/off-hand, which for a TG build would be an off-build switch to SMF).

**One-hander guard** (the mirror, in `evaluate`): when the character has an **off-hand equipped**
(`equipped.OffHand`) — a shield tank (Prot Paladin/Warrior) or a dual-wielder (DW Frost DK,
Enhancement, Windwalker, rogues) — a two-hander (`ns.IsTwoHand`) is rejected outright, since equipping it would
drop the off-hand the spec relies on (the per-slot ilvl compare would otherwise flag a higher-ilvl
2H against the equipped 1H main hand). It's keyed off the **equipped weapon config**, not a spec
table, so it tracks the character's actual build (DW vs 2H Frost) for free. The one **exception** is
a Titan's-Grip Fury warrior already dual-wielding two 2H (`equippedDualTwoHand`): an occupied
off-hand does **not** always mean a 1H/shield build, so a 2H is *not* rejected there — it's routed
to the weaker hand (see Titan's Grip above). A true single-2H wielder has an empty off-hand and
falls to `resolveTwoHand` instead. One gate in `evaluate` covers every source (held/warband,
world-quest, vendor, and the `ItemUpgrades` tooltip).

## Gotchas

- **`SkipUpgradeBlock` opt-out.** `tooltip.lua`'s post-call bails when the hovered
  `GameTooltip` frame has `SkipUpgradeBlock = true`, so a consumer can suppress the
  "Upgrade for:" block on its own private tooltip. Warbandeer's Detail view sets it on
  `WarbandeerItemTooltip`/`WarbandeerItemCompareTooltip` (it shows the suggestion as a
  side-by-side comparison instead). The standard `GameTooltip`/`ItemRefTooltip` never set it.
- **Embedded reward tooltips are skipped.** `tooltip.lua`'s `isEmbedded` guard bails when
  `tooltip:GetParent().Tooltip == tooltip` — the signature of an `EmbeddedItemTooltip` container
  (it parents its inner tooltip back onto itself). This suppresses the "Upgrade for:" block on
  world-quest map-pin rewards and quest-log reward previews, while the standalone `GameTooltip` /
  `ItemRefTooltip` (bag hovers, chat item links) — nobody's `.Tooltip` — keep it.
- **Soulbound items are holder-only in the tooltip.** `tooltip.lua` detects a `Soulbound`
  binding line (`ITEM_SOULBOUND`) and passes `boundTo = current character` to `ItemUpgrades`,
  so a soulbound item only lists the character it's already bound to; BoE / Warbound-until-
  equipped items (different binding line) stay viable for everyone. The per-character views
  need no binding check — they only draw from a character's own bags/bank (soulbound there is
  legitimately theirs) plus the warband bank (which can't hold soulbound items).
- **Bind-on-Pickup gear is skipped in the tooltip.** `tooltip.lua` detects a `Binds when picked
  up` line (`ITEM_BIND_ON_PICKUP`) and bails before building the "Upgrade for:" block — a
  not-yet-bound BoP item can't move between characters, so a cross-character recommendation is
  misleading. (Already-bound BoP shows `Soulbound` instead and takes the holder-only path above.)
- **Spec resolution is by numeric spec ID** (`charData.basic.specialization.id`, persisted by
  Warbandeer_Characters v13) — locale-independent. The `id` follows the **played (active)** spec,
  not the **loot** spec (`.primary`), so recommendations match what the character actually plays
  (a Shadow Priest with a Holy loot spec gets Shadow enchants/gems/mastery, not Holy). The name
  fallback (`ccClassSpec`, when `id` is absent) likewise prefers `.active` over `.primary`. A
  character never logged in since that DB version has no `id` and gets no stat tag (ilvl upgrades still report).
- **Load order:** publishes `ShadowsOfUI_UpgradeApi` and is listed in Warbandeer's `OptionalDeps`,
  so it loads **before** Warbandeer — Warbandeer's column file can gate on the global at load.
  This addon does *not* depend on Warbandeer.
- **Two-hander weapon slots** never report a lone off-hand or lone 1H upgrade (see Algorithm) —
  only a better 2H, or a 1H+off-hand pair that beats the 2H in doubled-ilvl budget. The pair is a
  heuristic (2H ilvl ≈ two one-handers of that ilvl); spec weapon *style* (e.g. Arms wanting a 2H)
  isn't modelled, so a fury-style pair can surface for a 2H-preferring spec — class proficiency is
  the only gate. Non-2H wielders keep the plain per-slot behaviour. **Titan's Grip** (both hands 2H)
  is the exception: a 2H upgrades the weaker hand directly (no pairing), and 1H/off-hand candidates
  are not suggested (they'd be an off-build SMF switch).
- **Wands are one-handed**, though they share `INVTYPE_RANGEDRIGHT` with (two-handed) guns and
  crossbows — only the weapon subclass (`Enum.ItemWeaponSubclass.Wand` = 19) tells them apart. So
  `ns.IsTwoHand`/`ns.WeaponRole` take an optional `subClassID` and exclude a wand from the two-hand
  bucket; a wand user is treated as a 1H + off-hand build (their off-hand upgrades surface, and a 2H
  that would strand the off-hand is guarded out). Callers pass the candidate's subclass; equipped
  slots derive it via `slotSubClass` (`GetItemInfoInstant` fallback like `slotEquipLoc`).
- **2H detection tolerates pre-equipLoc cached data:** `slotEquipLoc`/`slotSubClass` fall back to
  `GetItemInfoInstant(link)` when an equipped slot has no stored `equipLoc`/`subClassID` (alt scanned
  before those fields existed) — otherwise alts viewed from the warband would slip back to the bogus
  lone off-hand upgrade.
- **Artifact-quality items are excluded outright** (`isArtifact` in `evaluate.lua`, gating both
  `evaluate` and the `resolveTwoHand` scan). The Heart of Azeroth and Legion artifact weapons
  scale by their own systems, so `GetDetailedItemLevelInfo` returns an inflated effective ilvl —
  a legacy Heart in a bank would otherwise "upgrade" a real neck. Gate prefers the candidate's
  **scan-time `quality`** (captured by the data layer's `gearbag`/`bank` scanners, v17) and falls back
  to `C_Item.GetItemQualityByID(itemID)`. The stored quality is essential for **offline alts**:
  `GetItemQualityByID` returns nil for an item not in the client cache, so without it a cold legacy
  Heart slipped the gate and was recommended as a neck upgrade. Gate is `quality == Enum.ItemQuality.Artifact`.
- **Effective vs. detailed ilvl** — equipped slots are measured with `C_Item.GetCurrentItemLevel`
  (effective / context-scaled), so candidates MUST be too, or an item the player sees downscaled
  (e.g. a true ilvl-655 ring shown at 102 in Chromie Time / a scaled zone) reads hundreds of levels
  too high via the link's unscaled `GetDetailedItemLevelInfo` and fakes a massive upgrade. The
  held/warband caches store effective ilvl (`data/gearbag.lua`, `data/bank.lua` build an
  `ItemLocation` per slot); the tooltip passes the displayed effective ilvl into `ItemUpgrades`
  (`tooltip.lua` parses the `ITEM_LEVEL` line). Residual edge: a warband-bank item scanned in one
  character's scaled context, then compared against another character's slots, is still cross-context.
- **ilvl-first** means tier-set breaks / unique-equipped duplicates can show as upgrades; the
  stat tag and class-proficiency gate trim the obvious noise but it's documented, not perfect.
- **`ns.ClassGear` weapon matrix is a class-granularity approximation** — refresh on weapon-
  proficiency changes. It lists the **full** class proficiency (e.g. Hunters carry their melee
  weapons — axes/swords/polearm/staff/dagger/fist — so Survival's mandatory 2H is covered, not just
  ranged; Evokers carry 2H axe/mace/sword, not only staves), erring toward over-allowing since an
  occasional mis-allow only adds/drops one ilvl-gated suggestion. Armour-type gating (the high-value
  case) is exact via `ns.wow.Armor.byClass`.
- **Last-seen data:** loose gear is only known after the relevant bags/bank/warband-bank have
  been opened; `GetItemStats`/scaled ilvl need the item loaded (warm for your own gear).
- **Stat priorities drift** with the season — `data/statpriority.lua` is precomputed from PvE
  secondary-stat weightings; regenerate it when those shift (it only affects the good/off tag).
- **Stat tag needs only the tier map** — no rating numbers or content-type (M+/Raid) are stored;
  the priority is collapsed to tiers offline, so there's nothing to rank at runtime.
- **Missing-enchant detection is link-only** (`enchants.lua`) — the permanent enchant id is field 2
  of the itemString, so it's read with a pure string parse from the stored link and works for
  every alt without the item being loaded (unlike sockets/gems, which need the live item — a
  possible follow-up). `ns.EnchantableSlots` is the static enchantable-slot set (**verify each
  expansion**); the off-hand is gated on the equipped item being a weapon so a shield/holdable
  is never flagged. The **gem** *suggestion* side (which gem to socket) is still not bundled —
  sockets need the live item (not warband-wide) and that data drifts every patch; the **enchant**
  suggestion is bundled (`data/enchants.lua`) but re-derived against our own `ns.StatPriority`
  rather than copied (a stat-variant resolver, not a flat per-slot ID table — see below).
- **Enchant recommendation is stat-derived, not a flat table.** Narcissus hand-maintains a
  per-slot enchant-ID table; we instead store the *variants* (`byStat`) and pick by the
  character's spec priority (`ns.StatRanks`), so the same small table serves every spec and the
  logic is ours. Only the IDs are data, and names render live — but the IDs still drift, so
  `data/enchants.lua` is a **regenerate-each-season** file like `vendorgear`/`statpriority`.
- **Refreshing `ns.Enchants`** (the *fallback* only — ClassCodex covers installed users).
  Open the Enchanting profession window in-game on an enchanter, then run this `/wdebug` probe
  (copyable output) to dump every enchant recipe id + name:
  `local t={} for _,id in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do local i=C_TradeSkillUI.GetRecipeInfo(id) if i and i.name and i.name:find("Enchant") then t[#t+1]=id.."\t"..i.name end end table.sort(t) return table.concat(t,"\n")`
  Map the names onto canonical slots (`Finger`/`Weapon`/`Chest`/…) and the stat variants, then
  bake the recipe spellIDs into `data/enchants.lua`. A row is `byStat` if the enchant has
  Crit/Haste/Mastery/Versatility variants, else `fixed`.
- **ClassCodex is an undocumented internal global, read defensively.** `ClassCodexGearData`
  (and `ClassCodexIcyVeinsData`) are plain globals a young (v0.x) addon assigns; there's no
  published API, so the shape could change on any update. `ns.ClassCodexEnchant`/`ns.ClassCodexGems`
  (in `classcodex.lua`) type-check every level and return nil on a miss, so the worst case is callers
  "revert to the bundled pick," never an error. Two known data quirks handled: spec keys are lower-with-hyphens
  (`beast-mastery`) and slot strings are inconsistent — plural (`Ring` vs `Rings`), alternate nouns
  (`Boots` for feet), and **synonyms** (`Helm` for the Head slot) — `ccNormalize` collapses all three
  (lowercase + de-plural + a `CC_ALIAS` synonym fold, `helm`→`head`). Missing the helm fold was a real
  bug: a Holy Priest's head enchant showed "Missing enchant" with no suggestion because CC labels it
  "Helm" while we looked up "head". The spec key is read from the *localized* spec name, so a
  non-enUS client misses the lookup and falls back (acceptable; CC itself is English-keyed).
