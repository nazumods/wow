---@class ShadowsOfUI_ProfCommissions
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r2", notes = [==[
### Features
- moon-style logo generator + five ShadowsOfUI logos (#348)

### Bug Fixes
- reward border/count + align reward-icon column to the money zone (#360)
]==] },
  { version = "12.0.7-r1", notes = [==[
### Features
- new addon — reward icons + first-craft/reagent Info column on the Crafting Orders list (#297)
]==] },
}
