---@type Warbandeer_Characters
local ns = select(2, ...)
local GetAchievementInfo = GetAchievementInfo
local GetTotalAchievementPoints = GetTotalAchievementPoints

-- Account-wide achievement snapshot. Unlike per-character brokers, achievement completion
-- is (mostly) shared across the whole account, so it lives once at the DB top level
-- (`db.achievements`) rather than being duplicated into every character. `wasEarnedByMe` is
-- genuinely per-character, but is captured here from whichever character last triggered a
-- snapshot (login or ACHIEVEMENT_EARNED) rather than tracked per alt — a deliberate
-- simplification matching this store's account-wide shape.
--
-- Names are intentionally NOT persisted here — the addon can always resolve them live via
-- GetAchievementInfo; a name catalog for the desktop app is deferred to #639.

---@class AchievementSnapshotEntry
---@field completed boolean  account-wide completion state
---@field wasEarnedByMe boolean  per-character earned-credit flag; last-captured character wins

-- Every tracked achievement id (checklist expansions + milestones grid + legion grid, plus
-- each catalog metaAlt pair), deduped. Built once from data/achievementcatalog.lua.
local TRACKED = {}
do
  local cat = ns.AchievementCatalog
  local function add(id) TRACKED[id] = true end
  for _, list in pairs(cat.checklist) do
    for _, id in ipairs(list) do add(id) end
  end
  for _, id in ipairs(cat.milestones) do add(id) end
  for _, id in ipairs(cat.legion) do add(id) end
  for id, alt in pairs(cat.metaAlts) do add(id); add(alt) end
end

local function captureOne(id)
  local _, _, _, completed, _, _, _, _, _, _, _, _, wasEarnedByMe = GetAchievementInfo(id)
  ns.db.achievements.snapshot[id] = { completed = completed or false, wasEarnedByMe = wasEarnedByMe or false }
end

---Snapshot every tracked achievement's completion + wasEarnedByMe, and the account's total
---achievement points.
---@class Warbandeer_Characters
---@field CaptureAchievements fun()
function ns:CaptureAchievements()
  for id in pairs(TRACKED) do captureOne(id) end
  self.db.achievements.totalPoints = GetTotalAchievementPoints()
end

---Login-time setup: ensure the store exists, capture the full snapshot, then keep it fresh
---on ACHIEVEMENT_EARNED. Called once per session from `initialize()`.
---@class Warbandeer_Characters
---@field InitAchievements fun()
function ns:InitAchievements()
  if not self.db.achievements then self.db.achievements = { snapshot = {}, totalPoints = 0 } end
  self:CaptureAchievements()
  ns:registerEvent("ACHIEVEMENT_EARNED", function(_, achievementId)
    if not TRACKED[achievementId] then return end
    captureOne(achievementId)
    ns.db.achievements.totalPoints = GetTotalAchievementPoints()
  end)
end

ns:registerDump("achievements", "Achievement Snapshot", "Dump tracked achievement snapshot", function(self, out)
  local a = self.db.achievements
  if not a then out:line("No achievement data yet."); return end
  local total, done = 0, 0
  for _, e in pairs(a.snapshot) do
    total = total + 1
    if e.completed then done = done + 1 end
  end
  out:line("Tracked: " .. done .. "/" .. total .. " completed")
  out:line("Total achievement points: " .. (a.totalPoints or 0))
end)
