---@type Warbandeer
local ns = select(2, ...)
local insert = table.insert
local ui = ns.ui
local Class, Frame = ns.lua.Class, ui.Frame
local LabeledBar = ns.LabeledBar
local theme = ns.theme
local BottomLeft = ui.edge.BottomLeft
local GetMajorFactionIDs = C_MajorFactions.GetMajorFactionIDs
local GetMajorFactionData, GetFactionDataByID = C_MajorFactions.GetMajorFactionData, C_Reputation.GetFactionDataByID
local GetRenownLevels = C_MajorFactions.GetRenownLevels
local GetFriendshipReputation = C_GossipInfo.GetFriendshipReputation
local GetFriendshipReputationRanks = C_GossipInfo.GetFriendshipReputationRanks
local IsFactionParagon = C_Reputation.IsFactionParagon
local GetFactionParagonInfo = C_Reputation.GetFactionParagonInfo

ns.overview = ns.overview or {}

-- Extract r,g,b,a from a ColorMixin or a plain {r,g,b,a} array.
local function rgbaOf(color)
  if not color then return nil end
  if color.GetRGBA then return color:GetRGBA() end
  return color[1], color[2], color[3], color[4]
end

-- Resolve a faction's color: prefer the custom override (ns.data.factionColors),
-- then the API's factionFontColor, then a caller fallback (e.g. the parent faction
-- color for an uncolored subfaction). Returns nameColor, fillColor, r, g, b.
local function colorFor(factionID, apiColor, fallback)
  local col = ns.data.factionColors[factionID] or apiColor or fallback
  if col and col.a == 0 then col.a = 1 end
  local r, g, b = rgbaOf(col)
  return col, (r and {r, g, b, 1} or theme.colors.gold), r, g, b
end

-- For a faction at max renown that has paragon unlocked, return paragon display
-- {value, pct, trackColor}. The track becomes a darker shade of the faction color
-- so paragon reads differently from base rep (dark-grey track). Returns nil when
-- the faction has no usable paragon progress.
local function paragonInfo(factionID, r, g, b)
  if not IsFactionParagon(factionID) then return nil end
  local cur, threshold, _, hasReward = GetFactionParagonInfo(factionID)
  if not (cur and threshold and threshold > 0) then return nil end
  local prog = cur % threshold
  if hasReward and prog == 0 then prog = threshold end -- a claimable bag = full bar
  return {
    numbers = (hasReward and "! " or "") .. prog .. " / " .. threshold,
    pct = prog / threshold,
    trackColor = r and {r * 0.3, g * 0.3, b * 0.3, 0.85} or nil,
  }
end

-- Resolve a faction's bar fields into a row fragment. When maxed, prefer paragon
-- progress (shown as "paragon" text on a darker faction-colored track, with the
-- raw numbers revealed on hover); otherwise show base-rep progress, or "complete"
-- when maxed with no paragon.
local function resolveProgress(factionID, atMax, valueText, pct, r, g, b)
  if atMax then
    local par = paragonInfo(factionID, r, g, b)
    if par then
      return { value = "paragon", hoverValue = par.numbers, pct = par.pct,
               done = false, paragon = true, trackColor = par.trackColor }
    end
    return { value = "complete", pct = 1, done = true }
  end
  return { value = valueText, pct = pct, done = false }
end

-- Collect reputation rows for a given expansion. Each row carries fillColor (the
-- faction color) and an optional trackColor (paragon). Mirrors the prior Factions
-- table logic, plus a fill pct and paragon handling.
local function gatherFactions(expansionLevel, extraFactionIDs)
  local rows, seen = {}, {}

  local function pushFaction(factionID)
    local info = GetMajorFactionData(factionID)
    if not (info and info.name and info.name ~= "") then return end

    local levels = GetRenownLevels(factionID)
    local maxLevel = info.maxLevel or (levels and levels[#levels] and levels[#levels].level)
    local nameColor, fillColor, r, g, b = colorFor(factionID, info.factionFontColor and info.factionFontColor.color)

    local atMax = maxLevel ~= nil and info.renownLevel == maxLevel
    local valueText = info.renownLevel .. " / " .. (maxLevel or "?")
    local pct = (maxLevel and maxLevel > 0) and info.renownLevel / maxLevel or 0
    local prog = resolveProgress(factionID, atMax, valueText, pct, r, g, b)
    insert(rows, {
      name = info.name, value = prog.value, hoverValue = prog.hoverValue,
      pct = prog.pct, done = prog.done, paragon = prog.paragon,
      nameColor = nameColor, fillColor = fillColor, trackColor = prog.trackColor,
    })

    if not ns.data.minorFactions[factionID] then return end
    for _, subID in ipairs(ns.data.minorFactions[factionID]) do
      local subMajor = GetMajorFactionData(subID)
      local subName, subAtMax, subValueText, subPct
      if subMajor and subMajor.renownLevel ~= nil then
        local subMax = subMajor.maxLevel
        if not subMax then
          local subLevels = GetRenownLevels(subID)
          subMax = subLevels and subLevels[#subLevels] and subLevels[#subLevels].level
        end
        subAtMax = subMax and (subMajor.renownLevel == subMax)
        subValueText = subMajor.renownLevel .. " / " .. (subMax or "?")
        subPct = (subMax and subMax > 0) and subMajor.renownLevel / subMax or 0
        subName = subMajor.name
      else
        local friendInfo = GetFriendshipReputation(subID)
        local rankInfo = friendInfo and friendInfo.friendshipFactionID
                         and friendInfo.friendshipFactionID > 0
                         and GetFriendshipReputationRanks(friendInfo.friendshipFactionID)
        if rankInfo and rankInfo.maxLevel > 1 then
          subAtMax = rankInfo.currentLevel >= rankInfo.maxLevel
          subValueText = rankInfo.currentLevel .. " / " .. rankInfo.maxLevel
          subPct = rankInfo.currentLevel / rankInfo.maxLevel
          subName = friendInfo.name
        else
          local subInfo = GetFactionDataByID(subID)
          subAtMax = subInfo.reaction >= 8
          local progress = subInfo.currentStanding - (subInfo.currentReactionThreshold or 0)
          local tierSize = (subInfo.nextReactionThreshold or 0) - (subInfo.currentReactionThreshold or 0)
          subValueText = tierSize > 0 and (progress .. " / " .. tierSize) or tostring(subInfo.currentStanding)
          subPct = tierSize > 0 and progress / tierSize or 0
          subName = subInfo.name
        end
      end
      local subNameColor, subFillColor, sr, sg, sb = colorFor(subID, nil, nameColor)
      local subProg = resolveProgress(subID, subAtMax, subValueText, subPct, sr, sg, sb)
      insert(rows, {
        name = subName, value = subProg.value, hoverValue = subProg.hoverValue,
        pct = subProg.pct, done = subProg.done, paragon = subProg.paragon,
        nameColor = subNameColor, fillColor = subFillColor, trackColor = subProg.trackColor, indent = true,
      })
    end
  end

  for _, factionID in ipairs(GetMajorFactionIDs(expansionLevel)) do
    seen[factionID] = true
    pushFaction(factionID)
  end
  for _, factionID in ipairs(extraFactionIDs) do
    if not seen[factionID] then pushFaction(factionID) end
  end
  return rows
end

-- Stack of reputation progress bars for one expansion.
---@class FactionBars: Frame
---@field expansionLevel number    LE_EXPANSION_* level whose major factions are shown
---@field extraFactionIDs number[] factions to append beyond GetMajorFactionIDs
---@field width number             bar/row width
local FactionBars = Class(Frame, function(self)
  local c = theme.colors
  local rows = gatherFactions(self.expansionLevel, self.extraFactionIDs)
  local totalH, prev = 0, nil
  for i, r in ipairs(rows) do
    local bar = LabeledBar:new{
      parent = self,
      width = self.width,
      label = (r.indent and "  " or "") .. r.name,
      value = r.value,
      hoverValue = r.hoverValue,
      pct = r.pct,
      nameColor = r.nameColor,
      barColor = r.fillColor or c.gold,
      trackColor = r.trackColor,
      valueColor = (r.done or r.paragon) and c.green or c.muted,
      hoverColor = c.muted,
      position = prev and { TopLeft = {prev, BottomLeft, 0, -7} } or { TopLeft = {0, 0} },
    }
    if i > 1 then totalH = totalH + 7 end
    totalH = totalH + bar:Height()
    prev = bar
  end
  self:Width(self.width)
  self:Height(totalH)
end, {
  expansionLevel = 10, -- LE_EXPANSION_THE_WAR_WITHIN
  extraFactionIDs = {},
  width = 230,
})
ns.overview.FactionBars = FactionBars
