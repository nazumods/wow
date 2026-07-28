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
-- GetAchievementInfo, and the desktop app resolves them offline from its generated static-data
-- bundle, which filters Achievement.db2 down to the ids data/achievementcatalog.lua declares.
-- Adding an id there needs a bundle regeneration (Tooling/update-static-data.ps1) to render.

-- **This snapshot only ever grows within a build.** Completion and points are both monotonic, so
-- every write here is OR-ed against what is already stored rather than replacing it — see
-- `captureOne` for why a cold login read would otherwise blank the whole account's answer (#733).

---@class AchievementSnapshotEntry
---@field completed boolean  account-wide completion state; STICKY — never returns to false within a build
---@field wasEarnedByMe boolean  per-character earned-credit flag; last-captured character wins (deliberately not sticky)

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

-- Points are monotonic per account, so a zero is a cold read rather than a real total — writing it
-- would blank a good one. Nothing legitimate is masked by the guard: the total never decreases.
local function capturePoints()
  local points = GetTotalAchievementPoints()
  if points and points > 0 then ns.db.achievements.totalPoints = points end
end

-- Completion is monotonic too: an account-completed achievement never un-completes. So a live
-- `false` is indistinguishable from "the achievement API hasn't answered yet" on a cold login, and
-- taking it at face value replaces the account-wide snapshot every character reads with an empty
-- one (#733). OR against what is stored instead — the sticky-read pattern data/weekly.lua and
-- data/quests.lua already use for the same hazard.
--
-- `wasEarnedByMe` is deliberately NOT sticky. It is documented above as per-character,
-- last-captured-character-wins; OR-ing it would quietly promote that to any-character-wins, which
-- is a different contract rather than a repaired one.
local function captureOne(id)
  local _, _, _, completed, _, _, _, _, _, _, _, _, wasEarnedByMe = GetAchievementInfo(id)
  local prev = ns.db.achievements.snapshot[id]
  ns.db.achievements.snapshot[id] = {
    completed = completed == true or (prev and prev.completed) == true,
    wasEarnedByMe = wasEarnedByMe or false,
  }
end

---Snapshot every tracked achievement's completion + wasEarnedByMe, and the account's total
---achievement points.
---@class Warbandeer_Characters
---@field CaptureAchievements fun()
function ns:CaptureAchievements()
  for id in pairs(TRACKED) do captureOne(id) end
  capturePoints()
end

---Login-time setup: ensure the store exists, capture the full snapshot, then keep it fresh
---on ACHIEVEMENT_EARNED. Called once per session from `initialize()`.
---@class Warbandeer_Characters
---@field InitAchievements fun()
function ns:InitAchievements()
  if not self.db.achievements then self.db.achievements = { snapshot = {}, totalPoints = 0 } end
  self:CaptureAchievements()
  ns:registerEvent("ACHIEVEMENT_EARNED", function(_, achievementId)
    -- Above the TRACKED guard on purpose (#745-1): the points total is account-wide, so it moves
    -- for ANY achievement earned. Gating it on the checklist left the stored total disagreeing
    -- with the game until something else happened to trigger a capture.
    capturePoints()
    if not TRACKED[achievementId] then return end
    captureOne(achievementId)
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
