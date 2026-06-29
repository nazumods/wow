# ShadowsOfUI-Known

**Deps:** LibNAddOn, Warbandeer_Characters · **OptionalDeps:** Warbandeer · **SavedVars:** none · **Commands:** `/sknown <itemID>`, `/sknown knownby <recipeID>` (dev dumps) · **API:** reads `WarbandeerApi` + `WarbandeerDB`

Headless tooltip addon with two surfaces, both driven by the captured per-character learned-recipe
data (`professions.details[skillLineID].recipes[bucket].learned[] = { id, name }`):

1. **"Learnable by:"** on **recipe items** (the patterns/scrolls) — characters that have the
   recipe's profession but haven't learned it.
2. **"Known by:" / "Not Known"** on the **Place Crafting Order** browse list — which characters
   already know the hovered recipe (red "Not Known" when none do).

Assignment-form init (`local ns = LibNAddOn(...)`); no LibNUI.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Bootstrap + logic. `RECIPE_SUBCLASS_TO_SKILL` (recipe item subclass → parent skillLineID), `ns.BuildLearnable(itemID, reqSkill, itemName)` → sorted `KnownEntry[]` (or nil if not a craftable recipe), and `ns.BuildKnownBy(recipeID)` → sorted `CrafterEntry[]` of characters that have **learned** that recipe (matched by the captured `learned[].id` — exact, no name ambiguity; ordered main-intent → secondary → other, then level desc, name). |
| `tooltip.lua` | Two `ns:OnItemTooltip` (LibNAddOn item-tooltip hook) registrations: the **Learnable** block (reads the skill threshold off the tooltip lines, renders names) and the **Known by** line on crafting-order rows (`customerOrderRecipeID` gates on `ProfessionsCustomerOrdersFrame` being shown + the tooltip owner's `option.spellID` — which C_TradeSkillUI treats as a recipeID — so it's both the gate and the exact identity; `renderKnownBy` → `Known by: <names>` or red `Not Known: <Profession>` — the profession comes from the row's `option.skillLineAbilityID` via `C_TradeSkillUI.GetProfessionNameForSkillLineAbility`, so it shows even when **nobody** knows the recipe). `/sknown <itemID>` + `/sknown knownby <recipeID>` dev commands. |

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
- Name colour: `ns.Colors.className(name, classKey)` (PascalCase class colour) when `meets`,
  else `RED_FONT_COLOR`.
- `reqSkill(data)` = first parenthesised integer on tooltip lines 2+ (skips line 1, the item
  name) — i.e. the "Requires <Profession> (N)" threshold; 0 when the recipe states none.

## "Known by" (Place Crafting Order)

`ns.BuildKnownBy(recipeID)` walks `WarbandeerApi:GetAllCharacters()` and returns every
character whose captured `learned[]` contains that **recipe id** (`knowsRecipeID` searches all
professions — recipe ids are globally unique). Each `CrafterEntry { name, classKey, rank,
level }`; sorted by `rank ↑` (intent: main → secondary → other), `level ↓`, `name ↑`.

`tooltip.lua`'s second hook fires only when `customerOrderRecipeID(tooltip)` resolves — i.e.
`ProfessionsCustomerOrdersFrame` is shown and the tooltip's owner (the hovered browse row)
carries `option.spellID`. That spellID *is* the recipeID (`C_TradeSkillUI.GetQualitiesForRecipe`
takes it), so it serves as both the UI gate and the exact recipe identity. Rendering: 1 crafter
→ inline `Known by: <name>`; >1 → a `Known by:` header + up to 5 class-coloured names (first 4 +
`and N more.` past 5); 0 → a red `Not Known: <Profession>` (the profession is resolved from the
row's `option.skillLineAbilityID` via `C_TradeSkillUI.GetProfessionNameForSkillLineAbility` —
available even though no captured-data path exists when nobody knows the recipe; falls back to a
bare `Not Known` if the name can't be resolved).

## Gotchas

- **Recipe identity is name-matched, not ID-matched** *(Learnable surface only)*. The recipe item
  name minus its `Recipe:/Pattern:/…` prefix is compared against captured learned-recipe *names*.
  Robust within one account/locale, but a profession never opened on an alt has no learned capture,
  so that alt may show as able to learn a recipe it already knows. The **Known by** surface instead
  matches by the captured recipe **id** (the crafting-order row hands us `option.spellID`), so it's
  exact — no name/locale ambiguity.
- **Known by needs the profession opened once per crafter.** A character whose profession was
  never opened (while its trade-skill window was up) has no `learned` capture, so a recipe they
  actually know reads as "Not Known" until they've opened that profession once.
- **`reqSkill` parsing is single-client/locale.** It only looks for a parenthesised integer;
  recipes with no numeric threshold (most modern ones) yield 0, so nobody is shown red.
- **Cooking (185) is included** via the subclass map even though it isn't in
  `WarbandeerApi.professionInfo`; gathering/book/first-aid/fishing recipe subclasses are not.
- **Warbandeer is optional.** `intentRank` reads the global `WarbandeerDB` directly and
  degrades to rank 3 for everyone when absent — ordering then falls back to level/skill.
