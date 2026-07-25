---@type Warbandeer_Characters
local ns = select(2, ...)
local floor, min = math.floor, math.min
local GetServerTime = GetServerTime
local PerksActivities = C_PerksActivities
local PerksProgram = C_PerksProgram

-- Account-wide monthly Trading Post "Traveler's Log" progress + rewards-waiting
-- snapshot. The activity bar and Trader's Tender are shared across the whole
-- warband, so this lives once at `db.travelersLog` rather than per character
-- (the data/warband.lua account-wide pattern). Derivation mirrors Blizzard's own
-- Adventure Guide UI (Blizzard_MonthlyActivities.lua `UpdateActivities`): earned =
-- sum of completed activities' contribution, capped at the largest threshold; the
-- % is earned/max. Rewards-waiting joins the pending chest rewards back to their
-- thresholds by order index (matching Blizzard's `HasPendingReward`).

---@class TravelersLogRewards
---@field count integer          uncollected chest rewards waiting (any month)
---@field pendingTender integer  Trader's Tender granted by this month's pending thresholds
---@field items integer[]        reward itemIDs at this month's pending thresholds (for icons)
---@field itemInfo table<integer, {name: string?, icon: integer?}>  display metadata per reward itemID, captured at refresh time (absent on snapshots taken before the field existed)

---@class TravelersLogData
---@field month integer          activePerksMonth (the server month id)
---@field monthName string       display month name (e.g. "July")
---@field resetAt integer        server-time of the monthly reset
---@field earned integer         contribution points earned (capped at max)
---@field max integer            largest threshold requirement (the monthly cap)
---@field pct number             earned / max (0..1)
---@field completedCount integer completed activities this month
---@field totalCount integer     total activities this month
---@field tender integer         current spendable Trader's Tender balance
---@field rewards TravelersLogRewards

-- Build the compact snapshot from the raw API tables.
---@param info table   C_PerksActivities.GetPerksActivitiesInfo()
---@param pending table C_PerksProgram.GetPendingChestRewards()
---@param currency integer C_PerksProgram.GetCurrencyAmount()
---@param prev table<integer, {name: string?, icon: integer?}>? the last snapshot's `rewards.itemInfo`, so a cold item keeps its captured name
---@return TravelersLogData
local function derive(info, pending, currency, prev)
  local thresholdMax = 0
  for _, t in pairs(info.thresholds) do
    if t.requiredContributionAmount > thresholdMax then thresholdMax = t.requiredContributionAmount end
  end
  local earned, completed, total = 0, 0, 0
  for _, a in pairs(info.activities) do
    total = total + 1
    if a.completed then
      completed = completed + 1
      earned = earned + a.thresholdContributionAmount
    end
  end
  earned = min(earned, thresholdMax)

  -- Rewards waiting: `count` is every pending chest reward (so a prior month's
  -- uncollected chest still flags "go collect"); the Tender/item detail is joined
  -- from this month's pending thresholds only (that's all we can attribute).
  local count, pendingByIndex = 0, {}
  for _, r in pairs(pending) do
    count = count + 1
    if r.activityMonthID == info.activePerksMonth then pendingByIndex[r.thresholdOrderIndex] = true end
  end
  -- `items` stays the plain id list it has always been; the display metadata rides
  -- alongside in `itemInfo` so an offline reader can label/ico the reward strip
  -- without a client. Nil-tolerant — a reward item still cold this pass just fills
  -- in on the next refresh (the whole snapshot is re-derived on every Perks event).
  local pendingTender, items, itemInfo = 0, {}, {}
  for _, t in pairs(info.thresholds) do
    if pendingByIndex[t.thresholdOrderIndex] then
      pendingTender = pendingTender + (t.currencyAwardAmount or 0)
      if t.itemReward then
        items[#items + 1] = t.itemReward
        local name = C_Item.GetItemInfo(t.itemReward)
        -- Only an id is available here (no link), so the name needs the item cache
        -- warm. Request the load on a miss and keep whatever the last refresh
        -- captured — a Perks event re-derives the whole snapshot shortly after.
        if not name then
          C_Item.RequestLoadItemDataByID(t.itemReward)
          name = prev and prev[t.itemReward] and prev[t.itemReward].name or nil
        end
        itemInfo[t.itemReward] = { name = name, icon = C_Item.GetItemIconByID(t.itemReward) or nil }
      end
    end
  end

  return {
    month = info.activePerksMonth,
    monthName = info.displayMonthName,
    resetAt = GetServerTime() + (info.secondsRemaining or 0),
    earned = earned,
    max = thresholdMax,
    pct = thresholdMax > 0 and (earned / thresholdMax) or 0,
    completedCount = completed,
    totalCount = total,
    tender = currency or 0,
    rewards = { count = count, pendingTender = pendingTender, items = items, itemInfo = itemInfo },
  }
end

-- Re-read live data and re-derive the snapshot. Bails (keeping the last snapshot)
-- when the Trading Post feature is unavailable or its data hasn't arrived yet, so
-- a pre-data login doesn't blank a good stored snapshot.
local function refresh()
  if not PerksActivities then return end
  local info = PerksActivities.GetPerksActivitiesInfo()
  if not (info and info.thresholds and next(info.thresholds)) then return end
  local pending = (PerksProgram and PerksProgram.GetPendingChestRewards()) or {}
  local currency = (PerksProgram and PerksProgram.GetCurrencyAmount()) or 0
  local cur = ns.db.travelersLog
  ns.db.travelersLog = derive(info, pending, currency, cur and cur.rewards and cur.rewards.itemInfo)
end

---Login-time setup: ensure the store exists, request pending chest rewards (async),
---take an initial read, and hook the four Perks events that change the snapshot.
---@class Warbandeer_Characters
---@field InitTravelersLog fun()
function ns:InitTravelersLog()
  if not self.db.travelersLog then
    self.db.travelersLog = { pct = 0, rewards = { count = 0, pendingTender = 0, items = {}, itemInfo = {} } }
  end
  if PerksProgram then PerksProgram.RequestPendingChestRewards() end
  refresh()
  ns:registerEvent("PERKS_ACTIVITIES_UPDATED", refresh)
  ns:registerEvent("PERKS_ACTIVITY_COMPLETED", function()
    -- crossing a threshold can mint a new pending reward; re-request then re-derive
    if PerksProgram then PerksProgram.RequestPendingChestRewards() end
    refresh()
  end)
  ns:registerEvent("CHEST_REWARDS_UPDATED_FROM_SERVER", refresh)
  ns:registerEvent("PERKS_PROGRAM_CURRENCY_REFRESH", refresh)
end

ns:registerDump("travelerslog", "Traveler's Log", "Dump Traveler's Log progress + rewards", function(self, out)
  local t = self.db.travelersLog
  if not t or not t.month then out:line("No Traveler's Log data yet."); return end
  local r = t.rewards or {}
  out:line("Traveler's Log — " .. (t.monthName or "?"))
  out:line(("Progress: %d%% (%d / %d)"):format(floor((t.pct or 0) * 100 + 0.5), t.earned or 0, t.max or 0))
  out:line("Activities: " .. (t.completedCount or 0) .. " / " .. (t.totalCount or 0))
  out:line("Trader's Tender: " .. (t.tender or 0))
  out:line("Rewards waiting: " .. (r.count or 0) ..
    " (" .. (r.pendingTender or 0) .. " Tender, " .. #(r.items or {}) .. " item(s))")
  out:line("Resets in: " .. math.max(0, floor(((t.resetAt or 0) - GetServerTime()) / 86400)) .. "d")
end)
