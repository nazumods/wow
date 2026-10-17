---@class ShadowsOfUI_Castbar
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.1.5-r2", notes = [==[
### Features
- 12 TOC-only addons load on Forever (16001); HideBagBar skips a missing frame and hides the key ring (#956, merge after #955) (#973)

]==] },
  { version = "12.1.5-r1", notes = [==[
### Maintenance
- target WoW 12.1.5 (Interface 120105) (#947)

]==] },
  { version = "12.1.0-r1", notes = [==[
### Maintenance
- target WoW 12.1.0 (Interface 120100) (#905)

]==] },
  { version = "12.0.7-r6", notes = [==[
### Other Changes
- add curse project

]==] },
  { version = "12.0.7-r5", notes = [==[
### Refactoring
- adopt LibNUI Slider label/valueFormat fold in Castbar + Collected (#397)

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
### Features
- add an optional player cast bar (#273)
]==] },
  { version = "12.0.7-r1", notes = [==[
### Features
- Edit Mode config popup + show hidden bars (#268)
- preview the bars while the settings panel is open (#265)
- scaffold ShadowsOfUI-Castbar — target & focus cast bars (#264)
]==] },
}
