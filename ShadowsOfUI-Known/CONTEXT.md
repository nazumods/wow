# ShadowsOfUI-Known

**Deps:** LibNAddOn, Warbandeer_Characters · **OptionalDeps:** Warbandeer · **SavedVars:** none · **Commands:** `/sknown <itemID>` (dev dump) · **API:** reads `WarbandeerApi` + `WarbandeerDB`

Headless tooltip addon. Adds a "Learnable by:" block to recipe item tooltips listing the
account's characters that have the recipe's profession but haven't learned it. Assignment-form
init (`local ns = LibNAddOn(...)`); no LibNUI.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Bootstrap + logic. `RECIPE_SUBCLASS_TO_SKILL` (recipe item subclass → parent skillLineID), and `ns.BuildLearnable(itemID, reqSkill, itemName)` → sorted `KnownEntry[]` (or nil if not a craftable recipe). |
| `tooltip.lua` | `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item)` hook: reads the skill threshold off the tooltip lines, renders the block, colours names. Manual `/sknown` dev command. |

## `ns.BuildLearnable(itemID, reqSkill, itemName)`

Returns `nil` unless `GetItemInfoInstant(itemID)` reports `Enum.ItemClass.Recipe` **and** the
recipe subclass maps to a tracked crafting profession (`RECIPE_SUBCLASS_TO_SKILL`). Otherwise
walks `WarbandeerApi:GetAllCharacters()` and, for each toon that:

- has a `basic.professions` slot whose `skillID` equals the recipe's `skillLineID`, and
- does **not** already list the recipe (`craftedName(itemName)` matched against the union of
  `professions.details[skillLineID].recipes[*].learned[].name`),

emits a `KnownEntry { name, classKey, meets, rank, level, skill }`. `meets = reqSkill == 0 or
skill >= reqSkill`. `rank` is the intent rank from `WarbandeerDB.profIntent[name][skillLineID]`
(main = 1, secondary = 2, else 3). Sorted by `rank ↑`, `level ↓`, `skill ↓`, `name ↑`.

Second return value `knownCount` = characters that already know the recipe. Since any toon
with the profession is either learnable or known, `#list == 0 and knownCount > 0` means
"everyone who could has it" (rendered as **Already known**), while `#list == 0 and
knownCount == 0` means no character has the profession at all (nothing rendered).

## Rendering (`tooltip.lua`)

- **1 entry** → one inline line: `Learnable by: <name>`.
- **>1** → a `Learnable by:` header, then up to 5 names; past 5, the first 4 then
  `and N more.`.
- **0 learnable but `knownCount > 0`** → a single green `Already known` line.
- Name colour: `ns.Colors[classKey]` (PascalCase class colour) when `meets`, else
  `RED_FONT_COLOR`.
- `reqSkill(data)` = first parenthesised integer on tooltip lines 2+ (skips line 1, the item
  name) — i.e. the "Requires <Profession> (N)" threshold; 0 when the recipe states none.

## Gotchas

- **Recipe identity is name-matched, not ID-matched.** The recipe item name minus its
  `Recipe:/Pattern:/…` prefix is compared against captured learned-recipe *names*. Robust
  within one account/locale, but a profession never opened on an alt has no learned capture,
  so that alt may show as able to learn a recipe it already knows.
- **`reqSkill` parsing is single-client/locale.** It only looks for a parenthesised integer;
  recipes with no numeric threshold (most modern ones) yield 0, so nobody is shown red.
- **Cooking (185) is included** via the subclass map even though it isn't in
  `WarbandeerApi.professionInfo`; gathering/book/first-aid/fishing recipe subclasses are not.
- **Warbandeer is optional.** `intentRank` reads the global `WarbandeerDB` directly and
  degrades to rank 3 for everyone when absent — ordering then falls back to level/skill.
