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
| `equip.lua` | `ns.CompetingSlots(equipLoc)` → equipment-slot names an item contests; `ns.CanEquip(classKey, equipLoc, classID, subClassID)` → armour-type / shield / weapon-proficiency check; `ns.IsTwoHand(equipLoc)` + `ns.WeaponRole(equipLoc)` → `"mh1h"`/`"mh2h"`/`"off"`/nil for the 2H ↔ dual-wield reconciliation |
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

`UpgradeResult` = `{ slot, link, ilvl, ilvlGain, statTag?, where, betterElsewhere?, pairSwap? }`
where `statTag` ∈ `"good"`/`"off"`/nil, `where` ∈ `"held"`/`"warband"`,
`betterElsewhere` = a warband-bank copy beats the best held upgrade, `pairSwap` = the
MainHand/OffHand result is half of a 2H → (1H + off-hand) swap (see Algorithm).
`ItemUpgradeEntry` = `{ name, classKey, slot, ilvlGain, statTag? }`.

## Algorithm (`upgrade.lua`)

Per (character, candidate item): `WarbandeerApi:ClassifyGearItem`/stored fields give
equipLoc/classID/subClassID → `CanEquip` (class proficiency) → `CompetingSlots` → upgrade iff
candidate ilvl > the **lowest** equipped ilvl among competing slots (an empty slot = 0, so
always an upgrade). Stat tag is lazy: `C_Item.GetItemStats(link)` mapped to crit/haste/mastery/
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
- **Two-hander weapon slots** never report a lone off-hand or lone 1H upgrade (see Algorithm) —
  only a better 2H, or a 1H+off-hand pair that beats the 2H in doubled-ilvl budget. The pair is a
  heuristic (2H ilvl ≈ two one-handers of that ilvl); spec weapon *style* (e.g. Arms wanting a 2H)
  isn't modelled, so a fury-style pair can surface for a 2H-preferring spec — class proficiency is
  the only gate. Non-2H wielders keep the plain per-slot behaviour.
- **2H detection tolerates pre-equipLoc cached data:** `slotEquipLoc` falls back to
  `GetItemInfoInstant(link)` when an equipped slot has no stored `equipLoc` (alt scanned before
  that field existed) — otherwise alts viewed from the warband would slip back to the bogus lone
  off-hand upgrade.
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
