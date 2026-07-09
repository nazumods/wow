---@type ShadowsOfUI_Delves
local ns = select(2, ...)

local floor = math.floor
local Player = ns.wow.Player
local LABEL = NORMAL_FONT_COLOR
local MUTED = GRAY_FONT_COLOR

-- Append the current character's average completion time for `poiName` to a tooltip (or a muted
-- "no runs" hint for a delve we haven't timed), plus an average-XP line for leveling characters.
-- Returns false when there's nothing to show.
---@param tooltip table
---@param poiName string?
---@return boolean appended
local function appendDelveTime(tooltip, poiName)
  if not poiName then return false end
  local stats = ns.api:GetDelveStats(poiName, ns.AssumedTier())
  local me = ns.api:GetCurrentCharacter()
  local mine
  if stats then
    for _, s in ipairs(stats) do
      if s.name == me then mine = s; break end
    end
  end
  if mine then
    local label = mine.scope ~= "all" and ("Avg completion (%s): "):format(mine.scope) or "Avg completion: "
    local runs = MUTED:WrapTextInColorCode(("· %d run%s"):format(mine.count, mine.count == 1 and "" or "s"))
    local tail = mine.scope == "all" and (" " .. MUTED:WrapTextInColorCode("(all tiers)")) or ""
    tooltip:AddLine(LABEL:WrapTextInColorCode(label) .. ns.FormatDuration(mine.avg) .. "  " .. runs .. tail, nil, nil, nil, true)

    -- Leveling value: average XP per run + XP/hr (avg XP ÷ avg time).  Leveling-only — XP isn't
    -- tracked at max level, and an explicit cap gate (mirroring ShadowsOfUI-QuestXP) drops any
    -- stale leveling-run XP still lingering in the rolling window on a freshly-capped character.
    if not Player:isMaxLevel() and mine.avgXp and mine.avgXp > 0 then
      local xpLabel = mine.scope ~= "all" and ("Avg XP (%s): "):format(mine.scope) or "Avg XP: "
      local rate = ""
      if mine.avg > 0 then
        local perHour = floor(mine.avgXp / mine.avg * 3600 + 0.5)
        rate = "  " .. MUTED:WrapTextInColorCode(("· %s XP/hr"):format(AbbreviateNumbers(perHour)))
      end
      tooltip:AddLine(LABEL:WrapTextInColorCode(xpLabel) .. BreakUpLargeNumbers(mine.avgXp) .. rate, nil, nil, nil, true)
    end
  else
    tooltip:AddLine(MUTED:WrapTextInColorCode("No timed runs yet"), nil, nil, nil, true)
  end
  return true
end

-- Delve entrance pins build their tooltip in AreaPOIPinMixin:OnMouseEnter; hook it, gate to delve
-- pins via C_AreaPoiInfo.GetDelvesForMap, append our line, and re-Show so the tooltip resizes
-- around it (mirrors ShadowsOfUI-Quests).  Shift hides the block (suite convention).
local function onPinEnter(pin)
  if IsShiftKeyDown() then return end
  local poiInfo = pin.poiInfo
  local areaPoiID = (poiInfo and poiInfo.areaPoiID) or pin.areaPoiID
  if not areaPoiID then return end
  local map = pin.GetMap and pin:GetMap()
  local mapID = map and map.GetMapID and map:GetMapID()
  if not mapID then return end
  local delves = C_AreaPoiInfo.GetDelvesForMap(mapID)
  local isDelve = false
  if delves then
    for _, id in ipairs(delves) do
      if id == areaPoiID then isDelve = true; break end
    end
  end
  if not isDelve then return end
  local name = poiInfo and poiInfo.name
  if not name then
    local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, areaPoiID)
    name = info and info.name
  end
  if appendDelveTime(GameTooltip, name) then GameTooltip:Show() end
end

-- Delve entrance pins use DelveEntrancePinMixin, which lives in Blizzard_SharedMapDataProviders —
-- a LoadOnDemand package that only loads with the World Map, AFTER us. So the mixin is nil at
-- login; defer the hook until that package loads (ContinueOnAddOnLoaded fires immediately if it's
-- already up). We hook DelveEntrancePinMixin directly, not the AreaPOIPinMixin base: the delve pin
-- is a CreateSubPin of it, and CreateSubPin COPIES the parent's methods, so a base-mixin hook never
-- reaches the copy the pins actually call. Guarded so a client/mixin rename just disables the line.
EventUtil.ContinueOnAddOnLoaded("Blizzard_SharedMapDataProviders", function()
  if DelveEntrancePinMixin and DelveEntrancePinMixin.OnMouseEnter then
    hooksecurefunc(DelveEntrancePinMixin, "OnMouseEnter", onPinEnter)
  end
end)
