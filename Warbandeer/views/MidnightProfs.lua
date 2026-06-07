local _, ns = ...
local ui = ns.ui
-- luacheck: globals DISABLED_FONT_COLOR GetServerTime
local insert, sort, concat, floor = table.insert, table.sort, table.concat, math.floor
local Class, Frame, TableFrame, Button, Texture = ns.lua.Class, ui.Frame, ui.TableFrame, ui.Button, ui.Texture
local Colors, ColorS = ns.Colors, ns.Colors.Strings
local C_GREEN, C_WHITE, C_ORANGE, C_GREY, C_END = ColorS.GREEN, ColorS.WHITE, ColorS.ORANGE, ColorS.GREY, ColorS.END

-- All professions in display order. hasCon = has Midnight concentration resource.
local PROF_ORDER = { 171, 164, 333, 202, 773, 755, 165, 197, 182, 186, 393, 356, 185 }
local PROF_INFO = {
  [171] = { abbr = "Alch", name = "Alchemy",        hasCon = true  },
  [164] = { abbr = "BS",   name = "Blacksmithing",  hasCon = true  },
  [333] = { abbr = "Ench", name = "Enchanting",     hasCon = true  },
  [202] = { abbr = "Eng",  name = "Engineering",    hasCon = true  },
  [773] = { abbr = "Insc", name = "Inscription",    hasCon = true  },
  [755] = { abbr = "JC",   name = "Jewelcrafting",  hasCon = true  },
  [165] = { abbr = "LW",   name = "Leatherworking", hasCon = true  },
  [197] = { abbr = "Tail", name = "Tailoring",      hasCon = true  },
  [182] = { abbr = "Herb", name = "Herbalism",      hasCon = false },
  [186] = { abbr = "Mine", name = "Mining",         hasCon = false },
  [393] = { abbr = "Skin", name = "Skinning",       hasCon = false },
  [356] = { abbr = "Fish", name = "Fishing",        hasCon = false },
  [185] = { abbr = "Cook", name = "Cooking",        hasCon = false },
}

local ICON_COL_W = 20
local CHAR_COL_W = 90
local PROF_COL_W     = 100  -- gathering / fishing / cooking
local PROF_CON_COL_W = 142  -- crafting profs with concentration (6 chars wider)

local TRANSPARENT = { color = Colors.TransparentBlack }

local function rowBgColor(i)
  return i % 2 == 0 and { 0, 0, 0, 0.4 } or { 0, 0, 0, 0.2 }
end

-- ─── Data helpers ─────────────────────────────────────────────────────────────

local estimateConcentration = ns.data.EstimateConcentration

-- Returns the Midnight expansion skill and max for a crafting profession, if captured.
local function midnightSkill(toon, skillLineID)
  local detail = toon.professions
               and toon.professions.details
               and toon.professions.details[skillLineID]
  if not detail or not detail.expansions then return nil, nil end
  for _, exp in ipairs(detail.expansions) do
    if exp.name == "Midnight" then return exp.skillLevel, exp.maxSkillLevel end
  end
  return nil, nil
end

-- Finds the character's profession object from the basic broker for a given skill line.
local function findProf(toon, skillLineID)
  local profs = toon.basic and toon.basic.professions
  if not profs then return nil end
  for _, slot in ipairs({"primary", "secondary", "fishing", "cooking"}) do
    local p = profs[slot]
    if p and p.skillID == skillLineID then return p end
  end
  return nil
end

-- Builds a single cell showing "skill [conc]" for crafting profs or "skill" for others.
-- Uses embedded WoW color codes so skill and concentration can be colored independently.
local function profCell(toon, prof)
  local p = findProf(toon, prof.id)
  if not p then return { text = C_GREY .. "—" .. C_END, justifyH = ui.justify.Center } end

  -- Skill level: prefer Midnight-specific from professions broker, fall back to basic.
  local skillLevel, skillMax
  if prof.hasCon then
    skillLevel, skillMax = midnightSkill(toon, prof.id)
    if not skillLevel then skillLevel, skillMax = p.skillLevel, p.maxSkillLevel end
  else
    skillLevel, skillMax = p.skillLevel, p.maxSkillLevel
  end

  local skillCol = (skillMax and skillLevel and skillLevel >= skillMax) and C_GREEN or C_WHITE
  local text     = skillCol .. (skillLevel and tostring(skillLevel) or "—") .. C_END

  -- Concentration bracket: only for crafting professions.
  local concQty, concMax, concEst
  if prof.hasCon then
    local concEntry = toon.concentration and toon.concentration.data and toon.concentration.data[prof.id]
    if concEntry then
      concQty, concMax, concEst = estimateConcentration(concEntry)
      local concCol
      if concMax and concMax > 0 then
        local pct = concQty / concMax
        if     pct >= 0.8 then concCol = C_GREEN
        elseif pct >= 0.3 then concCol = C_WHITE
        else                   concCol = C_ORANGE
        end
      else
        concCol = C_WHITE
      end
      text = text .. " " .. concCol .. "[" .. (concEst and "~" or "") .. concQty .. "]" .. C_END
    else
      text = text .. " " .. C_GREY .. "[—]" .. C_END
    end
  end

  -- Midnight recipe % (learned / total for this profession).
  local recipePct, recipeLearned, recipeTotal
  local bucket = toon.professions and toon.professions.details
             and toon.professions.details[prof.id]
             and toon.professions.details[prof.id].recipes
             and toon.professions.details[prof.id].recipes.midnight
  if bucket and bucket.total and bucket.total > 0 then
    recipeLearned = #bucket.learned
    recipeTotal   = bucket.total
    recipePct     = floor(recipeLearned / recipeTotal * 100 + 0.5)
    local recipeCol = recipePct >= 90 and C_GREEN or (recipePct >= 50 and C_WHITE or C_ORANGE)
    text = text .. " " .. recipeCol .. "(" .. recipePct .. "%)" .. C_END
  end

  return {
    text      = text,
    justifyH  = ui.justify.Center,
    onEnter = function(self)
      ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
      ui.tip:ClearLines()
      ui.tip:AddLine(prof.name)
      if skillLevel then
        ui.tip:AddLine("Skill: " .. skillLevel .. (skillMax and " / " .. skillMax or ""))
      end
      if concQty then
        local line = "Concentration: " .. concQty .. " / " .. (concMax or "?")
        if concEst then line = line .. "  (estimated)" end
        ui.tip:AddLine(line)
      end
      if recipePct then
        ui.tip:AddLine("Recipes: " .. recipeLearned .. " / " .. recipeTotal .. " (" .. recipePct .. "%)")
      end
      ui.tip:Show()
    end,
    onLeave = function() ui.tip:Hide() end,
  }
end

-- ─── Column discovery ─────────────────────────────────────────────────────────

-- Returns the ordered list of professions present across the warband.
local function discoverProfs(toons)
  local seen = {}
  for _, toon in ipairs(toons) do
    local profs = toon.basic and toon.basic.professions
    if profs then
      for _, slot in ipairs({"primary", "secondary", "fishing", "cooking"}) do
        local p = profs[slot]
        if p and p.skillID and PROF_INFO[p.skillID] then seen[p.skillID] = true end
      end
    end
  end
  local result = {}
  for _, id in ipairs(PROF_ORDER) do
    if seen[id] then
      local info = PROF_INFO[id]
      insert(result, { id = id, abbr = info.abbr, name = info.name, hasCon = info.hasCon })
    end
  end
  return result
end

local function profKey(profs)
  local ids = {}
  for _, p in ipairs(profs) do insert(ids, p.id) end
  return concat(ids, ",")
end

local function buildColInfo(profs)
  local cols = {
    { width = ICON_COL_W, backdrop = TRANSPARENT },
    { name = "Character", width = CHAR_COL_W, backdrop = TRANSPARENT, justifyH = ui.justify.Left },
  }
  for _, prof in ipairs(profs) do
    insert(cols, {
      name     = prof.abbr,
      width    = prof.hasCon and PROF_CON_COL_W or PROF_COL_W,
      backdrop = TRANSPARENT,
      tooltip  = prof.name .. (prof.hasCon and " — skill [concentration] (recipes%)" or " — skill (recipes%)"),
    })
  end
  return cols
end

-- ─── View ─────────────────────────────────────────────────────────────────────

---@class MidnightProfs: Frame
local MidnightProfs = Class(Frame, function(self)
  -- default to the current character's faction on first open
  local current = ns.api:GetCharacterData()
  self._showAlliance = not current or current.isAlliance
  self._profKey = nil
  self._profs   = nil
  self._numCols = 0
  self.tbl      = nil
  self._sortCol = nil  -- nil = default level/name sort
  self._sortAsc = false
  self:Width(200)
  self:Height(40)
end, {
  name   = "midnightprofs",
  _title = "Midnight Profs",
})
MidnightProfs.name = "midnightprofs"
ns.views.MidnightProfs = MidnightProfs

function MidnightProfs:BuildTable(profs)
  if self.tbl then self.tbl:Hide() end
  self.tbl = TableFrame:new{
    parent   = self,
    colInfo  = buildColInfo(profs),
    position = { TopLeft = {} },
  }
  self._profKey = profKey(profs)
  self._profs   = profs
  self._numCols = 2 + #profs
  self._sortCol = nil
  -- wire sort click on each column header
  for i, col in ipairs(self.tbl.cols) do
    local colIdx = i
    col.header:SetScript("OnMouseUp", function()
      if self._sortCol == colIdx then
        self._sortAsc = not self._sortAsc
      else
        self._sortCol = colIdx
        self._sortAsc = false -- default descending
      end
      self:OnBeforeShow()
      if ns.MainWindow then ns.MainWindow:Fit() end
    end)
  end
end

function MidnightProfs:toggleFaction()
  self._showAlliance = not self._showAlliance
  self:refreshFilterButtons()
  self:OnBeforeShow()
  if ns.MainWindow then ns.MainWindow:Fit() end
end

function MidnightProfs:refreshFilterButtons()
  if not self._filter then return end
  self._filter.alliance:Alpha(self._showAlliance and 1 or 0.3)
  self._filter.horde:Alpha(not self._showAlliance and 1 or 0.3)
end

function MidnightProfs:BuildFilter(parent)
  local box = ui.Frame:new{
    parent = parent,
    position = { Height = 20, Width = 44 },
  }
  local function btn(iconPath, position)
    local b = Button:new{
      parent = box,
      position = position,
      glow = false,
      OnClick = function() self:toggleFaction() end,
    }
    b.icon = Texture:new{
      parent = b,
      layer = ui.layer.Artwork,
      path = iconPath,
      position = { All = true },
    }
    return b
  end
  box.alliance = btn(ns.icons.Alliance, {
    Left = {0, 0},
    Size = {20, 20},
  })
  box.horde = btn(ns.icons.Horde, {
    Left = {box.alliance, ui.edge.Right, 4, 0},
    Size = {20, 20},
  })
  self._filter = box
  self:refreshFilterButtons()
  return box
end

local function profSortKey(toon, prof)
  local p = findProf(toon, prof.id)
  if not p then return 0 end
  if prof.hasCon then return midnightSkill(toon, prof.id) or p.skillLevel or 0 end
  return p.skillLevel or 0
end

function MidnightProfs:OnBeforeShow()
  local all = ns.api.GetAllCharacters()
  local toons = {}
  for _, t in ipairs(all) do
    if t.isAlliance == self._showAlliance then insert(toons, t) end
  end

  local profs = discoverProfs(toons)
  if profKey(profs) ~= self._profKey then self:BuildTable(profs) end

  local current = ns.api.GetCurrentCharacter()

  -- build entries: {toon, row, keys}
  local entries = {}
  for _, toon in ipairs(toons) do
    local nameText = toon.name
    if toon.name == current then
      nameText = nameText .. " |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14:0:0|t"
    end
    nameText = nameText .. " " .. C_GREY .. "(" .. toon.basic.level .. ")" .. C_END
    local row = {
      ns.factionIcon[toon.isAlliance],
      {
        text    = nameText,
        color   = Colors[toon.classKey],
        onEnter = function(self)
          ns.ShowCharacterTooltip(toon, self)
        end,
        onLeave = ns.HideCharacterTooltip,
      },
    }
    -- sort keys: col1=faction, col2=name, col3+=prof skill
    local keys = { toon.isAlliance and 1 or 0, toon.name }
    for _, prof in ipairs(self._profs) do
      insert(row, profCell(toon, prof))
      insert(keys, profSortKey(toon, prof))
    end
    insert(entries, { toon = toon, row = row, keys = keys })
  end

  -- sort
  if self._sortCol then
    local col, asc = self._sortCol, self._sortAsc
    sort(entries, function(a, b)
      local av, bv = a.keys[col], b.keys[col]
      if av == bv then return a.toon.name < b.toon.name end
      if asc then return av < bv else return av > bv end
    end)
  else
    sort(entries, function(a, b)
      if a.toon.basic.level ~= b.toon.basic.level then return a.toon.basic.level > b.toon.basic.level end
      return a.toon.name < b.toon.name
    end)
  end

  for _ = #self.tbl.rows + 1, #entries do self.tbl:addRow({}) end

  local emptyRow = {}
  for _ = 1, self._numCols do insert(emptyRow, "") end

  local rowData = {}
  for i, entry in ipairs(entries) do
    insert(rowData, entry.row)
    self.tbl.rows[i]:backdropColor(unpack(rowBgColor(i)))
  end
  for i = #entries + 1, #self.tbl.rows do
    insert(rowData, emptyRow)
    self.tbl.rows[i]:backdropColor(0, 0, 0, 0)
  end

  self.tbl.data = rowData
  self.tbl:update()
  self:Width(self.tbl:Width())
  self:Height(self.tbl:Height())
  self:updateSortIndicators()
end

function MidnightProfs:updateSortIndicators()
  for i, col in ipairs(self.tbl.cols) do
    local base = self.tbl.colInfo[i].name or ""
    local label
    if self._sortCol == i then
      label = base .. (self._sortAsc and " ^" or " v")
    else
      label = base
    end
    col.header.label:Text(label)
  end
end
