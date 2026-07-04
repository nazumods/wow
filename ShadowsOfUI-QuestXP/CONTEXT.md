# ShadowsOfUI-QuestXP

**Deps:** LibNAddOn · **SavedVars:** none · **Commands:** `/squestxp` (dev/lookup) · **API:** none

Headless addon, single file, no DB. Assignment-form init (`local ns = LibNAddOn(...)`); no
LibNUI. Appends a `(X%)` tag to the XP reward shown in the map quest log's Details pane —
percentage of the player's current-level XP requirement the reward is worth.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Whole addon. `GetRewardPercent()` (also exposed as `ns.GetRewardPercent`): whole-percent value of the selected quest's XP reward vs. `UnitXPMax("player")`, or nil if nothing to show. `hooksecurefunc("QuestInfo_ShowRewards", …)` appends the tag to `MapQuestInfoRewardsFrame.XPFrame.Name` when that call was for the map Details pane. `/squestxp` dev/lookup command. |

## How it hooks

`QuestInfo_ShowRewards` is a single shared Blizzard function that renders the rewards section for
**both** the map quest-log Details pane and the NPC quest-greeting/offer dialogs — it swaps
`QuestInfoFrame.rewardsFrame` between `MapQuestInfoRewardsFrame` (map) and `QuestInfoRewardsFrame`
(NPC dialog) depending on context (see Blizzard's `QuestInfo.lua`). This addon hooks the shared
function and only acts when `QuestInfoFrame.rewardsFrame == MapQuestInfoRewardsFrame` — i.e. the
map Details pane — leaving NPC quest-giver dialogs untouched.

`GetQuestLogRewardXP()` (legacy global, no args) implicitly reads the same "currently selected
quest" state `QuestInfo_ShowRewards` just used, so no explicit questID needs to be threaded
through.

## Gotchas

- **Read-only, cosmetic hook.** `hooksecurefunc` on a UI-refresh function, `SetText` on a
  FontString — no combat-rating/secret-value concerns, no tainting risk.
- **Text is appended, not replaced.** Blizzard's own `SetText(BreakUpLargeNumbers(xp))` runs
  first (we hook *after*), so `nameText:GetText()` is always Blizzard's fresh base text — no
  double-appending across refreshes.
- **No live update on level-up.** Because this piggybacks on Blizzard's own render call rather
  than owning any state, the tag only (re)appears when Blizzard itself redraws the rewards
  section (selecting/reselecting a quest) — matching Blizzard's own staleness if you level up
  while the pane happens to be open.
- **No `X-Curse-Project-ID` yet** — added when the CurseForge project is created.
