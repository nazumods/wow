---@class ShadowsOfUI_Collectibles
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r7", notes = [==[
### Features
- rework tint preview — controls left, grouped preview right (#518)

]==] },
  { version = "12.0.7-r6", notes = [==[
### Features
- revamped known-item tint palette + in-panel picker & preview (#485)

]==] },
  { version = "12.0.7-r5", notes = [==[
### Features
- decor overlays in bags/bank/Bagnon + shared HousingDecorApi (#477)

]==] },
  { version = "12.0.7-r4", notes = [==[
### Features
- roll out in-game changelog viewer to all ShadowsOfUI addons (#340) (#376)

]==] },
  { version = "12.0.7-r3", notes = [==[
### Features
- moon-style logo generator + five ShadowsOfUI logos (#348)

### Bug Fixes
- gate detection negatives on a loaded tooltip, not the item name (#354)
]==] },
  { version = "12.0.7-r2", notes = [==[
### Performance
- cache negative scan results with event-based invalidation (#291)
]==] },
  { version = "12.0.7-r1", notes = [==[
### Features
- add ShadowsOfUI-Collectibles addon (#274)

### Bug Fixes
- stop overwriting Blizzard merchant/AH cues on untinted rows (#287)
]==] },
}
