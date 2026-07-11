---@class ShadowsOfUI_HousingVendor
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r1", notes = [==[
### Features
- housing decor owned-count + first-acquisition overlay at vendors (#465)

]==] },
  { version = "12.0.7-r0", notes = [==[
### Features
- add ShadowsOfUI-HousingVendor addon (#463)
]==] },
}
