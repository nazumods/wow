---@class ShadowsOfUI_PostOffice
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r7", notes = [==[
### Bug Fixes
- give each delete confirm its own letter payload (#756)

]==] },
  { version = "12.0.7-r6", notes = [==[
### Bug Fixes
- delete the clicked mail on confirm, not a fingerprint twin (#590)

]==] },
  { version = "12.0.7-r5", notes = [==[
### Bug Fixes
- reagent-bag edge cases + LibNAddOn enforce round-trip (#447) (#459)

]==] },
  { version = "12.0.7-r4", notes = [==[
### Bug Fixes
- forward attachments into the reagent bag and tear down on mailbox close (#450)
- stop batch-open and confirm-delete acting on stale mail indices (#449)

]==] },
  { version = "12.0.7-r3", notes = [==[
### Features
- ns.wow.CoinString plain-coin formatter; adopt in PostOffice (#406)

]==] },
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
