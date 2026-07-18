---@class ShadowsOfUI_WarbandInventory
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r4", notes = [==[
### Features
- roll out in-game changelog viewer to all ShadowsOfUI addons (#340) (#376)

]==] },
  { version = "12.0.7-r3", notes = [==[
### Features
- add logo + reusable Tooling/ logo generator (#346)
]==] },
  { version = "12.0.7-r2", notes = [==[
### Refactoring
- shared ns:OnItemTooltip item-tooltip hook helper (#262)
- shared ns.Colors hex/code/wrap/className helpers (#261)
]==] },
  { version = "12.0.7-r1", notes = [==[
### Features
- rename tooltip header to "Warband Inventory" (#174)
- cross-alt mail tracking + expiry warnings (#167)
- cross-alt item-count tooltip (ShadowsOfUI-WarbandInventory) (#165)
]==] },
}
