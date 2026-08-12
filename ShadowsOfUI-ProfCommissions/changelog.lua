---@class ShadowsOfUI_ProfCommissions
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
  { version = "12.0.7-r6", notes = [==[
### Features
- gold glow for rare rewards in the reward column (#752)

]==] },
  { version = "12.0.7-r5", notes = [==[
### Other Changes
- add curse project

]==] },
  { version = "12.0.7-r4", notes = [==[
### Features
- flag unlearned recipes with a red ⊗ in the Info column (#435)

]==] },
  { version = "12.0.7-r3", notes = [==[
### Features
- roll out in-game changelog viewer to all ShadowsOfUI addons (#340) (#376)

]==] },
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
