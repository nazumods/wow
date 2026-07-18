---@class ShadowsOfUI_Quests
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r5", notes = [==[
### Other Changes
- add curse project

]==] },
  { version = "12.0.7-r4", notes = [==[
### Features
- roll out in-game changelog viewer to all ShadowsOfUI addons (#340) (#376)

]==] },
  { version = "12.0.7-r3", notes = [==[
### Features
- moon-style logo generator + five ShadowsOfUI logos (#348)
]==] },
  { version = "12.0.7-r2", notes = [==[
### Refactoring
- shared ns.Colors hex/code/wrap/className helpers (#261)
]==] },
  { version = "12.0.7-r1", notes = [==[
### Features
- cross-alt quest status (ShadowsOfUI-Quests) (#172)
]==] },
}
