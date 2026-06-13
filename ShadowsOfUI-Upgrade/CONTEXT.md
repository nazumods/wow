# ShadowsOfUI-Upgrade

**Deps:** LibNAddOn, Warbandeer_Characters · **SavedVars:** none · **Commands:** `/supgrade [name]` (dev dump) · **API:** reads `WarbandeerApi`, publishes `ShadowsOfUI_UpgradeApi`

Headless logic + tooltip addon. Computes per-character gear upgrades from the data layer
(equipped gear + loose gear in bags / personal bank / warband bank), gated by item level and
annotated with spec stat-priority fit. Assignment-form init (`local ns = LibNAddOn(...)`); no
LibNUI. The stat-priority table is a small precomputed built-in (`ns.StatPriority`), so the
addon is fully standalone.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Bootstrap. `ns.api` = `WarbandeerApi` (X-NUI-API, consumed); creates + publishes the global `ShadowsOfUI_UpgradeApi` (`ns.UpgradeApi`); seeds `ns.StatPriority` |
| `data/statpriority.lua` | `ns.StatPriority[classToken] = { [specIndex] = { crit, haste, mastery, versatility } }` = stat→tier (1 = top), each class an array in `GetSpecialization()` index order. Precomputed offline from PvE secondary-stat weightings (ties within ~15% share a tier); the only stat data the addon carries |
| `data/classgear.lua` | `ns.ClassGear[classKey] = { shield, weapons = {[subClassID]=true} }` — bundled weapon/shield proficiency baseline (armour *type* comes from `ns.wow.Armor.byClass`, not repeated here) |
| `resolve.lua` | `ns.StatRanks(charData)` → the spec's `{stat=tier}` table (or nil), via a lazily-built `specID → {token, index}` map (`GetSpecializationInfoForClassID`) indexing straight into `ns.StatPriority` |
| `equip.lua` | `ns.CompetingSlots(equipLoc)` → equipment-slot names an item contests; `ns.CanEquip(classKey, equipLoc, classID, subClassID)` → armour-type / shield / weapon-proficiency check |
| `upgrade.lua` | Core logic + the published `ShadowsOfUI_UpgradeApi` methods |
| `tooltip.lua` | `TooltipDataProcessor.AddTooltipPostCall(Item)` "Upgrade for:" block; `/supgrade [name]` dev dump |

## `ShadowsOfUI_UpgradeApi`

```lua
ShadowsOfUI_UpgradeApi:SlotUpgrade(charName, slot)      → UpgradeResult|nil
    -- best available upgrade for one equipment slot (Head, Finger1, MainHand, …)
ShadowsOfUI_UpgradeApi:CharacterUpgrades(charName)      → UpgradeResult[]   (sorted by ilvlGain desc)
ShadowsOfUI_UpgradeApi:CharacterUpgradeCount(charName)  → integer
ShadowsOfUI_UpgradeApi:ItemUpgrades(link, boundTo?)    → ItemUpgradeEntry[]|nil
    -- which characters a specific item would upgrade (drives the tooltip).
    -- boundTo = the holder's name for a soulbound item (restricts to that one
    -- character); nil for an unbound item (BoE / Warbound) that any char could use
```

`UpgradeResult` = `{ slot, link, ilvl, ilvlGain, statTag?, where, betterElsewhere? }`
where `statTag` ∈ `"good"`/`"off"`/nil, `where` ∈ `"held"`/`"warband"`,
`betterElsewhere` = a warband-bank copy beats the best held upgrade.
`ItemUpgradeEntry` = `{ name, classKey, slot, ilvlGain, statTag? }`.

## Algorithm (`upgrade.lua`)

Per (character, candidate item): `WarbandeerApi:ClassifyGearItem`/stored fields give
equipLoc/classID/subClassID → `CanEquip` (class proficiency) → `CompetingSlots` → upgrade iff
candidate ilvl > the **lowest** equipped ilvl among competing slots (an empty slot = 0, so
always an upgrade). Stat tag is lazy: `C_Item.GetItemStats(link)` mapped to crit/haste/mastery/
vers, looked up against the spec's `ns.StatPriority` tiers (`ns.StatRanks`); the item is `good`
if it carries a tier-1 secondary, else `off`. `computeUpgrades` aggregates the best held vs
warband candidate per slot; the warband one wins (and sets `betterElsewhere`) only when strictly
higher. Results are memoized per character (~2s TTL) so a view's per-slot calls compute once.

## Gotchas

- **Soulbound items are holder-only in the tooltip.** `tooltip.lua` detects a `Soulbound`
  binding line (`ITEM_SOULBOUND`) and passes `boundTo = current character` to `ItemUpgrades`,
  so a soulbound item only lists the character it's already bound to; BoE / Warbound-until-
  equipped items (different binding line) stay viable for everyone. The per-character views
  need no binding check — they only draw from a character's own bags/bank (soulbound there is
  legitimately theirs) plus the warband bank (which can't hold soulbound items).
- **Spec resolution is by numeric spec ID** (`charData.basic.specialization.id`, persisted by
  Warbandeer_Characters v13) — locale-independent. A character never logged in since that DB
  version has no `id` and gets no stat tag (ilvl upgrades still report).
- **Load order:** publishes `ShadowsOfUI_UpgradeApi` and is listed in Warbandeer's `OptionalDeps`,
  so it loads **before** Warbandeer — Warbandeer's column file can gate on the global at load.
  This addon does *not* depend on Warbandeer.
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
