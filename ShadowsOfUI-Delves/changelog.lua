---@class ShadowsOfUI_Delves
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
  { version = "12.0.7-r5", notes = [==[
### Documentation
- correct five drifted doc/comment/annotation spots (#455)

]==] },
  { version = "12.0.7-r4", notes = [==[
### Features
- show avg XP + XP/hr on delve pin tooltip (leveling) (#414)
- Timer widget + shared ns.lua.strings.duration formatter (#405)

]==] },
  { version = "12.0.7-r3", notes = [==[
### Bug Fixes
- open /sdelves output in a copyable window (#382)

]==] },
  { version = "12.0.7-r2", notes = [==[
### Features
- roll out in-game changelog viewer to all ShadowsOfUI addons (#340) (#376)

]==] },
  { version = "12.0.7-r1", notes = [==[
### Features
- track personal delve completion times + entrance-pin tooltip
]==] },
}
