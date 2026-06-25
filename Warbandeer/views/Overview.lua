---@type Warbandeer
local ns = select(2, ...)
local insert = table.insert
local floor, max = math.floor, math.max
local ui = ns.ui
local Class, Frame, TableFrame, Label, Texture = ns.lua.Class, ui.Frame, ui.TableFrame, ui.Label, ui.Texture
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
-- 12.1.0 renamed OpenAchievementFrameToAchievement -> ShowAchievementFrameForAchievement
local OpenAchievement = ShowAchievementFrameForAchievement or OpenAchievementFrameToAchievement

local TransparentBackdrop = {color = ns.Colors.TransparentBlack}
local P, GAP, STRIP_H, HEAD_H = 12, 8, 64, 16
local TREND_ICON = "Interface\\AddOns\\Warbandeer\\icons\\"

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

-- ─── Top Characters gear columns ────────────────────────────────────────────
-- The Top Characters table appends one column per raid difficulty (RF/N/H/M)
-- showing how many appearance pieces of the selected raid's class set that class
-- still needs, mirroring the Collected view (number missing, or a green check
-- when complete). Data is read from the sibling Collected addon via the
-- WarbandeerCollectedApi global (OptionalDep). The four difficulty variants of a
-- raid are sibling Collected groups that share one group id and differ only by the
-- difficulty suffix in their name (see Warbandeer_Collected/data/sets.lua).
-- Like the Collected view, each set cell also carries the wanted-star + tier-letter
-- overlays (TopAlts:_refreshMarks/_applyCellMarks), a Shift-click wanted toggle, and a
-- live refresh on dressing-room rating edits (the OnRatingsChanged listener below).

-- Raids selectable via the titlebar dropdown; `key` is the shared Collected group id.
local RAIDS = {
  { key = 372, label = "Voidspire" },
}
local DEFAULT_RAID = RAIDS[1].key

-- Difficulty columns in display order; `suffix` matches the Collected group-name suffix.
local DIFFS = {
  { label = "RF", suffix = "Raid Finder" },
  { label = "N",  suffix = "Normal" },
  { label = "H",  suffix = "Heroic" },
  { label = "M",  suffix = "Mythic" },
}
local GEAR_W = 26   -- width of each difficulty column
local STAR = 11     -- wanted-star overlay size (matches the /collected DataView grid)

-- 10-shade red→green gradient keyed by collected fraction (matches the /collected DataView grid).
local shades = {
  {165/255,   0/255,  38/255, 1},
  {215/255,  48/255,  39/255, 1},
  {244/255, 109/255,  67/255},
  {253/255, 174/255,  97/255},
  {254/255, 224/255, 139/255},
  {217/255, 239/255, 139/255},
  {166/255, 217/255, 106/255},
  {102/255, 189/255,  99/255},
  { 26/255, 152/255,  80/255},
  {      0, 104/255,  55/255},
}

local GreenCheck = {
  atlas = ns.icons.CheckGreen,
  atlasSize = false,
  position = { Center = {}, Size = {13, 13} },
}

-- Resolve a raid id to its four difficulty groups, keyed by difficulty suffix.
---@param api table?  WarbandeerCollectedApi (nil when Collected isn't loaded)
---@param raidId number
---@return table<string, table>  suffix -> Collected group
local function raidGroups(api, raidId)
  local out = {}
  if not api then return out end
  for _, grp in ipairs(api.Sets) do
    if grp.id == raidId then
      for _, d in ipairs(DIFFS) do
        if grp.name:find(d.suffix, 1, true) then out[d.suffix] = grp end
      end
    end
  end
  return out
end

-- Cell data for one class's set in one difficulty: green check when complete, the
-- uncollected count (red→green shaded) otherwise, "–" when unscanned, blank when
-- the class has no set or Collected isn't available. A scanned cell carries the
-- Collected view's own hover/click — hover shows the shared per-slot source InfoTip,
-- left-click opens the 3D dressing room, Shift-click toggles the set's wanted flag.
-- Every real set cell carries its setId so _refreshMarks can draw the wanted-star +
-- tier-letter overlays. GetData's decorate() wraps the hover to also drive the row
-- highlight (and falls back to opening Detail where there's no set click).
---@param tbl TopAlts  owning table (for _applyCellMarks on the wanted toggle)
---@param api table?  WarbandeerCollectedApi
---@param grp table?  the difficulty group, or nil
---@param classId number
---@return table  cell data
local function gearCell(tbl, api, grp, classId)
  if not (api and grp) then return {} end
  local set = grp.sets[classId]
  if not (set and set.id) then return {} end
  local status = api:SetStatus(grp.id, set.id)
  if not status then
    return { setId = set.id, text = "–", justifyH = ui.justify.Center, color = theme.colors.muted }
  end
  local onEnter = function(c) api:ShowInfoTip(grp, set, c, ns.InfoTipPosition(c)) end
  local onLeave = function() api:HideInfoTip() end
  -- Left-click previews the set; Shift-click flags/unflags it wanted (button-agnostic,
  -- matching the Collected view) and re-applies this cell's overlays from live state.
  local onClick = function(c)
    if IsShiftKeyDown() then
      api:ToggleWanted(set.id)
      tbl:_applyCellMarks(c, set.id)
    else
      api:ShowDressingRoom(grp, set)
    end
  end
  if status == true or status.collected >= status.total then
    return {
      setId = set.id,
      atlas = GreenCheck.atlas, atlasSize = GreenCheck.atlasSize,
      position = GreenCheck.position,
      onEnter = onEnter, onLeave = onLeave, onClick = onClick,
    }
  end
  return {
    setId = set.id,
    text = status.total - status.collected,
    justifyH = ui.justify.Center,
    color = shades[max(1, floor(status.collected / status.total * 10))],
    fontInfo = ns.theme.fonts.number,
    onEnter = onEnter, onLeave = onLeave, onClick = onClick,
  }
end

-- Static + difficulty columns for the Top Characters table (level / name / ilvl,
-- then one centered column per RF/N/H/M difficulty).
local topAltsCols = {
  {width = 20, backdrop = TransparentBackdrop},
  {width = 100, backdrop = TransparentBackdrop},
  {width = 30, backdrop = TransparentBackdrop},
}
for _, d in ipairs(DIFFS) do
  insert(topAltsCols, {
    width = GEAR_W, name = d.label,
    justifyH = ui.justify.Center, backdrop = TransparentBackdrop,
  })
end

-- Table of top toon per class
---@class TopAlts: TableFrame
---@field _toons Character[]  row index -> character (kept in sync by GetData)
---@field _raidId number      currently selected raid (Collected group id)
---@field _playerRace number? cached canonical race id the tier-letter overlays resolve against
---@field GetData fun(self: TopAlts): table  builds the top-character rows
---@field SetRaid fun(self: TopAlts, raidId: number)  re-render gear cells for a raid
---@field Refresh fun(self: TopAlts)  rebuild rows from current data + raid
---@field _refreshMarks fun(self: TopAlts)  re-apply every set cell's wanted/tier overlays
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
  -- Hover/click is driven per-cell (see GetData's decorate), not by a mouse-enabled
  -- row: an interactive row sits above the cells and swallows their tooltips/clicks.
  self:_refreshMarks()   -- the constructor-time update() ran before our override was mixed in
end, {
  headerHeight = 18,
  headerWidth = 0,
  _raidId = DEFAULT_RAID,
  colInfo = topAltsCols,
  GetData = function(self)
    local toons = ns.api.GetAllCharacters()
    local top = {}
    for _, toon in pairs(toons) do
      if not top[toon.classKey] or ns.byLevelIlvl(toon, top[toon.classKey]) then
        top[toon.classKey] = toon
      end
    end
    top = ns.lua.lists.values(top)
    table.sort(top, ns.byLevelIlvl)
    local api = WarbandeerCollectedApi
    local groups = raidGroups(api, self._raidId)
    local data = {}
    self._toons = {}
    for idx, toon in ipairs(top) do
      -- addRow only for genuinely new rows so GetData is re-runnable (raid change /
      -- OnBeforeShow) without duplicating rows; update() reuses the existing cells.
      if not self.rows[idx] then self:addRow({backdrop = TransparentBackdrop}) end
      insert(self._toons, toon)

      -- Cells drive hover + click (the row isn't mouse-enabled): like
      -- SummaryView:decorateRow, every cell chains the row highlight onto its hover
      -- and opens Detail on click unless it carries its own (ilvl → Gear, set →
      -- dressing room). idx is resolved lazily so the closures survive re-sorts.
      local function decorate(cell, defaultClick)
        local onEnter, onLeave, onClick = cell.onEnter, cell.onLeave, cell.onClick
        cell.onEnter = function(c) self:_hover(idx, true);  if onEnter then onEnter(c) end end
        cell.onLeave = function(c) self:_hover(idx, false); if onLeave then onLeave(c) end end
        cell.onClick = onClick or defaultClick
        return cell
      end
      local function openDetail() self:_openDetail(idx) end

      -- Per-slot ilvl breakdown for the ilvl-cell tooltip (matches the Summary column).
      local ilvlLines = ns.IlvlTooltipLines(toon)
      local row = {
        decorate({
          text = toon.basic.level,
          color = NORMAL_FONT_COLOR,
          fontInfo = ns.theme.fonts.number,
        }, openDetail),
        decorate({
          text = toon.name,
          color = ns.Colors[toon.classKey],
        }, openDetail),
        decorate({
          text = ns.IlvlColor(ns.ilvlOf(toon)),
          justifyH = ui.justify.Right,
          fontInfo = ns.theme.fonts.number,
          onEnter = function(c)
            if #ilvlLines == 0 then return end
            ns.AnchorTip(c)
            ui.tip:ClearLines()
            for _, l in ipairs(ilvlLines) do ui.tip:AddLine(l) end
            ui.tip:Show()
          end,
          onLeave = function() ui.tip:Hide() end,
          onClick = function() ns:view("gear") end,
        }, openDetail),
      }
      for _, d in ipairs(DIFFS) do
        insert(row, decorate(gearCell(self, api, groups[d.suffix], toon.classId), openDetail))
      end
      insert(data, row)
    end
    return data
  end,
})

-- Highlight (or clear) row `i` — transparent at rest, theme hover on enter. Called
-- from every cell's hover (the row itself isn't mouse-enabled; cells drive it).
---@param i integer  row index
---@param on boolean
function TopAlts:_hover(i, on)
  local row = self.rows[i]
  if not row then return end
  if on then row.backdrop:Color(theme.colors.hover) else row.backdrop:Color(0, 0, 0, 0) end
end

-- Open row `i`'s character in the Detail view.
---@param i integer  row index
function TopAlts:_openDetail(i)
  local win, toon = ns.MainWindow, self._toons[i]
  if not (win and toon) then return end
  win:getView("detail"):Select(toon)
  win:view("detail")
end

-- Apply (or clear) one cell's rating overlays from live Collected DB state: a gold
-- wanted star top-left, the tier letter in its tier color top-right. Cells carry only
-- their setId, so a re-apply after any toggle / re-sort / rating edit is enough; the
-- overlay children are created lazily and reused (shown/hidden), like the Collected grid.
---@param cell Cell
---@param setId number?
function TopAlts:_applyCellMarks(cell, setId)
  local api = WarbandeerCollectedApi
  if api and setId and api:IsWanted(setId) then
    if not cell._wantStar then
      cell._wantStar = Texture:new{
        parent = cell, layer = ui.layer.Overlay,
        atlas = api.WantedIcon, atlasSize = false,
        position = { TopLeft = {1, -1}, Size = {STAR, STAR} },
      }
    end
    cell._wantStar:Show()
  elseif cell._wantStar then
    cell._wantStar:Hide()
  end

  local rank = api and setId and api:EffectiveRank(setId, self._playerRace)
  if rank then
    if not cell._rankPip then
      cell._rankPip = Label:new{
        parent = cell, layer = ui.layer.Overlay, fontObj = "GameFontNormalSmall",
        position = { TopRight = {-1, 0} },
      }
    end
    cell._rankPip:Text(rank)
    cell._rankPip:Color(api.RankColors[rank])
    cell._rankPip:Show()
  elseif cell._rankPip then
    cell._rankPip:Hide()
  end
end

-- Re-apply every cell's overlays from current Collected DB state (non-set cells carry
-- no setId, so they blank). Cheap enough to run on every update()/re-sort and the
-- ratings-changed refresher; cells persist across re-sorts so their overlays do too.
function TopAlts:_refreshMarks()
  local api = WarbandeerCollectedApi
  self._playerRace = api and api:PlayerRace()
  for r = 1, #self.cells do
    local row = self.cells[r]
    for c = 1, #self.cols do
      local cell = row[c]
      if cell then
        local data = cell.data
        self:_applyCellMarks(cell, type(data) == "table" and data.setId or nil)
      end
    end
  end
end

-- Refresh overlays after the base table (re)builds its cells.
function TopAlts:update()
  TableFrame.update(self)
  self:_refreshMarks()
end

-- Rebuild rows + cells from current character data and the selected raid.
function TopAlts:Refresh()
  self.data = self:GetData()
  self:update()
end

-- Switch the gear columns to a different raid and re-render.
---@param raidId number
function TopAlts:SetRaid(raidId)
  if self._raidId == raidId then return end
  self._raidId = raidId
  self:Refresh()
end

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

-- Single-column achievement checklist for one expansion.
---@class OverviewAchievements: TableFrame
---@field achievementIds number[]  achievement IDs to list, in display order
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
          OpenAchievement(achievementId)
        end,
        onEnter = function() row.backdrop:Color(theme.colors.hover) end,
        onLeave = function() row.backdrop:Color(0, 0, 0, 0) end,
      },
    })
  end
  self:update()
end, {
  achievementIds = {},
  headerHeight = 0,
  headerWidth = 0,
  colInfo = {
    {width = 200, backdrop = TransparentBackdrop},
  },
})

-- Build one expansion's content into `panel`: a Reputations box (left) and an
-- Achievements box (right), each under its own caps header. The two sit a box-gap
-- (GAP*2) apart so each can carry its own module background. Returns the reps and
-- achievements section sizes (width, height) for the caller to size those boxes.
local function buildTab(panel, expansionLevel, extraFactionIDs, achievementIds)
  capsHeader(panel, "Reputations", { TopLeft = {0, 0} })
  local bars = FactionBars:new{
    parent = panel,
    expansionLevel = expansionLevel,
    extraFactionIDs = extraFactionIDs,
    position = { TopLeft = {0, -HEAD_H} },
  }
  -- Achievements is moved into its own equal-thirds column by the caller once the
  -- shared column width is known; the X here is a placeholder.
  local achHead = capsHeader(panel, "Achievements", { TopLeft = {0, 0} })
  local ach = Achievements:new{
    parent = panel,
    achievementIds = achievementIds,
    position = { TopLeft = {0, -HEAD_H} },
  }
  panel._ach = ach -- reachable for the cold-session font heal (and /wb cells)
  return bars:Width(), bars:Height(), ach:Width(), ach:Height(), achHead
end

-- Expansions selectable via the titlebar dropdown. Each builds its own
-- Reputations + Achievements panel; only the selected one is shown.
local EXPANSIONS = {
  { key = "midnight", label = "Midnight",       expansionLevel = 11, extraFactionIDs = {}, achievementIds = midnightAchievementIds },
  { key = "wwi",      label = "The War Within", expansionLevel = 10, extraFactionIDs = {}, achievementIds = wwiAchievementIds },
}

-- Swap every cell label's font away and back (same size/flags) to force the
-- client to re-rasterize the string. See the cold-session note in the ctor.
local function healCellFonts(tbl)
  for _, row in pairs(tbl.cells) do
    for _, cell in pairs(row) do
      if cell.label then
        local f = cell.label:Font()
        cell.label:Font({"Fonts\\FRIZQT__.TTF", f[2], f[3]})
        cell.label:Font(f)
      end
    end
  end
end

-- Overview
---@class Overview: Frame
---@field topAlts TopAlts
---@field _panels table<string, Frame>   expansion key -> reps+achievements panel
---@field _repsH table<string, number>   expansion key -> reputations section height
---@field _achH table<string, number>    expansion key -> achievements section height
---@field _altH number                   Top Characters section height
---@field _contentW number               total content width (excl. outer padding)
---@field _contentTop number             Y offset where the panels start
---@field _modReps Texture               reputations module background
---@field _modAch Texture                achievements module background
---@field _expansion string?             currently selected expansion key
---@field _filter FilterDropdown?        titlebar expansion picker
-- The live view instance, captured so the ratings-changed listener (registered once,
-- below) refreshes whichever Top Characters table currently exists.
local _view
local Overview = Class(Frame, function(self)
  _view = self
  local c = theme.colors
  local BLEED = 6                        -- module/strip outer bleed (matches module bg padding)
  local contentTop = P + STRIP_H + GAP
  self._contentTop = contentTop

  -- Reputations + Achievements, one panel per expansion. Each panel holds a reps
  -- box (left) and an achievements box (right); panels share the same anchor and
  -- only the selected one is shown. The two module backgrounds are siblings of the
  -- panels and resize to the active expansion's section heights.
  self._panels, self._repsH, self._achH = {}, {}, {}
  local repsW, achW = 0, 0
  local achHeads = {}                    -- expansion key -> achievements caps header
  for _, e in ipairs(EXPANSIONS) do
    local panel = Frame:new{
      parent = self,
      position = { TopLeft = {P, -contentTop}, Hide = true },
    }
    local bw, bh, aw, ah, achHead = buildTab(panel, e.expansionLevel, e.extraFactionIDs, e.achievementIds)
    panel:Height(HEAD_H + math.max(bh, ah))
    self._panels[e.key] = panel
    self._repsH[e.key] = HEAD_H + bh
    self._achH[e.key]  = HEAD_H + ah
    repsW = math.max(repsW, bw)
    achW  = math.max(achW, aw)
    achHeads[e.key] = achHead
  end

  -- Top Characters header + table — built at a placeholder X, moved to its column below.
  local topHead = capsHeader(self, "Top Characters", { TopLeft = {P, -contentTop} })
  self.topAlts = TopAlts:new{
    parent = self,
    position = { TopLeft = {P, -(contentTop + HEAD_H)} },
  }
  self._altH = HEAD_H + self.topAlts:Height()

  -- Equal thirds: every section gets the same box width — the widest natural column —
  -- laid out left→right with a box-gap between, so the three sections line up as a clean
  -- grid (each content frame left-aligned in its column) instead of staggering to its
  -- own content width.
  local colW = math.max(repsW, achW, self.topAlts:Width())
  local col0, col1, col2 = P, P + colW + GAP * 2, P + 2 * (colW + GAP * 2)

  -- shift each expansion's achievements box into column 1 (local X relative to the
  -- panel, which is anchored at col0); the panel spans columns 0–1 (reps + ach).
  for key, panel in pairs(self._panels) do
    local achHead = achHeads[key]
    achHead:ClearAllPoints();    achHead:TopLeft(col1 - P, 0)
    panel._ach:ClearAllPoints(); panel._ach:TopLeft(col1 - P, -HEAD_H)
    panel:Width(2 * colW + GAP * 2)
  end

  -- move Top Characters into column 2.
  topHead:ClearAllPoints();      topHead:TopLeft(col2, -contentTop)
  self.topAlts:ClearAllPoints(); self.topAlts:TopLeft(col2, -(contentTop + HEAD_H))

  self._contentW = (col2 - P) + colW

  -- module backgrounds (parent textures render behind the child content frames); each
  -- section gets an equal-width box. Reps + ach are resized per selection (height only).
  self._modReps = Texture:new{
    parent = self, layer = ui.layer.Artwork, color = c.module,
    position = { TopLeft = {col0 - 6, -(contentTop - 6)}, Width = colW + 12, Height = 12 },
  }
  self._modAch = Texture:new{
    parent = self, layer = ui.layer.Artwork, color = c.module,
    position = { TopLeft = {col1 - 6, -(contentTop - 6)}, Width = colW + 12, Height = 12 },
  }
  Texture:new{
    parent = self, layer = ui.layer.Artwork, color = c.module,
    position = { TopLeft = {col2 - 6, -(contentTop - 6)}, Width = colW + 12, Height = self._altH + 12 },
  }

  -- Stat strip — one card per content column, each overlaying its column's box.
  local cardX = {col0, col1, col2}

  -- this-patch played time = each char's total minus its /played snapshot taken at
  -- first login on the current patch (PlaytimeBroker.byPatch); chars that never logged
  -- in this patch have no snapshot and contribute nothing.
  local patch = GetBuildInfo()
  local playSecs, patchSecs, topIlvl, count = 0, 0, 0, 0
  for _, toon in ipairs(ns.api.GetAllCharacters()) do
    count = count + 1
    local pt = toon.playtime
    if pt and pt.total then
      playSecs = playSecs + pt.total
      local snap = pt.byPatch and pt.byPatch[patch]
      if snap then patchSecs = patchSecs + (pt.total - snap) end
    end
    if toon.equipment and toon.equipment.ilvl and toon.equipment.ilvl > topIlvl then
      topIlvl = toon.equipment.ilvl
    end
  end

  local function card(i, caption, amount, amountColor, sub, subIcon, subColor)
    return StatCard:new{
      parent = self,
      caption = caption,
      amount = amount,
      amountColor = amountColor,
      sub = sub,
      subIcon = subIcon,
      subColor = subColor,
      subIconColor = subColor,
      position = { TopLeft = {cardX[i] - BLEED, -BLEED}, Width = colW + BLEED * 2, Height = STRIP_H },
    }
  end
  -- wealth includes the warband (account) bank, not just per-character gold
  local wealth = ns.api.GetWarbandWealth()
  local madeGold = math.floor(ns.api.GetWeeklyGoldMade() / 10000)
  local madeSub, trendIcon, trendColor
  if madeGold ~= 0 then
    madeSub = (madeGold > 0 and "+" or "") .. BreakUpLargeNumbers(madeGold) .. "g this week"
    trendIcon = TREND_ICON .. (madeGold > 0 and "trending_up.tga" or "trending_down.tga")
    trendColor = madeGold > 0 and c.green or c.red
  end
  card(1, "Total Warband Wealth", BreakUpLargeNumbers(math.floor(wealth / 10000)) .. "g", c.gold,
       madeSub, trendIcon, trendColor)
  card(2, "Total Playtime", BreakUpLargeNumbers(math.floor(playSecs / 3600)) .. " hrs", c.text,
       BreakUpLargeNumbers(math.floor(patchSecs / 3600)) .. " hrs this patch · " .. count .. " chars")
  card(3, "Top Item Level", tostring(topIlvl), ns.IlvlColorObj(topIlvl))

  self:selectExpansion(EXPANSIONS[1].key)

  -- Cold-session render glitch: cell FontStrings in the two TableFrames above can
  -- rasterize blank on the first UI load of a client session, even though text,
  -- size, visibility, and font all report correct (and the rest of the view
  -- renders fine). A *real* font change forces the client to re-rasterize them —
  -- a same-params SetFont is a no-op — so one tick after construction every cell
  -- label's font is swapped away and back. Invisible and idempotent.
  ns:after(50, function()
    healCellFonts(self.topAlts)
    for _, panel in pairs(self._panels) do healCellFonts(panel._ach) end
  end)
end, {
  name = "overview",
  background = theme.colors.window,
})
Overview.name = "overview"
Overview._title = "Overview"
ns.views.Overview = Overview

-- Live-refresh the Top Characters rating overlays when a rating changes in the shared
-- dressing room (registered once at load; Collected loads first via the OptionalDep
-- order). Mirrors CollectedView's own ratings-changed refresher. The Overview has no
-- wanted-only filter, so a mark re-apply is always enough.
if WarbandeerCollectedApi and WarbandeerCollectedApi.OnRatingsChanged then
  WarbandeerCollectedApi:OnRatingsChanged(function()
    local t = _view and _view.topAlts
    if t then t:_refreshMarks() end
  end)
end

-- Show the panel for `key`, size the reps + achievements boxes and the view to it,
-- and refit the window so the shorter expansion doesn't leave dead space below.
---@param key string
function Overview:selectExpansion(key)
  for k, panel in pairs(self._panels) do
    panel:SetShown(k == key)
  end
  self._expansion = key
  local repsH, achH = self._repsH[key], self._achH[key]
  self._modReps:Height(repsH + 12)
  self._modAch:Height(achH + 12)
  self:Width(P + self._contentW + P)
  self:Height(self._contentTop + math.max(repsH, achH, self._altH) + P)
  if self.parent and self.parent.Fit then self.parent:Fit() end
end

-- Refresh the Top Characters gear columns each time the view shows, so a
-- /collected scan run after the view was built is reflected on next open.
function Overview:OnBeforeShow()
  if self.topAlts then self.topAlts:Refresh() end
end

-- Titlebar pickers (shown only while the Overview is active): a raid picker for the
-- Top Characters gear columns (left) and the reps/achievements expansion picker
-- (right). Both sit in one container anchored by its right edge to the close button.
---@param parent Frame
---@return Frame
function Overview:BuildFilter(parent)
  local box = Frame:new{ parent = parent, position = { Height = 20 } }

  local raid = ns.FilterDropdown:new{
    parent    = box,
    options   = RAIDS,
    selected  = self.topAlts._raidId,
    width     = 110,
    menuWidth = 120,
    onSelect  = function(_, key) self.topAlts:SetRaid(key) end,
    position  = { TopLeft = {0, 0} },
  }
  local exp = ns.FilterDropdown:new{
    parent    = box,
    options   = EXPANSIONS,
    selected  = self._expansion,
    width     = 112,
    menuWidth = 130,
    onSelect  = function(_, key) self:selectExpansion(key) end,
    position  = { TopLeft = {raid, ui.edge.TopRight, GAP, 0} },
  }

  box:Width(raid:Width() + GAP + exp:Width())
  self._filter = box
  return box
end
