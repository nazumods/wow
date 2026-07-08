---@class ShadowsOfUI_PostOffice
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r2", notes = [==[
### Features
- port Select inbox checkboxes + batch open/return (Phase 4b) (#400)
- shared inbox-row decorator + DoNotWant (Phase 4a) (#392)
- port QuickAttach trade-goods buttons (Phase 3b) (#389)
- port BlackBook recipient picker + autocomplete (Phase 3a) (#388)
- port Forward and CarbonCopy (Phase 2) (#385)
- port Express modifier-click shortcuts (#383)

]==] },
  { version = "12.0.7-r1", notes = [==[
### Features
- add ShadowsOfUI-PostOffice mailbox helper (#381)

]==] },
  { version = "12.0.7-r0", notes = [==[
### Features
- initial release: coin-collected report, trade blocking at the mailbox, and coin auto-subject (re-derived from Postal's Rake, TradeBlock, and Wire)
]==] },
}
