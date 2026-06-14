---@type Warbandeer_Characters
local ns = select(2, ...)
---@type WarbandeerAPI
local API = ns.api
local insert = table.insert
local GetTime = GetTime
local GetServerTime = GetServerTime
local C_Map = C_Map
local C_TaskQuest = C_TaskQuest
local C_Item = C_Item
local GetNumQuestLogRewards = GetNumQuestLogRewards
local GetQuestLogRewardInfo = GetQuestLogRewardInfo
local GetQuestLogItemLink = GetQuestLogItemLink
local HaveQuestRewardData = HaveQuestRewardData

-- Per-character cache of active world-quest gear rewards that would upgrade an
-- equipped slot.  World-quest reward data is only readable for the *logged-in*
-- character (and only while the quest is active), so — like the bank/gear caches —
-- each character scans its own quests when logged in and stores the qualifying
-- gear rewards (last-seen model).  The Suggested box reads this cache for whichever
-- character is displayed; the upgrade evaluation (is it actually an upgrade for a
-- slot) lives in ShadowsOfUI-Upgrade, which consumes WarbandeerApi:GetWorldQuestRewards.
-- We keep only equippable gear (API:ClassifyGearItem), which makes the cache tiny.
--
-- Each reward is structurally a GearCandidate (so ShadowsOfUI-Upgrade's evaluate can
-- read it directly) plus its quest metadata: questID, title, zone, and an endTime
-- so expired quests can be dropped on read (an alt's cache can't be refreshed live).

-- Map ID(s) of the current expansion's world-quest continent.  Expanded to their
-- zone children at scan time, so every current WQ zone is covered no matter which
-- one the player stands in; older expansions are different continents and never
-- scanned (their rewards can't be current-content upgrades anyway).
local WQ_CONTINENTS = { 2537 } -- Quel'Thalas (Midnight); zone children = Eversong, Silvermoon, …

-- World-quest gear tops out around the Adventurer reward track (ilvl ~220).  A
-- character whose every equipped slot already meets that cap can't be upgraded by
-- any world quest, so the (map-walking) scan is skipped for them entirely.
local WQ_ILVL_CEILING = 220

-- Don't re-scan more often than this on the noisy QUEST_LOG_UPDATE stream.
local SCAN_THROTTLE = 60 -- seconds

---@class WorldQuestReward: GearCandidate
---@field questID integer source world quest
---@field title string world-quest title
---@field zone string? zone (map) name the quest is in
---@field endTime integer? server time the quest expires (nil = unknown / no timer)

-- Resolved WQ zone map IDs, cached after the first build (map topology is static
-- for a client session).
local zoneCache
local function wqZones()
  if zoneCache then return zoneCache end
  zoneCache = {}
  for _, continent in ipairs(WQ_CONTINENTS) do
    for _, child in ipairs(C_Map.GetMapChildrenInfo(continent, Enum.UIMapType.Zone, true) or {}) do
      insert(zoneCache, child.mapID)
    end
  end
  return zoneCache
end

local mapNames = {}
local function mapName(mapID)
  if mapNames[mapID] == nil then
    local info = C_Map.GetMapInfo(mapID)
    mapNames[mapID] = (info and info.name) or false
  end
  return mapNames[mapID] or nil
end

-- The character's lowest equipped slot ilvl (an empty/unscanned set → 0, so the
-- ceiling gate never skips a barely-known character).
local function lowestEquippedIlvl(toon)
  local slots = toon.equipment and toon.equipment.slots
  if not slots then return 0 end
  local low
  for _, s in pairs(slots) do
    local il = s.ilvl or 0
    if not low or il < low then low = il end
  end
  return low or 0
end

-- The first gear reward of a world quest as a GearCandidate, or nil when the quest
-- has no reward / the reward isn't equippable gear.  Caller must have confirmed the
-- reward data is loaded (HaveQuestRewardData).
local function gearReward(questID)
  if (GetNumQuestLogRewards(questID) or 0) == 0 then return nil end
  local _, _, _, _, _, itemID, itemLevel = GetQuestLogRewardInfo(1, questID)
  if not itemID then return nil end
  local equipLoc, classID, subClassID = API:ClassifyGearItem(itemID)
  if not equipLoc then return nil end -- not equippable gear (currency, mats, …)
  local link = GetQuestLogItemLink("reward", 1, questID)
  if not link then return nil end
  return {
    link = link,
    itemID = itemID,
    -- The reward's own ilvl (already scaled to this character) — matches how the
    -- character's equipped slots are measured for the same character.
    ilvl = itemLevel or C_Item.GetDetailedItemLevelInfo(link),
    equipLoc = equipLoc,
    classID = classID,
    subClassID = subClassID,
  }
end

-- Scan every current WQ zone for active gear-reward quests.  Returns the qualifying
-- rewards (cache replaces the stored list wholesale — last-seen).  Quests whose
-- reward data isn't loaded yet are preloaded and picked up on the next scan.
---@param toon Character
---@return WorldQuestReward[]
local function scanWorldQuests(_, toon)
  -- Fully geared past the reward ceiling → nothing a world quest could improve.
  if lowestEquippedIlvl(toon) >= WQ_ILVL_CEILING then return {} end

  local rewards, seen = {}, {}
  local now = GetServerTime()
  for _, mapID in ipairs(wqZones()) do
    for _, poi in ipairs(C_TaskQuest.GetQuestsOnMap(mapID) or {}) do
      local questID = poi.questID or poi.questId
      if questID and not seen[questID] and C_TaskQuest.IsActive(questID) then
        seen[questID] = true
        if HaveQuestRewardData(questID) then
          local cand = gearReward(questID)
          if cand then
            local secs = C_TaskQuest.GetQuestTimeLeftSeconds(questID)
            cand.questID = questID
            cand.title = C_TaskQuest.GetQuestInfoByQuestID(questID) or ("Quest " .. questID)
            cand.zone = mapName(mapID)
            cand.endTime = (secs and secs > 0) and (now + secs) or nil
            insert(rewards, cand)
          end
        else
          C_TaskQuest.RequestPreloadRewardData(questID)
        end
      end
    end
  end
  return rewards
end

---@class Character
---@field worldquests { rewards: WorldQuestReward[] }?

---@class WorldQuests: Broker
ns.WorldQuests = ns:RegisterBroker("worldquests")

local lastScan = 0
ns.WorldQuests.fields = {
  ---@type BrokerField
  rewards = {
    maxLevel = true, -- world quests are max-level content
    get = scanWorldQuests,
    event = { "QUEST_LOG_UPDATE", "ZONE_CHANGED_NEW_AREA" },
    -- QUEST_LOG_UPDATE is very noisy and the maxLevel guard isn't applied to events,
    -- so throttle hard and gate on level here ourselves.
    eventHandler = function(field, currentValue)
      local toon = ns.currentData
      if not toon or toon.basic.level < ns.wow.maxLevel then return end
      local now = GetTime()
      if now - lastScan < SCAN_THROTTLE then return end
      lastScan = now
      field:set(field:get(toon, currentValue))
    end,
  },
}

ns:registerCommand("dump", "wq", function()
  ns.Print("World-quest zones scanned: " .. table.concat(wqZones(), ", "))
  for _, c in pairs(ns.db.characters) do
    local list = c.worldquests and c.worldquests.rewards
    if list and #list > 0 then
      ns.Print(c.name .. ": " .. #list .. " cached WQ reward(s)")
      for _, r in ipairs(list) do
        print(("  %s +%s — %s (%s)"):format(r.link or r.itemID, r.ilvl or "?",
          r.title or "?", r.zone or "?"))
      end
    end
  end
end, "Dump cached world-quest gear rewards")
