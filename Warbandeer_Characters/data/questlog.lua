---@type Warbandeer_Characters
local ns = select(2, ...)
local C_QuestLog = C_QuestLog
local floor = math.floor
local bor, band, lshift = bit.bor, bit.band, bit.lshift

-- Completed quests are packed into a bitmap of 32-bit slots: slot = floor(questID/32),
-- bit = questID%32. **32 bits per slot, not 64** — WoW Lua numbers are doubles (53-bit
-- mantissa) and `bit.*` is 32-bit, so packing 64 per number silently dropped the high bits
-- (Altoholic Reborn H5). Membership is tested with `band` (never arithmetic), so bit 31
-- packing to 0x80000000 (a negative 32-bit int) round-trips fine.
local SLOT_BITS = 32

local function pack(ids)
  local map = {}
  for _, qid in ipairs(ids) do
    if qid and qid > 0 then
      local slot = floor(qid / SLOT_BITS)
      map[slot] = bor(map[slot] or 0, lshift(1, qid % SLOT_BITS))
    end
  end
  return map
end

-- Whether a packed completed-quest map contains questID. Exposed for api.lua's cross-alt
-- query (the bitmap shape is private to this file).
---@param map table<integer, integer>?
---@param questID integer
---@return boolean
function ns.IsQuestCompleted(map, questID)
  local bits = map and map[floor(questID / SLOT_BITS)]
  if not bits then return false end
  return band(bits, lshift(1, questID % SLOT_BITS)) ~= 0
end

-- The character's currently-active quests as a { [questID] = true } set (headers skipped).
local function scanActive()
  local active = {}
  for i = 1, (C_QuestLog.GetNumQuestLogEntries() or 0) do
    local info = C_QuestLog.GetInfo(i)
    if info and not info.isHeader and info.questID and info.questID > 0 then
      active[info.questID] = true
    end
  end
  return active
end

---@class QuestLogBroker
---@field active table<integer, boolean>  currently-active quests
---@field completed table<integer, integer>  completed-quest bitmap (32-bit slots)

---@class Character
---@field questlog QuestLogBroker?

---@class QuestLogBroker: Broker
local QuestLog = ns:RegisterBroker("questlog")

QuestLog.fields = {
  active = {
    missing = { label = "quest history", order = 100 },
    get = function() return scanActive() end,
    event = { "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN" },
    eventDelay = 1000,
  },
  -- Full re-pack of GetAllCompletedQuestIDs (tens of thousands of ids) — cheap enough at
  -- login + on the (debounced) turn-in event, which coalesces quest-chain bursts.
  completed = {
    missing = false,
    get = function() return pack(C_QuestLog.GetAllCompletedQuestIDs() or {}) end,
    event = "QUEST_TURNED_IN",
    eventDelay = 3000,
  },
}
