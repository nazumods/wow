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
| `data/statpriority.lua` | `ns.StatPriority[classToken] = { [specIndex] = { crit, haste, mastery, versatility } }` = stat→tier (1 = top), each class an array in `GetSpecialization()` index order. Precomputed offline from PvE secondary-stat weightings (ties within ~15% share a tier); the only stat data the addon carries |
| `data/primarystat.lua` | `ns.ClassPrimary[classToken] = { [specIndex] = "str"\|"agi"\|"int" }` — primary stat per spec, same array layout as `ns.StatPriority`. Gates out wrong-primary gear (an Intellect dagger for a Rogue) that class proficiency alone lets through |
| `data/classgear.lua` | `ns.ClassGear[classKey] = { shield, weapons = {[subClassID]=true} }` — bundled weapon/shield proficiency baseline (armour *type* comes from `ns.wow.Armor.byClass`, not repeated here) |
| `data/vendorgear.lua` | `ns.VendorGear` = bundled list of the expansion's faction-quartermaster gear pieces (`VendorGearEntry[]`); one entry per slot/quartermaster, each carrying `options` (armour-type variants / stat alternatives) + `quartermaster`/`zone`/`mapID`/`cost`/`ilvl`/`reqLevel`/`equipLoc`. Static game data, **regenerate each season** (note in-file) |
| `data/enchantslots.lua` | `ns.EnchantableSlots` = set of equipment-slot names that take a permanent enchant this expansion. Midnight (12.0.x): Head/Shoulder/Chest/Legs/Feet/Finger1/Finger2/MainHand — **Head/Shoulder are in, Back(cloak)/Wrist(bracer) are out** (Enchanting has no recipe for them); Legs stays (its enchant is a Tailoring/LW spellthread, not an Enchanting recipe). **Verify each expansion** — the set drifts. OffHand is deliberately absent (enhance.lua gates it on the equipped item being a weapon, not a shield/holdable). `enhance.lua`'s `ENCHANT_ORDER` is a top-down superset (Head→OffHand) gated against this set, so a listed-but-unenchantable slot is simply skipped |
| `data/gems.lua` | `ns.Gems` = the **fallback** recommended gem (used only without ClassCodex, whose per-spec primary gem is preferred). `byStat` maps a secondary stat → cut-gem itemId (Midnight "Flawless" gems; adjective = stat). ClassCodex's primary gem is role-specific so we don't mirror it; the fallback offers a universal secondary-stat gem by top stat. **Regenerate each season** |
| `data/enchants.lua` | `ns.Enchants` = the **fallback** recommended enchant per **canonical** enchant slot (used only when ClassCodex isn't installed; CC's per-spec data is preferred — see `enhance.lua`). (both rings → `Finger`, both weapons → `Weapon`; `enhance.lua`'s `ENCHANT_KEY` maps equipped slots onto these). Each row is either `byStat = { haste=id, crit=id, mastery=id, versatility=id }` (resolver picks the variant for the character's top secondary via `ns.StatRanks`) or `fixed = id` (non-variant slots — weapon proc/utility enchants, a primary-stat leg kit). `id` is the **enchanting recipe spellID**; names resolve live (`GetSpellInfo`) at the surface, so nothing is hardcoded/locale-bound. **Regenerate each season** — harvest live recipe ids in-game (see Gotchas → "Refreshing `ns.Enchants`"). A slot absent here yields no recommendation |
| `resolve.lua` | `ns.StatRanks(charData)` → the spec's `{stat=tier}` table (or nil); `ns.PrimaryStat(charData)` → `"str"`/`"agi"`/`"int"` (or nil). Both via a lazily-built `specID → {token, index}` map (`GetSpecializationInfoForClassID`) indexing into `ns.StatPriority` / `ns.ClassPrimary` |
| `equip.lua` | `ns.CompetingSlots(equipLoc)` → equipment-slot names an item contests; `ns.CanEquip(classKey, equipLoc, classID, subClassID)` → armour-type / shield / weapon-proficiency check; `ns.IsTwoHand(equipLoc)` + `ns.WeaponRole(equipLoc)` → `"mh1h"`/`"mh2h"`/`"off"`/nil for the 2H ↔ dual-wield reconciliation |
| `upgrade.lua` | Core logic + the published `ShadowsOfUI_UpgradeApi` methods |
| `enhance.lua` | Missing-enchant detection + recommendation + the published `MissingEnchants`/`RecommendedEnchant` methods. `ns.ItemEnchantID(link)` parses field 2 of the itemString (0 = unenchanted); `ns.MissingEnchants(charData)` walks the equipped slots in a stable order and returns `{ slot, link }` for each enchantable slot whose link carries no enchant (pure string parse → works from any stored alt link, warband-wide; off-hand counts only when it holds a weapon, `WEAPON_EQUIPLOC`). `ns.MissingGems(charData)` → `{ slot, link, sockets }[]` (equipped slots with ≥1 empty socket, from the stored `emptySockets` count — warband-wide but only as fresh as the character's last scan); `ns.RecommendedGems(charData)` → `primary, secondary` (two `EnchantSuggestion`s): the **primary** gem (the "diamond" — primary stat, **unique-equipped so socket exactly one**) and a repeatable **secondary**-stat gem for the other sockets. ClassCodex supplies both (`.gems.primary` + `.gems.secondary[1]` via `classCodexGems`/`ccGem`); the bundled fallback returns `nil` primary + the `ns.Gems.byStat` top-stat gem (the role-specific diamond isn't bundled). `ns.EnchantMismatches(charData)` → equipped slots whose **applied** enchant name (captured at scan time by Warbandeer_Characters into `equipment.slots[slot].enchant`) differs from the recommendation, each `{ slot, link, itemID, enchantID, applied, recommended }` (`itemID`+`enchantID` parsed from the link for a per-item ignore key). Compares via `normEnchant` (lowercase + collapse whitespace) on the shared "Enchant <Slot> - <X>" name form; rank/quality-tier variants share a name so aren't flagged; skips bare slots (→ MissingEnchants), slots with no stored applied name, and slots with no recommendation. `suggestionName` resolves the recommendation's name (CC `.name` / spell `GetSpellName` / item `GetItemInfo`). `ns.RecommendedEnchant(charData, slot)` → `EnchantSuggestion?` `{ kind="item"\|"spell", id, name?, stat? }`. **Prefers ClassCodex** (`classCodexEnchant`): when the global `_G.ClassCodexGearData[CLASSTOKEN][specKey].enchants` exists it returns that per-spec pick (`kind="item"`, carries `name`+`itemId`) — `ccClassSpec` builds the keys (classKey upper-cased; spec name lower-cased, spaces→hyphens — from the persisted numeric `id` via `GetSpecializationInfoByID`, **else the stored `active`/`primary` spec-name string** — prefers the played (active) spec over the loot spec (`primary`) — so alts not logged in since the `id` was added still resolve; locale-dependent), `CC_SLOT`+`ccNormalize` map/dedupe slot names ("Ring"/"Rings"/"Boots"/"Helm"→head via `CC_ALIAS`…). Every CC read is defensive → falls back. **Fallback** = the bundled recipe: maps the slot via `ENCHANT_KEY`, returns a `fixed` recipe or the `byStat` variant for the top secondary (`pickStat` over `ns.StatRanks`, `STAT_ORDER` tie-break; `kind="spell"`). nil when neither source has one. Names resolve at the surface (CC carries its own; a spell via `GetSpellName`, an item via `GetItemInfo`). `ns.DumpEnchants(charData)` → a text block (for `/supgrade enchants`) listing the resolved class/spec key, whether the CC global is present, every CC enchant entry as **raw slot → `ccNormalize` → pick** (so a slot CC carries under an unmatched name is visible), and each missing-enchant slot → its recommendation with the `CC_SLOT` key — reuses the real helpers so it mirrors live resolution |
| `tooltip.lua` | `TooltipDataProcessor.AddTooltipPostCall(Item)` "Upgrade for:" block + an orange "Missing enchant" line when the hovered item is one of the **player's own equipped** enchantable items with no enchant (`equippedMissingSlot` — matches the displayed link against the live `GetInventoryItemLink` of each enchantable inventory slot, returning that slot; never fires on a loose bag/vendor copy; off-hand gated on holding a weapon). The line gains a "— recommend `<enchant>`" tail (`missingEnchantLine` → `ns.RecommendedEnchant` for the logged-in char, name via `GetSpellName`) when the bundled table has a pick. Also an **"Empty socket"** line for the player's own equipped item with an unfilled socket (`equippedEmptySockets` — `GetItemNumSockets` minus gemmed sockets via `GetItemGemID`, gated to equipped; **not** the `GetItemStats` `EMPTY_SOCKET_*` keys, which the Midnight Gem Manager leaves set on items it has gemmed) + a "— recommend `<gem>`" tail (`emptySocketLine` → `ns.RecommendedGems`, using the **secondary** fill gem — a lone item tooltip can't know if the one diamond is already placed elsewhere). `/supgrade [name]` dev dump (upgrades); `/supgrade enchants [name]` → `ns.DumpEnchants` in a copyable `LibNUI.ShowCopyWindow` (LibNUI loaded transitively; falls back to chat) |
| `spec/upgrade.lua` | Busted harness: loads data + `resolve`/`equip`/`upgrade` into a fresh `ns` with stubbed WoW globals (`C_Item`, `Enum`, `GetTime`, spec-info fns) and a fake `WarbandeerApi`. `up.harness()` returns `{ ns, Api, api, defItem, addChar, pools, warband, advance }`. Skips `core.lua` (LibNAddOn bootstrap) + `tooltip.lua` (frames) |
| `spec/equip_spec.lua` | `CompetingSlots` / `IsTwoHand` / `WeaponRole` / `CanEquip` (armour-type, shield, weapon-proficiency gating) |
| `spec/resolve_spec.lua` | `StatRanks` / `PrimaryStat` spec-ID → tier/primary resolution |
| `spec/enhance_spec.lua` | `ItemEnchantID` link parsing (enchant id / 0 / nil / bare itemString), `MissingEnchants` (slot-order output, non-enchantable slots ignored, empty slots skipped, off-hand weapon flagged but shield/holdable not), the published `Upgrade:MissingEnchants` name resolution, and `RecommendedEnchant` — the bundled path (stat-variant pick from spec priority, Finger1/2 + MainHand/OffHand canonical-key mapping, `fixed` spec-independent, nil for unknown-spec variant slot / unbundled slot, next-best-stat fallback) **and** the ClassCodex source (per-spec pick overrides bundled, singular/plural slot tolerance, weapon mapping, graceful fallback when CC's global is absent or malformed); plus `MissingGems` (empty-socket slot list from stored counts, order, ignores no-data slots) and `RecommendedGems` (bundled → nil primary + top-stat secondary; ClassCodex → primary diamond + first secondary; nil/nil when spec unknown + no CC) |
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

## Algorithm (`upgrade.lua`)

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

**One-hander guard** (the mirror, in `evaluate`): when the character has an **off-hand equipped**
(`equipped.OffHand`) — a shield tank (Prot Paladin/Warrior) or a dual-wielder (DW Frost DK,
Enhancement, Windwalker, rogues) — a two-hander (`ns.IsTwoHand`) is rejected outright, since equipping it would
drop the off-hand the spec relies on (the per-slot ilvl compare would otherwise flag a higher-ilvl
2H against the equipped 1H main hand). It's keyed off the **equipped weapon config**, not a spec
table, so it tracks the character's actual build (DW vs 2H Frost, SMF vs Titan's-Grip Fury) for free;
a true 2H wielder has an empty off-hand and falls to `resolveTwoHand` instead. One gate in `evaluate`
covers every source (held/warband, world-quest, vendor, and the `ItemUpgrades` tooltip).

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
  the only gate. Non-2H wielders keep the plain per-slot behaviour.
- **2H detection tolerates pre-equipLoc cached data:** `slotEquipLoc` falls back to
  `GetItemInfoInstant(link)` when an equipped slot has no stored `equipLoc` (alt scanned before
  that field existed) — otherwise alts viewed from the warband would slip back to the bogus lone
  off-hand upgrade.
- **Artifact-quality items are excluded outright** (`isArtifact` in `upgrade.lua`, gating both
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
  proficiency changes. Armour-type gating (the high-value case) is exact via `ns.wow.Armor.byClass`.
- **Last-seen data:** loose gear is only known after the relevant bags/bank/warband-bank have
  been opened; `GetItemStats`/scaled ilvl need the item loaded (warm for your own gear).
- **Stat priorities drift** with the season — `data/statpriority.lua` is precomputed from PvE
  secondary-stat weightings; regenerate it when those shift (it only affects the good/off tag).
- **Stat tag needs only the tier map** — no rating numbers or content-type (M+/Raid) are stored;
  the priority is collapsed to tiers offline, so there's nothing to rank at runtime.
- **Missing-enchant detection is link-only** (`enhance.lua`) — the permanent enchant id is field 2
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
  published API, so the shape could change on any update. `classCodexEnchant` type-checks every
  level and silently falls back to `ns.Enchants` on a miss, so the worst case is "reverts to the
  bundled pick," never an error. Two known data quirks handled: spec keys are lower-with-hyphens
  (`beast-mastery`) and slot strings are inconsistent — plural (`Ring` vs `Rings`), alternate nouns
  (`Boots` for feet), and **synonyms** (`Helm` for the Head slot) — `ccNormalize` collapses all three
  (lowercase + de-plural + a `CC_ALIAS` synonym fold, `helm`→`head`). Missing the helm fold was a real
  bug: a Holy Priest's head enchant showed "Missing enchant" with no suggestion because CC labels it
  "Helm" while we looked up "head". The spec key is read from the *localized* spec name, so a
  non-enUS client misses the lookup and falls back (acceptable; CC itself is English-keyed).
