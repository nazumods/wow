---@class ShadowsOfUI_DMF
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r2", notes = [==[
### Bug Fixes
- DMF pin pooling, Ilvl stale-paint guard, Alias live name, HideBagBar ipairs (#320) (#363)
- guard auto-buy against a 0/nil maxStack hang and extended-cost items (#353)
]==] },
  { version = "12.0.7-r1", notes = [==[
### Other Changes
- Support 12.0.7 + flag uncaptured secondary stats in /wbc missing (#145)
]==] },
}
