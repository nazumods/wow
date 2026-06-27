---@type Warbandeer_Collected
local ns = select(2, ...)
-- EPHEMERAL set-review file. Committed EMPTY. Populate it locally with
-- `pwsh tools/update-sets.ps1 -AuditSets` to browse wago sets not yet rendered in
-- collected (in-game: Category -> Review), then `git checkout` this file when done.
-- Never commit a populated copy.
local _ = ns
