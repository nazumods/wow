---@class ShadowsOfUI_Reputations
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r8", notes = [==[
### Maintenance
- cleanup

]==] },
  { version = "12.0.7-r7", notes = [==[
### Maintenance
- create curse project for reputations

]==] },
  { version = "12.0.7-r6", notes = [==[
### Features
- roll out in-game changelog viewer to all ShadowsOfUI addons (#340) (#376)

]==] },
  { version = "12.0.7-r5", notes = [==[
### Features
- moon-style logo generator + five ShadowsOfUI logos (#348)

### Bug Fixes
- tooltip-family edge cases (ReqSkill anchor + KnownBy memoize + rep memoGen) (#359)
]==] },
  { version = "12.0.7-r4", notes = [==[
### Bug Fixes
- guard faction-row tooltip on GameTooltip ownership (#318) (#323)
- guard secret spell-cooldown values and nil item-tooltip id (#313, #317) (#322)
]==] },
  { version = "12.0.7-r3", notes = [==[
### Refactoring
- shared ns:OnItemTooltip item-tooltip hook helper (#262)
- shared ns.Colors hex/code/wrap/className helpers (#261)
]==] },
  { version = "12.0.7-r2", notes = [==[
### Bug Fixes
- accept partial faction names in /sreps (#200)

### Performance
- memoize faction-name tooltip lookup per item (#199)
]==] },
  { version = "12.0.7-r1", notes = [==[
### Features
- cross-alt faction standings (ShadowsOfUI-Reputations) (#169)
]==] },
}
