# ShadowsOfUI-Upgrade

**Deps:** LibNAddOn, Warbandeer_Characters · **SavedVars:** none · **Commands:** `/supgrade [name]` (dev dump) · **API:** reads `WarbandeerApi`, publishes `ShadowsOfUI_UpgradeApi`

Headless logic + tooltip addon. Computes per-character gear upgrades from the data layer
(equipped gear + loose gear in bags / personal bank / warband bank), plus future-action sources
— active world-quest rewards and bundled faction-quartermaster gear — gated by item level and
annotated with spec stat-priority fit. Also flags **missing permanent enchants** on equipped
gear (parsed from the stored item link, so it works warband-wide). Assignment-form init (`local ns = LibNAddOn(...)`); no
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
| `resolve.lua` | `ns.StatRanks(charData)` → the spec's `{stat=tier}` table (or nil); `ns.PrimaryStat(charData)` → `"str"`/`"agi"`/`"int"` (or nil). Both via a lazily-built `specID → {token, index}` map (`GetSpecializationInfoForClassID`) indexing into `ns.StatPriority` / `ns.ClassPrimary` |
| `equip.lua` | `ns.CompetingSlots(equipLoc)` → equipment-slot names an item contests; `ns.CanEquip(classKey, equipLoc, classID, subClassID)` → armour-type / shield / weapon-proficiency check; `ns.IsTwoHand(equipLoc)` + `ns.WeaponRole(equipLoc)` → `"mh1h"`/`"mh2h"`/`"off"`/nil for the 2H ↔ dual-wield reconciliation |
| `upgrade.lua` | Core logic + the published `ShadowsOfUI_UpgradeApi` methods |
| `enhance.lua` | Missing-enchant detection + the published `MissingEnchants` method. `ns.ItemEnchantID(link)` parses field 2 of the itemString (0 = unenchanted); `ns.MissingEnchants(charData)` walks the equipped slots in a stable order and returns `{ slot, link }` for each enchantable slot whose link carries no enchant. Pure string parse → works from any stored alt link (warband-wide); the off-hand counts only when it holds a weapon (`WEAPON_EQUIPLOC`) |
| `tooltip.lua` | `TooltipDataProcessor.AddTooltipPostCall(Item)` "Upgrade for:" block + an orange "Missing enchant" line when the hovered item is one of the **player's own equipped** enchantable items with no enchant (`equippedMissingEnchant` — matches the displayed link against the live `GetInventoryItemLink` of each enchantable inventory slot, so it never fires on a loose bag/vendor copy; off-hand gated on holding a weapon); `/supgrade [name]` dev dump |
| `spec/upgrade.lua` | Busted harness: loads data + `resolve`/`equip`/`upgrade` into a fresh `ns` with stubbed WoW globals (`C_Item`, `Enum`, `GetTime`, spec-info fns) and a fake `WarbandeerApi`. `up.harness()` returns `{ ns, Api, api, defItem, addChar, pools, warband, advance }`. Skips `core.lua` (LibNAddOn bootstrap) + `tooltip.lua` (frames) |
| `spec/equip_spec.lua` | `CompetingSlots` / `IsTwoHand` / `WeaponRole` / `CanEquip` (armour-type, shield, weapon-proficiency gating) |
| `spec/resolve_spec.lua` | `StatRanks` / `PrimaryStat` spec-ID → tier/primary resolution |
| `spec/enhance_spec.lua` | `ItemEnchantID` link parsing (enchant id / 0 / nil / bare itemString), `MissingEnchants` (slot-order output, non-enchantable slots ignored, empty slots skipped, off-hand weapon flagged but shield/holdable not), and the published `Upgrade:MissingEnchants` name resolution |
| `spec/upgrade_spec.lua` | End-to-end published API: ilvl gating, equip/primary filters, multi-slot weaker-slot targeting, held-vs-warband (`betterElsewhere`), `statTag` good/off, sort/count, memo TTL, two-hand reconciliation, `ItemUpgrades` (soulbound `boundTo`, 2H lone-off-hand exclusion), `WorldQuestUpgrades` (ilvl gating, equip/primary filters, multi-slot, 2H guard, sort + quest metadata; harness `addWQ` / fake `GetWorldQuestRewards`), `VendorUpgrades` (ilvl gating, `reqLevel` player-level gating, armour-type/neck option pick, multi-slot, 2H guard, statTag, sort + purchase metadata; harness `addVendor` / synthetic `ns.VendorGear`) |

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
ShadowsOfUI_UpgradeApi:ItemUpgrades(link, boundTo?, ilvl?)  → ItemUpgradeEntry[]|nil
    -- which characters a specific item would upgrade (drives the tooltip).
    -- boundTo = the holder's name for a soulbound item (restricts to that one
    -- character); nil for an unbound item (BoE / Warbound) that any char could use.
    -- ilvl = the item's effective (context-scaled) level; the tooltip reads it off
    -- the displayed "Item Level" line so a downscaled item is measured the same way
    -- equipped slots are (falls back to the link's unscaled ilvl when omitted)
```

`UpgradeResult` = `{ slot, link, ilvl, ilvlGain, statTag?, where, betterElsewhere?, pairSwap? }`
where `statTag` ∈ `"good"`/`"off"`/nil, `where` ∈ `"held"`/`"warband"`,
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
  Warbandeer_Characters v13) — locale-independent. A character never logged in since that DB
  version has no `id` and gets no stat tag (ilvl upgrades still report).
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
  a legacy Heart in a bank would otherwise "upgrade" a real neck. Gate is `C_Item.GetItemQualityByID(itemID) == Enum.ItemQuality.Artifact`.
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
  is never flagged. The curated gem/enchant *suggestion* tables (which enchant to apply) are
  deliberately **not** bundled — they drift every patch and are high-maintenance; this only
  reports the gap.
