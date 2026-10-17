---@class ShadowsOfUI_Compartment
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.1.5-r2", notes = [==[
### Features
- 12 TOC-only addons load on Forever (16001); HideBagBar skips a missing frame and hides the key ring (#956, merge after #955) (#973)

]==] },
  { version = "12.1.5-r1", notes = [==[
### Maintenance
- target WoW 12.1.5 (Interface 120105) (#947)

]==] },
  { version = "12.1.0-r1", notes = [==[
### Maintenance
- target WoW 12.1.0 (Interface 120100) (#905)

]==] },
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
