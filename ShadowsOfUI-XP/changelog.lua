---@class ShadowsOfUI_XP
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r4", notes = [==[
### Bug Fixes
- restore corrupt ShadowsOfUI logo PNGs from CurseForge (#347)
]==] },
  { version = "12.0.7-r3", notes = [==[
### Bug Fixes
- batch confident Medium-severity fixes from the suite review (#285)
]==] },
  { version = "12.0.7-r2", notes = [==[
### Documentation
- document that hiding Blizzard's tracking bar at max level is intentional (#198)
]==] },
  { version = "12.0.7-r1", notes = [==[
### Other Changes
- Support 12.0.7 + flag uncaptured secondary stats in /wbc missing (#145)
]==] },
}
