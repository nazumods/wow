---@type Warbandeer
local ns = select(2, ...)
local insert = table.insert
local ui = ns.ui
local Class, Frame, Texture = ns.lua.Class, ui.Frame, ui.Texture
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

-- Blizzard atlases for a claimable paragon reward (the same the in-game rep UI shows).
local ATLAS_BAG, ATLAS_GLOW = "ParagonReputation_Bag", "ParagonReputation_Glow"
local PARAGON_BAG_SIZE = 14

-- A small paragon reward bag with a glow halo and a looping breathe/pulse, flagging a
-- maxed faction whose paragon chest is ready to claim. Returns the container Frame for
-- the caller to anchor; WoW auto-pauses the animation while the frame is hidden.
---@param parent Frame
---@param size number?
---@return Frame
function ns.overview.ParagonBag(parent, size)
  size = size or PARAGON_BAG_SIZE
  local f = Frame:new{ parent = parent, position = { Width = size, Height = size } }
  local glow = Texture:new{
    parent = f, layer = ui.layer.Overlay, blendMode = "ADD",
    position = { Center = {0, 0}, Width = size * 1.9, Height = size * 1.9 },
  }
  glow:Atlas(ATLAS_GLOW, false)
  glow:SetVertexColor(1, 0.95, 0.6, 1)
  glow._widget:SetAlpha(0.25)
  local bag = Texture:new{
    parent = f, layer = ui.layer.Overlay,
    position = { Center = {0, 0}, Width = size, Height = size },
  }
  bag:Atlas(ATLAS_BAG, false)
  bag:DrawLayer("OVERLAY", 2)

  local scaleAg = f._widget:CreateAnimationGroup()
  scaleAg:SetLooping("BOUNCE")
  local sc = scaleAg:CreateAnimation("Scale")
  sc:SetDuration(0.85); sc:SetScaleFrom(1, 1); sc:SetScaleTo(1.18, 1.18)
  sc:SetOrigin("CENTER", 0, 0)
  scaleAg:Play()

  local glowAg = glow._widget:CreateAnimationGroup()
  glowAg:SetLooping("BOUNCE")
  local ga = glowAg:CreateAnimation("Alpha")
  ga:SetDuration(0.85); ga:SetFromAlpha(0.2); ga:SetToAlpha(0.7)
  glowAg:Play()

  f._scaleAg, f._glowAg = scaleAg, glowAg
  return f
end

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
  -- apiColor is Blizzard's cached factionFontColor ColorMixin; clone before forcing
  -- opaque so an alpha-0 API colour doesn't get written back onto the shared object.
  if col and col.a == 0 then col = CreateColor(col.r, col.g, col.b, 1) end
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
    hasReward = hasReward,
    numbers = prog .. " / " .. threshold,
    pct = prog / threshold,
    trackColor = r and {r * 0.3, g * 0.3, b * 0.3, 0.85} or nil,
  }
end

-- Resolve a faction's bar fields into a row fragment. When maxed, prefer paragon
-- progress (shown as "paragon" text on a darker faction-colored track, with the
-- raw numbers revealed on hover; a claimable paragon chest instead shows a gold
-- bag + "claim"); otherwise show base-rep progress, or "complete" when maxed with
-- no paragon.
local function resolveProgress(factionID, atMax, valueText, pct, r, g, b)
  if atMax then
    local par = paragonInfo(factionID, r, g, b)
    if par then
      return { value = par.hasReward and "claim" or "paragon",
               hoverValue = par.numbers, pct = par.pct, done = false,
               paragon = true, reward = par.hasReward, trackColor = par.trackColor }
    end
    return { value = "complete", pct = 1, done = true }
  end
  return { value = valueText, pct = pct, done = false }
end

-- Seasonal reputations name themselves "<thing>: Season N" (e.g. "Delves: Season 1");
-- every other faction is evergreen. Returns the season number, or nil when evergreen.
local function seasonOf(name)
  local n = name and name:match("Season%s+(%d+)")
  return n and tonumber(n) or nil
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
      pct = prog.pct, done = prog.done, paragon = prog.paragon, reward = prog.reward,
      nameColor = nameColor, fillColor = fillColor, trackColor = prog.trackColor,
      season = seasonOf(info.name),
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
        pct = subProg.pct, done = subProg.done, paragon = subProg.paragon, reward = subProg.reward,
        nameColor = subNameColor, fillColor = subFillColor, trackColor = subProg.trackColor,
        indent = true, season = seasonOf(subName),
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
---@field rewardCount number       factions with a claimable paragon reward (for the picker badge)
---@field seasons number[]         sorted distinct season numbers among the seasonal reps
---@field _rows table[]            ordered { bar = LabeledBar, season = number? }
---@field _season number|string    currently shown season ("all" or a number)
local FactionBars = Class(Frame, function(self)
  local c = theme.colors
  local rows = gatherFactions(self.expansionLevel, self.extraFactionIDs)
  self._rows = {}
  local seasonSet, rewardCount = {}, 0
  for _, r in ipairs(rows) do
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
      valueColor = r.reward and c.gold or (r.done or r.paragon) and c.green or c.muted,
      hoverColor = c.muted,
      position = { TopLeft = {0, 0} }, -- real position assigned by _layout
    }
    -- a claimable paragon chest gets the animated reward bag left of its "claim" value
    if r.reward then
      rewardCount = rewardCount + 1
      ns.overview.ParagonBag(bar):Right(bar.valueLabel, ui.edge.Left, -3, 0)
    end
    self._rows[#self._rows + 1] = { bar = bar, season = r.season }
    if r.season then seasonSet[r.season] = true end
  end
  self.rewardCount = rewardCount -- unfiltered total, so the badge still counts hidden-season chests
  self.seasons = {}
  for s in pairs(seasonSet) do self.seasons[#self.seasons + 1] = s end
  table.sort(self.seasons)
  self._season = "all"
  self:_layout()
end, {
  expansionLevel = 10, -- LE_EXPANSION_THE_WAR_WITHIN
  extraFactionIDs = {},
  width = 230,
})

-- Stack the visible bars top-to-bottom. A seasonal bar shows only when its season is
-- the selected one (or "all"); evergreen bars (season == nil) always show. Re-anchors
-- the shown bars so a hidden row leaves no gap, and sizes the frame to the visible run.
function FactionBars:_layout()
  local totalH, prev = 0, nil
  for _, e in ipairs(self._rows) do
    local show = self._season == "all" or e.season == nil or e.season == self._season
    e.bar:SetShown(show)
    if show then
      e.bar:ClearAllPoints()
      if prev then
        e.bar:TopLeft(prev, BottomLeft, 0, -7)
        totalH = totalH + 7
      else
        e.bar:TopLeft(0, 0)
      end
      totalH = totalH + e.bar:Height()
      prev = e.bar
    end
  end
  self:Width(self.width)
  self:Height(totalH)
end

-- Filter to a season ("all" or a number) and return the new height so the Overview can
-- resize the panel around it.
---@param season number|string
---@return number
function FactionBars:SetSeason(season)
  self._season = season or "all"
  self:_layout()
  return self:Height()
end
ns.overview.FactionBars = FactionBars
