---@class ShadowsOfUI_Known
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r7", notes = [==[
### Bug Fixes
- correlate guild recipe responses to their skill line and drop the dead-candidate stall (#847)

]==] },
  { version = "12.0.7-r6", notes = [==[
### Features
- guild crafter lookup on crafting-order tooltips (#580)

]==] },
  { version = "12.0.7-r5", notes = [==[
### Features
- roll out in-game changelog viewer to all ShadowsOfUI addons (#340) (#376)

]==] },
  { version = "12.0.7-r4", notes = [==[
### Bug Fixes
- tooltip-family edge cases (ReqSkill anchor + KnownBy memoize + rep memoGen) (#359)
- restore corrupt ShadowsOfUI logo PNGs from CurseForge (#347)
]==] },
  { version = "12.0.7-r3", notes = [==[
### Features
- show "Known by:" on recipe item tooltips (#275)
]==] },
  { version = "12.0.7-r2", notes = [==[
### Features
- show the profession in the "Not Known" crafting-order line (#272)
- "Known by" on the Place Crafting Order browse list (#271)

### Refactoring
- shared ns:OnItemTooltip item-tooltip hook helper (#262)
- shared ns.Colors hex/code/wrap/className helpers (#261)
]==] },
  { version = "12.0.7-r1", notes = [==[
### Other Changes
- Support 12.0.7 + flag uncaptured secondary stats in /wbc missing (#145)
]==] },
}
