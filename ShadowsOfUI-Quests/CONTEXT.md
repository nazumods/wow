# ShadowsOfUI-Quests

**Deps:** LibNAddOn, Warbandeer_Characters · **OptionalDeps:** Warbandeer · **SavedVars:** none · **Commands:** `/squests <questID>` (dev/lookup) · **API:** reads `WarbandeerApi`

Headless addon. Adds a cross-alt "Also on this quest / Completed by" block to the world-map
quest-log tooltip. Assignment-form init (`local ns = LibNAddOn(...)`); no LibNUI, no DB. All
data comes from Warbandeer_Characters' `questlog` broker via `WarbandeerApi:GetQuestStatus`.

## Files

| File | Purpose |
|---|---|
| `core.lua` | Bootstrap + `ns.AppendQuestStatus(tooltip, questID)`: the shared block (class-coloured names via `ns.Colors.className`). Reads `WarbandeerApi:GetQuestStatus`, drops the current character (`names()` excludes `GetCurrentCharacter()`, caps at `MAX` 6 + "+N more"), emits an "Also on this quest:" line and/or a "Completed by:" line; returns false (nothing added) when no *other* character is involved. |
| `log.lua` | `EventRegistry:RegisterCallback("QuestMapLogTitleButton.OnEnter", …)` → appends the block to `GameTooltip` (with the questID the event passes), re-`Show`s it. `/squests` dev/lookup command. |

## How it hooks

The modern quest log lives on the world map (`QuestMapFrame`). `QuestMapLogTitleButton_OnEnter`
fires the `EventRegistry` event `"QuestMapLogTitleButton.OnEnter"` with `(button, questID)` after
building the row's tooltip — an exact, taint-free hook point (no item→quest guessing). We append
and re-`Show` (the row already showed its tooltip, so the added lines need a resize).

## Gotchas

- **Last-seen data.** A character's active set + completed history refresh while it's logged in
  (the broker scans each login + on quest events). `/wbc missing` flags "quest history" for
  never-seen characters.
- **Completed history is a bitmap** in the data layer (32-bit slots — see
  `Warbandeer_Characters/data/questlog.lua`); this addon never touches the bits, only
  `GetQuestStatus`.
- **Own character excluded.** You're looking at your own quest log, so `AppendQuestStatus` lists
  only *other* characters; the block is suppressed entirely when none apply.
- **No `X-Curse-Project-ID` yet** — added when the CurseForge project is created.
