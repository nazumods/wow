---@class ShadowsOfUI_Artisan
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r4", notes = [==[
### Features
- roll out in-game changelog viewer to all ShadowsOfUI addons (#340) (#376)

### Bug Fixes
- gate book badge on SpellButton1 shown to avoid phantom badge in emptied slot (#320) (#366)

]==] },
  { version = "12.0.7-r3", notes = [==[
### Features
- show the Moxie badge on the Crafting Orders tab (#296)

### Bug Fixes
- place the orders badge beside the OrderView concentration, not over it (#299)
]==] },
  { version = "12.0.7-r2", notes = [==[
### Refactoring
- shared ns.Colors hex/code/wrap/className helpers (#261)
]==] },
  { version = "12.0.7-r1", notes = [==[
### Features
- badge the crafting window too, beside concentration
- add ShadowsOfUI-Artisan profession-currency badge

### Style
- size, colour, and centre the crafting-window badge by concentration
]==] },
}
