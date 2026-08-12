---@class ShadowsOfUI_Ilvl
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.1.0-r1", notes = [==[
### Maintenance
- target WoW 12.1.0 (Interface 120100) (#905)

]==] },
  { version = "12.0.7-r4", notes = [==[
### Features
- roll out in-game changelog viewer to all ShadowsOfUI addons (#340) (#376)

]==] },
  { version = "12.0.7-r3", notes = [==[
### Bug Fixes
- DMF pin pooling, Ilvl stale-paint guard, Alias live name, HideBagBar ipairs (#320) (#363)
]==] },
  { version = "12.0.7-r2", notes = [==[
### Features
- show avg ilvl in inspect pane
]==] },
  { version = "12.0.7-r1", notes = [==[
### Features
- overlay item level + track on Bagnon/Bagnonium bags (#148)
- ilvl addon
]==] },
}
