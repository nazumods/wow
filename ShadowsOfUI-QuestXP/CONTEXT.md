# ShadowsOfUI-QuestXP

**Deps:** LibNAddOn · **SavedVars:** none · **Commands:** `/squestxp` (dev/lookup) · **API:** none

Headless addon, single file, no DB. Assignment-form init (`local ns = LibNAddOn(...)`); no
LibNUI. Appends a `(X%)` tag to the XP reward shown in the map quest log's Details pane —
percentage of the player's current-level XP requirement the reward is worth.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Whole addon. `GetRewardPercent()` (also exposed as `ns.GetRewardPercent`): whole-percent value of the selected quest's XP reward vs. `UnitXPMax("player")`, or nil if nothing to show. `hooksecurefunc(MapQuestInfoRewardsFrame.XPFrame.Name, "SetText", …)` appends the tag whenever that FontString's text is set; `EnsureHooked` installs it once the frame exists (immediately, or on `WorldMapFrame`'s first `OnShow`). `/squestxp` dev/lookup command. |

## How it hooks

`MapQuestInfoRewardsFrame.XPFrame.Name` is the FontString the map quest-log Details pane uses for
the XP reward number — confirmed live via `/framestack` (hover the XP text in the rewards panel).
It's distinct from `QuestInfoRewardsFrame`, which NPC quest-greeting dialogs use, so hooking it is
inherently map-only; no extra "which pane is this" check is needed.

This addon originally hooked `QuestInfo_ShowRewards` (the classic shared render function — see
Blizzard's `QuestInfo.lua`), gated to `QuestInfoFrame.rewardsFrame == MapQuestInfoRewardsFrame`.
That stopped firing on live: the client's rewards-panel rework (new `RewardsFrameContainer`
wrapper around the pane, confirmed via `/framestack`) still populates the same legacy
`MapQuestInfoRewardsFrame.XPFrame.Name` widget, but evidently through some other, unidentified
entry point rather than the classic function — Mapster was ruled out (its only quest-related code
touches map POI pin scaling, nothing reward/QuestInfo-related). Rather than chase the new render
function's name (which may change again across client reworks), the addon now hooks the widget's
own `SetText` directly — guaranteed to fire regardless of what calls it.

`GetQuestLogRewardXP()` (legacy global, no args) implicitly reads the same "currently selected
quest" state whatever code just populated the widget used, so no explicit questID needs to be
threaded through.

## Gotchas

- **Read-only, cosmetic hook.** `hooksecurefunc` on a FontString's `SetText` — no combat-rating/
  secret-value concerns, no tainting risk.
- **Recursion guard required.** Hooking an instance's own `SetText` means our own call to
  `fontString:SetText(...)` inside the hook would re-trigger the same hook; the `appending` flag
  makes the inner (recursive) call a no-op. Don't remove it.
- **Text is appended, not replaced.** Every genuine Blizzard refresh calls `SetText` with fresh
  raw text (not our previously-appended string), so `text` in `OnXPTextSet` is always the base
  value — no accumulation across refreshes.
- **Deferred hook.** `MapQuestInfoRewardsFrame` belongs to an on-demand Blizzard UI module and may
  not exist at login; `EnsureHooked` is called immediately and again on `WorldMapFrame`'s first
  `OnShow` as a fallback. `WorldMapFrame` itself is always loaded (base UI), so hooking its
  `OnShow` script at file-load time is safe.
- **No live update on level-up.** Because this reacts to Blizzard's own `SetText` call rather than
  owning any state, the tag only (re)appears when Blizzard itself redraws the rewards section
  (selecting/reselecting a quest) — matching Blizzard's own staleness if you level up while the
  pane happens to be open.
- **No `X-Curse-Project-ID` yet** — added when the CurseForge project is created.
