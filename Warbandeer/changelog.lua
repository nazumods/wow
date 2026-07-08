---@class Warbandeer
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in
-- Warbandeer settings. Appended automatically at release by release.sh from the
-- same conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r16", notes = [==[
### Features
- show guild name in the character summary tooltip (#390)

]==] },
  { version = "12.0.7-r15", notes = [==[
### Features
- in-game changelog viewer, wired for Warbandeer (#340) (#375)
- add settings for default bar-apply toggle states (#336) (#374)

### Bug Fixes
- heal Summary cell fonts on cold-session first open (#357) (#373)

]==] },
  { version = "12.0.7-r14", notes = [==[
### Features
- Unalloyed Abundance summary column + throttle delves rescan (#320) (#361)

### Bug Fixes
- four view edge cases (ilvl tooltip order, faction-color mutation, achievement refresh, soonest-expiry) (#356)

### Documentation
- #320 safe doc/dead-code batch (partial) (#351)
]==] },
  { version = "12.0.7-r13", notes = [==[
### Features
- recommended consumables box from ClassCodex (#269)
- right-click the rail logo for the Settings + views menu (#270)
- daily playtime tracking
- Alt+W keybinding — tap to toggle, hold for a radial view selector (#212)

### Bug Fixes
- auto-load Bindings.xml + group under a Warbandeer category
- restore the 1px border on the titlebar filter pickers (#260)

### Refactoring
- shared ns.Colors hex/code/wrap/className helpers (#261)
- split summaryCol/profs.lua craft hints into profsCraft.lua (#258)
- split ReputationsView into reps/ data + render files (#256)
]==] },
  { version = "12.0.7-r12", notes = [==[
### Features
- track weekly Delver's Bounty per character (#249)

### Bug Fixes
- scroll range should match the filtered row count (#248)
- say "appearances" instead of "cells" in user-facing text (#247)

### Refactoring
- extract ProfsView data/helpers to profs/ProfsData.lua (#255)
- split Overview.lua into views/overview/ files (#254)
]==] },
  { version = "12.0.7-r11", notes = [==[
### Features
- Tier C — 100% coverage + Trading Post (#222) (#240)
]==] },
  { version = "12.0.7-r10", notes = [==[
### Features
- expansion + category filters in a shared strip; FilterDropdown → LibNUI (#234)
- PTR set preview — live/PTR toggle for upcoming sets (#225)

### Bug Fixes
- PTR preview crash + show only upcoming sets when toggled (#228)
- survive 12.1.0 rename of OpenAchievementFrameToAchievement (#227)

### Refactoring
- reuse the standalone DataView in Warbandeer's collected view (#230)
]==] },
  { version = "12.0.7-r9", notes = [==[
### Features
- add a settings toggle for the minimap button (#218)
]==] },
  { version = "12.0.7-r8", notes = [==[
### Features
- show the view menu on compartment right-click (#217)
- flag pending mail with an envelope that trumps the count (#210)
- add a minimap button (#215)
]==] },
  { version = "12.0.7-r7", notes = [==[
### Features
- per-character Catalyst Unbound indicator (#209)
- track Shard of Dundun (weekly Abundance currency) (#208)
- this-patch playtime + equal-thirds section layout (#207)

### Refactoring
- rename the 'Midnight' view to 'Milestones' (#211)
]==] },
  { version = "12.0.7-r6", notes = [==[
### Features
- add wanted/tier icons to overview tier sets
- swap arrow-key pairs (Up/Down select, Left/Right page) (#192)
- tooltips on Top Characters ilvl + set cells (#185)
- wanted flag + S/A/B/C/F tier ranking for transmog sets

### Bug Fixes
- sync the embedded view header with the /collected window (#204)
- honor a column's own click action instead of always opening Detail (#197)
- guard missing weeklies table in the DMF column (#196)
- correct the Catch-up column tooltip text (#194)
- compute gear-upgrade column off the render frame (#191)
- show cloaks in set tooltip and live-refresh counts (#181)
- update grid view when set rating changes
- ensure Summary columns backing table; namespace setting variables

### Maintenance
- rename /wb repsdebug to /wb reps0 (#201)

### Documentation
- annotate ShowGemTooltip on the Warbandeer class (#195)
- clarify debug message for uncategorized factions
]==] },
  { version = "12.0.7-r5", notes = [==[
### Features
- warband-wide reputations view on the Warbandeer nav bar (#177)
- owned-auction tracking + expiry Summary column (#171)
- cross-alt mail tracking + expiry warnings (#167)
- green Up count when an upgrade is equippable now (#161)
- hover enchant/socket notes for what they grant (#159)
- confirm before accepting a wrong enchant on right-click
- add /wb enchants list + clear for accepted wrong-enchants
- flag wrong (non-recommended) enchants with a per-item accept list

### Bug Fixes
- handle secret combat-rating values in the stat grid (#168)
- keep adequate spacing between columns after hides (#160)
]==] },
  { version = "12.0.7-r4", notes = [==[
### Features
- include the active spec in the header subtitle
- name the mastery tooltip after the character's spec
- explain each secondary stat on its percentage hover
- let over-target stat vertices overshoot the guide up to 1.2x
- add secondary-stat radar chart to the stat grid

### Bug Fixes
- resolve spec data from the played spec, not the loot spec
- plot the stat radar as target fulfilment, not rating balance
]==] },
  { version = "12.0.7-r3", notes = [==[
### Features
- clear warband-bank upgrade markers when the item is withdrawn (#156)
- click a suggested upgrade to flash it in open bags/bank (#152)
- add per-column show/hide settings (#151)
- track Untainted Mana-Crystals currency column (#150)
]==] },
  { version = "12.0.7-r2", notes = [==[
### Features
- ilvl addon
- prefix suggested upgrade line with red [UP] -> tag (#147)

### Other Changes
- Merge branch 'main' of https://github.com/nazumods/wow
]==] },
  { version = "12.0.7-r1", notes = [==[
### Features
- hover tooltip on a stat cell showing target status (#146)
- secondary-stat panel with top-stat highlight (#144)
- detect empty gem sockets + recommend a gem (#140)
- recommend which enchant to apply to a missing slot (#138)
- surface missing-enchant gaps in tooltip + Warbandeer views (#136)

### Bug Fixes
- recommend the unique diamond on one socket, fill the rest (#143)
- stack gear sub-line notes (upgrade / enchant / socket) on separate lines (#142)

### Other Changes
- Support 12.0.7 + flag uncaptured secondary stats in /wbc missing (#145)
]==] },
}
