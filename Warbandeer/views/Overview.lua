local _, ns = ...
local insert = table.insert
local ui = ns.ui
-- luacheck: globals DIM_GREEN_FONT_COLOR DIM_RED_FONT_COLOR NORMAL_FONT_COLOR GetAchievementInfo OpenAchievementFrameToAchievement BreakUpLargeNumbers
local Class, Frame, TableFrame, TabFrame, Label, Texture = ns.lua.Class, ui.Frame, ui.TableFrame, ui.TabFrame, ui.Label, ui.Texture
local LabeledBar, StatCard = ns.LabeledBar, ns.StatCard
local theme = ns.theme
local BreakUpLargeNumbers = BreakUpLargeNumbers
local GetMajorFactionIDs = C_MajorFactions.GetMajorFactionIDs
local GetMajorFactionData, GetFactionDataByID = C_MajorFactions.GetMajorFactionData, C_Reputation.GetFactionDataByID
local GetRenownLevels = C_MajorFactions.GetRenownLevels
local GetFriendshipReputation = C_GossipInfo.GetFriendshipReputation
local GetFriendshipReputationRanks = C_GossipInfo.GetFriendshipReputationRanks
local IsFactionParagon = C_Reputation.IsFactionParagon
local GetFactionParagonInfo = C_Reputation.GetFactionParagonInfo
local BottomLeft = ui.edge.BottomLeft

local TransparentBackdrop = {color = ns.Colors.TransparentBlack}
local P, GAP, STRIP_H, HEAD_H = 12, 8, 64, 16

-- caps label used for section headers ("REPUTATIONS", "TOP CHARACTERS", ...)
local function capsHeader(parent, text, position)
  return Label:new{
    parent = parent,
    fontInfo = theme.fonts.caps,
    color = theme.colors.muted,
    text = text:upper(),
    position = position,
  }
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

-- Table of top toon per class
local TopAlts = Class(TableFrame, function(self)
  -- fit col 2 to the widest name
  local w = 0
  for _, r in ipairs(self.cells) do
    if r[2] and r[2].label then
      w = math.max(w, r[2].label._widget:GetUnboundedStringWidth())
    end
  end
  if w > 0 then
    local delta = w - self.cols[2]:Width()
    self.cols[2]:Width(w)
    self.rowArea:Width(self.rowArea:Width() + delta)
    self:Width(self:Width() + delta)
  end

  -- brighten the row on hover (rows are transparent at rest)
  for _, row in ipairs(self.rows) do
    row._widget:SetMouseMotionEnabled(true)
    row:SetScript("OnEnter", function() row.backdrop:Color(theme.colors.hover) end)
    row:SetScript("OnLeave", function() row.backdrop:Color(0, 0, 0, 0) end)
  end
end, {
  headerHeight = 0,
  headerWidth = 0,
  colInfo = {
    {width = 20, backdrop = TransparentBackdrop},
    {width = 100, backdrop = TransparentBackdrop},
    {width = 30, backdrop = TransparentBackdrop},
  },
  GetData = function(self)
    local toons = ns.api.GetAllCharacters()
    local top = {}
    for _, toon in pairs(toons) do
      if not top[toon.classKey] or
        toon.basic.level > top[toon.classKey].basic.level or
        (toon.basic.level == top[toon.classKey].basic.level and toon.equipment.ilvl > top[toon.classKey].equipment.ilvl)
      then
        top[toon.classKey] = toon
      end
    end
    top = ns.lua.lists.values(top)
    table.sort(top, function (c1, c2)
      if c1.basic.level ~= c2.basic.level then return c1.basic.level > c2.basic.level end
      if c1.equipment.ilvl ~= c2.equipment.ilvl then return c1.equipment.ilvl > c2.equipment.ilvl end
      return c1.name < c2.name
    end)
    local data = {}
    for _, toon in ipairs(top) do
      self:addRow({backdrop = TransparentBackdrop})
      insert(data, {
        {
          text = toon.basic.level,
          color = NORMAL_FONT_COLOR,
        },
        {
          text = toon.name,
          color = ns.Colors[toon.classKey]
        },
        {
          text = ns.IlvlColor(toon.equipment.ilvl),
          justifyH = ui.justify.Right,
        },
      })
    end
    return data
  end,
})

local wwiAchievementIds     = {20597, 40791, 20596, 40309, 40360, 41052, 40618, 41818, 41970, 41808, 61017}
local midnightAchievementIds = {
  62386, -- Light Up the Night (meta)
  62110, -- Loremaster of Midnight
  62104, -- Midnight Lore Hunter
  61741, -- Delve Loremaster: Midnight
  61506, -- Allied Race: Haranir
  61839, -- (existing)
  62261, -- Forever Song (Eversong Woods story)
  61453, -- Making an Amani Out of You (Zul'Aman story)
  62260, -- That's Aln, Folks! (Harandar story)
  62256, -- Yelling into the Voidstorm (Voidstorm story)
  61957, -- Sojourner of Eversong Woods
  61452, -- Sojourner of Zul'Aman
  61739, -- Sojourner of Harandar
  61864, -- Sojourner of Voidstorm
}

local Achievements = Class(TableFrame, function(self)
  self.data = {}
  for _, achievementId in ipairs(self.achievementIds) do
    self:addRow({backdrop = TransparentBackdrop})
    local row = self.rows[#self.rows]
    local _, name, _, completed = GetAchievementInfo(achievementId)
    if achievementId == 41818 then
       local _, _, _, completedH = GetAchievementInfo(41820)
       completed = completed or completedH
    end
    insert(self.data, {
      {
        text = name,
        color = completed and DIM_GREEN_FONT_COLOR or DIM_RED_FONT_COLOR,
        onClick = function()
          OpenAchievementFrameToAchievement(achievementId)
        end,
        onEnter = function() row.backdrop:Color(theme.colors.hover) end,
        onLeave = function() row.backdrop:Color(0, 0, 0, 0) end,
      },
    })
  end
end, {
  achievementIds = {},
  headerHeight = 0,
  headerWidth = 0,
  colInfo = {
    {width = 200, backdrop = TransparentBackdrop},
  },
})

-- Build one tab's content (reputations left, achievements right). Returns w, h.
local function buildTab(panel, expansionLevel, extraFactionIDs, achievementIds)
  capsHeader(panel, "Reputations", { TopLeft = {0, 0} })
  local bars = FactionBars:new{
    parent = panel,
    expansionLevel = expansionLevel,
    extraFactionIDs = extraFactionIDs,
    position = { TopLeft = {0, -HEAD_H} },
  }
  local achX = bars:Width() + 16
  capsHeader(panel, "Achievements", { TopLeft = {achX, 0} })
  local ach = Achievements:new{
    parent = panel,
    achievementIds = achievementIds,
    position = { TopLeft = {achX, -HEAD_H} },
  }
  return achX + ach:Width(), HEAD_H + math.max(bars:Height(), ach:Height())
end

-- Overview
local Overview = Class(Frame, function(self)
  local c = theme.colors
  local BLEED = 6                        -- module/strip outer bleed (matches module bg padding)
  local contentTop = P + STRIP_H + GAP

  -- Reputations + Achievements tabs (left of the content row)
  self.tabFrame = TabFrame:new{
    parent = self,
    tabs = {"Midnight", "WWI"},
    position = { TopLeft = {P, -contentTop} },
  }
  local midW, midH = buildTab(self.tabFrame:Tab(1), 11, {}, midnightAchievementIds)
  local wwiW, wwiH = buildTab(self.tabFrame:Tab(2), 10, {}, wwiAchievementIds)
  local tabBarH, tabContentH = self.tabFrame.tabHeight, {midH, wwiH}
  local tabW = math.max(midW, wwiW)
  self.tabFrame:Width(tabW)

  -- Top Characters (right of the tabs, beside the future detail card)
  local altX = P + tabW + GAP * 2
  capsHeader(self, "Top Characters", { TopLeft = {altX, -contentTop} })
  self.topAlts = TopAlts:new{
    parent = self,
    position = { TopLeft = {altX, -(contentTop + HEAD_H)} },
  }
  local altH = HEAD_H + self.topAlts:Height()
  local contentW = tabW + GAP * 2 + self.topAlts:Width()

  -- module backgrounds (parent textures render behind the child content frames)
  self._modTab = Texture:new{
    parent = self, layer = ui.layer.Artwork, color = c.module,
    position = { TopLeft = {P - 6, -(contentTop - 6)}, Width = tabW + 12, Height = tabBarH + 12 },
  }
  Texture:new{
    parent = self, layer = ui.layer.Artwork, color = c.module,
    position = { TopLeft = {altX - 6, -(contentTop - 6)}, Width = self.topAlts:Width() + 12, Height = altH + 12 },
  }

  -- Stat strip — aligned to the same outer extent as the module panels below
  local cardW = (contentW + BLEED * 2 - GAP * 2) / 3

  local goldTotal, playSecs, topIlvl, count = 0, 0, 0, 0
  for _, toon in ipairs(ns.api.GetAllCharacters()) do
    count = count + 1
    if toon.currency and toon.currency.gold then goldTotal = goldTotal + toon.currency.gold end
    if toon.playtime and toon.playtime.total then playSecs = playSecs + toon.playtime.total end
    if toon.equipment and toon.equipment.ilvl and toon.equipment.ilvl > topIlvl then
      topIlvl = toon.equipment.ilvl
    end
  end

  local function card(i, caption, amount, amountColor, sub)
    return StatCard:new{
      parent = self,
      caption = caption,
      amount = amount,
      amountColor = amountColor,
      sub = sub,
      position = { TopLeft = {P - BLEED + (i - 1) * (cardW + GAP), -BLEED}, Width = cardW, Height = STRIP_H },
    }
  end
  card(1, "Total Warband Wealth", BreakUpLargeNumbers(math.floor(goldTotal / 10000)) .. "g", c.gold)
  card(2, "Total Playtime", BreakUpLargeNumbers(math.floor(playSecs / 3600)) .. " hrs", c.text,
       "Across " .. count .. " characters")
  card(3, "Top Item Level", tostring(topIlvl), ns.IlvlColorObj(topIlvl))

  -- size to the active tab and refit the window when the tab changes, so the
  -- shorter tab doesn't leave dead space below the content.
  self._fit = function(idx)
    local th = tabBarH + tabContentH[idx]
    self.tabFrame:Height(th)
    self._modTab:Height(th + 12)
    self:Width(P + contentW + P)
    self:Height(contentTop + math.max(altH, th) + P)
    if self.parent and self.parent.Fit then self.parent:Fit() end
  end
  self._fit(self.tabFrame:Selected())
  self.tabFrame.onSelect = function(_, idx) self._fit(idx) end
end, {
  name = "overview",
  _title = "Overview",
  background = theme.colors.window,
})
Overview.name = "overview"
ns.views.Overview = Overview
