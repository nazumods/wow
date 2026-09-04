# ShadowsOfUI-Known

**Deps:** LibNAddOn, Warbandeer_Characters · **OptionalDeps:** Warbandeer · **SavedVars:** none · **Commands:** `/sknown <itemID>`, `/sknown knownby <recipeID>`, `/sknown guildcrafters <recipeID>` (dev dumps) · **API:** reads `WarbandeerApi` + `WarbandeerDB`; guild lookup via native `C_GuildInfo`

Headless tooltip addon with two surfaces, both driven by the captured per-character learned-recipe
data (`professions.details[skillLineID].recipes[bucket].learned[] = { id, name }`):

1. **"Learnable by:"** on **recipe items** (the patterns/scrolls) — characters that have the
   recipe's profession but haven't learned it, plus a **"Known by:"** line naming those who
   already know it (matched by recipe name).
2. **"Known by:" / "Not Known"** on the **Place Crafting Order** browse list — which characters
   already know the hovered recipe (matched by exact recipe id; red "Not Known" when none do),
   then a **"Guild crafters:"** line — guild members who can craft it — from a separate, **live
   native** guild query (not the captured data); see below.

Assignment-form init (`local ns = LibNAddOn(...)`); no LibNUI.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Bootstrap + logic. `RECIPE_SUBCLASS_TO_SKILL` (recipe item subclass → parent skillLineID), `ns.BuildLearnable(itemID, reqSkill, itemName)` → sorted `KnownEntry[]` learnable list **and** a `CrafterEntry[]` known-by list (or nil if not a craftable recipe), and `ns.BuildKnownBy(recipeID)` → sorted `CrafterEntry[]` of characters that have **learned** that recipe (matched by the captured `learned[].id` — exact, no name ambiguity; ordered main-intent → secondary → other, then level desc, name). |
| `changelog.lua` | `ns.changelog` — newest-first `{version, notes}` release history for the in-game **Changelog** viewer (LibNAddOn). **Generated** — `release.sh` prepends each release; not hand-edited |
| `guild.lua` | `ns.GuildCrafters(recipeID, tooltip?, recipeLevel?)` → cached `GuildCrafterEntry[]` **and** a `"ready"`/`"pending"`/`nil` state of guild members who can craft the recipe, via Blizzard's **native async** guild query (`C_GuildInfo.QueryGuildMembersForRecipe` → `GUILD_RECIPE_KNOWN_BY_MEMBERS` → `GetGuildRecipeInfoPostQuery`/`GetGuildRecipeMember`) — no SavedVars, no comms. Resolves the skill line via `C_TradeSkillUI.GetProfessionInfoByRecipeID` and tries the **parent (base) profession first**, then the recipe's own expansion-specific one — matching Blizzard's `parentProfessionID or professionID` resolution, with the second as a fallback its single-shot form has no recovery for. A query the client declines (`QueryGuildMembersForRecipe` is `MayReturnNothing`) advances to the next candidate **immediately**; the per-attempt 3s timeout is left to cover only the genuine "data hole" case where the query was accepted but no event ever arrives. `recipeLevel` is passed through (nil = no particular level, the documented `Nilable` default) — a caller that ever supplies one must also key the cache on it. Guards *secret values* on every `GetGuildRecipeInfoPostQuery` and `GetGuildRecipeMember` return, including the `numMembers` used as a loop bound. Bounded (30) per-recipe cache wiped on `CRAFTINGORDERS_SHOW_CUSTOMER`, which also re-runs `QueryGuildRecipes()` **every session** so the wipe actually yields fresh online/offline state (loading `Blizzard_Communities` is the one-shot half). Schedules `tooltip:RefreshData()` when the async result lands. `ns.SortGuildCrafters(list)` (online-first, then name) is pure — unit-tested in `spec/`. |
| `tooltip.lua` | Two `ns:OnItemTooltip` (LibNAddOn item-tooltip hook) registrations: the **Learnable** block (reads the skill threshold off the tooltip lines, renders names, then appends a **Known by** line for alts who already know it via the shared forward-declared `renderKnownBy`) and the **Known by** line on crafting-order rows (`customerOrderRecipeID` gates on `ProfessionsCustomerOrdersFrame` being shown + the tooltip owner's `option.spellID` — which C_TradeSkillUI treats as a recipeID — so it's both the gate and the exact identity; `renderKnownBy` → `Known by: <names>` or red `Not Known: <Profession>` — the profession comes from the row's `option.skillLineAbilityID` via `C_TradeSkillUI.GetProfessionNameForSkillLineAbility`, so it shows even when **nobody** knows the recipe). On a crafting-order row it also appends the **guild** crafter block (`renderGuildCrafters` → `ns.GuildCrafters`), which renders "pending" until the async query lands and then refreshes the live tooltip in place. `/sknown <itemID>` + `/sknown knownby <recipeID>` dev commands. Exposes the pure `ns.ReqSkill(data)` tooltip parser. |
| `spec/` | busted unit tests for the pure helpers — `ns.ReqSkill` (tooltip parser) and `ns.SortGuildCrafters` (online-first comparator, `guildsort_spec.lua`); excluded from zip + release detection. |

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

Second return value `knownList` = the `CrafterEntry[]` of characters that already know the
recipe (same shape + ordering as `BuildKnownBy`). Since any toon with the profession is
either learnable or known, `#list == 0 and #knownList > 0` means "everyone who could has
it", while both empty means no character has the profession at all (nothing rendered).

## Rendering (`tooltip.lua`)

- **1 entry** → one inline line: `Learnable by: <name>`.
- **>1** → a `Learnable by:` header, then up to 5 names; past 5, the first 4 then
  `and N more.`.
- **Known by** → when any alt already knows it, a `Known by:` line follows (shared
  `renderKnownBy`: inline for one, header + up to 5 names past that), replacing the old bare
  green `Already known` line.
- Name colour: `ns.Colors.className(name, classKey)` (PascalCase class colour) when `meets`,
  else `RED_FONT_COLOR`.
- `ns.ReqSkill(data)` = the parenthesised integer on the "Requires <Profession> (N)" line,
  anchored to that line via the `ITEM_MIN_SKILL` prefix so an earlier incidental `(NN)` (a stat,
  a set-piece `(2)`) isn't misread; line 1 (the item name) is skipped; 0 when the recipe states
  none, with a first-`(NN)`-on-lines-2+ fallback when `ITEM_MIN_SKILL` is unavailable. Pure — unit-tested in `spec/`.

## "Known by" (Place Crafting Order)

`ns.BuildKnownBy(recipeID)` walks `WarbandeerApi:GetAllCharacters()` and returns every
character whose captured `learned[]` contains that **recipe id** (`knowsRecipeID` searches all
professions — recipe ids are globally unique). Each `CrafterEntry { name, classKey, rank,
level }`; sorted by `rank ↑` (intent: main → secondary → other), `level ↓`, `name ↑`. The result
is **cached per recipeID** (the crafting-order list hovers this on every row, and the scan is
heavy) and wiped on `NEW_RECIPE_LEARNED` — cross-alt data is static within a session, and only the
current character's own learns change it.

`tooltip.lua`'s second hook fires only when `customerOrderRecipeID(tooltip)` resolves — i.e.
`ProfessionsCustomerOrdersFrame` is shown and the tooltip's owner (the hovered browse row)
carries `option.spellID`. That spellID *is* the recipeID (`C_TradeSkillUI.GetQualitiesForRecipe`
takes it), so it serves as both the UI gate and the exact recipe identity. Rendering: 1 crafter
→ inline `Known by: <name>`; >1 → a `Known by:` header + up to 5 class-coloured names (first 4 +
`and N more.` past 5); 0 → a red `Not Known: <Profession>` (the profession is resolved from the
row's `option.skillLineAbilityID` via `C_TradeSkillUI.GetProfessionNameForSkillLineAbility` —
available even though no captured-data path exists when nobody knows the recipe; falls back to a
bare `Not Known` if the name can't be resolved).

## "Guild crafters" (Place Crafting Order)

`ns.GuildCrafters(recipeID, tooltip?, recipeLevel?)` answers "which guild members can craft this
recipe" from Blizzard's own guild-recipe data — no SavedVariables and no addon-to-addon sync
(unlike VamoosesGuildCraft's peer store this replaces). The flow is **async**:
`GetProfessionInfoByRecipeID` gives the recipe's profession(s) →
`C_GuildInfo.QueryGuildMembersForRecipe(skillLineID, recipeID, recipeLevel)` fires — `recipeLevel`
is `nil` in the crafting-orders context, the documented `Nilable` default, since no caller here
passes one — → the `GUILD_RECIPE_KNOWN_BY_MEMBERS` event lands → `GetGuildRecipeInfoPostQuery()` +
`GetGuildRecipeMember(i)` (`displayName, fullName, classFileName, online`) build the list.

Because the tooltip renders synchronously, the first hover kicks off the query and renders a
grey `Guild crafters: querying...` placeholder; when the result arrives the module calls the
tooltip's `RefreshData`/`RefreshDataNextUpdate` so the post-call re-runs and the line fills in
(one crafter inline, otherwise a header + up to 5 names, then `and N more.`). Online crafters
sort first (they can craft now) and render in class colour; offline ones are greyed. Results
cache per recipeID (bounded to 30, FIFO) so re-hovering doesn't re-query; the cache is wiped —
and the subsystem re-primed — on `CRAFTINGORDERS_SHOW_CUSTOMER`. Only one query is in flight at a
time: a newer hover replaces the `active` table outright, so the **identity check `active == a`**
is what invalidates a stale timeout or event. (A separate `a.idx == idx` check rejects a timeout
for candidate N that fires after the flow already advanced to N+1.) Responses are correlated on
the **(skillLineID, recipeID) pair** — `GetGuildRecipeInfoPostQuery` returns the skill line it
answers for, and both candidates query the same recipeID, so the recipe half alone cannot tell
them apart.

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
- **`ns.ReqSkill` parsing is locale-derived.** The requirement line is located via the
  `ITEM_MIN_SKILL` ("Requires %s (%d)") prefix, so it tracks the client locale; recipes with no
  numeric threshold (most modern ones) yield 0, so nobody is shown red.
- **Cooking (185) is included** via the subclass map even though it isn't in
  `WarbandeerApi.professionInfo`; gathering/book/first-aid/fishing recipe subclasses are not.
- **Warbandeer is optional.** `intentRank` reads the global `WarbandeerDB` directly and
  degrades to rank 3 for everyone when absent — ordering then falls back to level/skill.
- **Guild crafters are a live native query, not captured data.** `ns.GuildCrafters` needs
  `IsInGuild()` and returns `nil` state otherwise (the line is skipped). It's async, so the
  first hover shows `querying...` and the tooltip is refreshed once the result lands.
- **Blizzard "data holes."** Some recipes never fire `GUILD_RECIPE_KNOWN_BY_MEMBERS` even
  when a guildmate knows them; the per-attempt 3s timeout treats that as "no crafters" rather
  than hanging (the crafting-order surface just shows no guild line).
- **Secret values.** `GetGuildRecipeMember` returns can be 12.0 *secret values*; each is run
  through `issecretvalue` and nil'd out so using it (as a class-key index, in the sort) can't
  crash and be blamed on us — a later query refills it.
- **Skill-line finickiness.** `QueryGuildMembersForRecipe` wants the recipe's exact profession
  id, so `guild.lua` tries the recipe's own `professionID` then its `parentProfessionID`.
- **Priming.** The guild-recipe subsystem only fires the event once `Blizzard_Communities` is
  loaded and `QueryGuildRecipes()` has been called — both done on `CRAFTINGORDERS_SHOW_CUSTOMER`.
