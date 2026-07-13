---@class ShadowsOfUI_Compartment
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r5", notes = [==[
### Bug Fixes
- dedupe "Addon Compartment" settings entry (#489)

]==] },
  { version = "12.0.7-r4", notes = [==[
### Bug Fixes
- counter-convert scale when restoring the button position (#452)

]==] },
  { version = "12.0.7-r3", notes = [==[
### Bug Fixes
- open /scompartment to its settings category by ID (#384)

]==] },
  { version = "12.0.7-r2", notes = [==[
### Features
- roll out in-game changelog viewer to all ShadowsOfUI addons (#340) (#376)

]==] },
  { version = "12.0.7-r1", notes = [==[
### Features
- movable addon-compartment button with custom icon (#188)
]==] },
}
