---@class ShadowsOfUI_PostOffice
local ns = select(2, ...)

-- In-game changelog (newest first), shown via the "Changelog" button in this
-- addon's settings. Appended automatically at release by release.sh from the same
-- conventional-commit grouping used for the GitHub/CurseForge release notes.
---@type { version: string, notes: string }[]
ns.changelog = {
  { version = "12.0.7-r0", notes = [==[
### Features
- initial release: coin-collected report, trade blocking at the mailbox, and coin auto-subject (re-derived from Postal's Rake, TradeBlock, and Wire)
]==] },
}
