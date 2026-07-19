---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r12", notes = [==[
### Maintenance
- add curse project

]==] },
  { version = "12.0.7-r11", notes = [==[
### Features
- roll out in-game changelog viewer to all ShadowsOfUI addons (#340) (#376)

]==] },
  { version = "12.0.7-r9", notes = [==[
### Bug Fixes
- weapon proficiency for wands, Titan's Grip, Hunter and Evoker (#301-304) (#321)
- type-guard the spec name before :lower() in ccClassSpec (#292)
]==] },
  { version = "12.0.7-r8", notes = [==[
### Features
- recommended consumables box from ClassCodex (#269)

### Refactoring
- shared ns:OnItemTooltip item-tooltip hook helper (#262)
- shared ns.Colors hex/code/wrap/className helpers (#261)
]==] },
  { version = "12.0.7-r7", notes = [==[
### Refactoring
- split ShadowsOfUI-Upgrade's two oversized files (#252)
]==] },
  { version = "12.0.7-r6", notes = [==[
### Bug Fixes
- two "Wrong enchant" false positives (name prefix + uncached spellthread scroll) (#237)
]==] },
  { version = "12.0.7-r5", notes = [==[
### Bug Fixes
- compare spellthread (leg) enchants by stat, not name (#187)
]==] },
  { version = "12.0.7-r4", notes = [==[
### Features
- only recommend enchants/gems at max level (#164)
- skip enchants for items below the minimum enchantable ilvl (#162)
- green Up count when an upgrade is equippable now (#161)
- flag wrong (non-recommended) enchants with a per-item accept list
]==] },
  { version = "12.0.7-r3", notes = [==[
### Bug Fixes
- resolve spec data from the played spec, not the loot spec
- match ClassCodex "Helm" enchant onto the Head slot

### Maintenance
- add /supgrade enchants dev dump for enchant resolution
]==] },
  { version = "12.0.7-r2", notes = [==[
### Bug Fixes
- never recommend a legacy artifact to an offline alt (#157)
- count empty sockets via GetItemGemID, not GetItemStats (#155)
- never suggest a two-hander to an off-hand wielder (#153)
]==] },
  { version = "12.0.7-r10", notes = [==[
### Bug Fixes
- enchant-flagging edge cases — ilvl-floor gate + thousands separators (#305) (#330)

### Maintenance
- five Low hygiene items (#306) (#331)
]==] },
  { version = "12.0.7-r1", notes = [==[
### Features
- secondary-stat panel with top-stat highlight (#144)
- detect empty gem sockets + recommend a gem (#140)
- recommend which enchant to apply to a missing slot (#138)
- surface missing-enchant gaps in tooltip + Warbandeer views (#136)

### Bug Fixes
- recommend the unique diamond on one socket, fill the rest (#143)
- stack gear sub-line notes (upgrade / enchant / socket) on separate lines (#142)
- correct enchantable slots for Midnight (#139)
- suppress upgrade note for BoP items

### Other Changes
- Support 12.0.7 + flag uncaptured secondary stats in /wbc missing (#145)
]==] },
}
