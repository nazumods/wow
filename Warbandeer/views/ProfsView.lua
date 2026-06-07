local _, ns = ...
local ui = ns.ui
-- luacheck: globals DISABLED_FONT_COLOR DIM_GREEN_FONT_COLOR NORMAL_FONT_COLOR
local Class, Frame, TableFrame, ScrollFrame = ns.lua.Class, ui.Frame, ui.TableFrame, ui.ScrollFrame
local Colors = ns.Colors
local insert, sort = table.insert, table.sort

-- Ordered expansion columns (chronological).
local EXP_ORDER = { "Clsc", "TBC", "WotLK", "Cata", "MoP", "WoD", "Leg", "BfA", "SL", "DF", "TWW", "Mid" }
local EXP_ABBR = {
  ["Classic"]      = "Clsc",
  ["Outland"]      = "TBC",
  ["Northrend"]    = "WotLK",
  ["Cataclysm"]    = "Cata",
  ["Pandaria"]     = "MoP",
  ["Draenor"]      = "WoD",
  ["Legion"]       = "Leg",
  ["Kul Tiran"]    = "BfA",
  ["Shadowlands"]  = "SL",
  ["Dragon Isles"] = "DF",
  ["Khaz Algar"]   = "TWW",
  ["Midnight"]     = "Mid",
}

-- Professions in display order (no Fishing — no expansion sub-skills).
local PROF_ORDER = {
  "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering", "Fishing",
  "Herbalism", "Inscription", "Jewelcrafting", "Leatherworking",
  "Mining", "Skinning", "Tailoring",
}

-- Column widths.  ICON + CHAR == PROF so expansion columns align between the two tables.
local PROF_COL_W    = 110   -- profession-name column in the summary grid
local ICON_COL_W    = 20    -- faction icon in the character list
local CHAR_COL_W    = 90    -- character name in the character list
local EXP_COL_W     = 44    -- shared width for every expansion column
local CHAR_LIST_H   = 180   -- height of the scrollable character-list area

local VIEW_WIDTH    = PROF_COL_W + #EXP_ORDER * EXP_COL_W  -- 638

-- Row backdrop colours.
local TRANSPARENT   = { color = { 0, 0, 0, 0 } }
local SELECTED_COLOR = { 1, 0.82, 0.2, 0.22 }
local function rowBgColor(i)
  return i % 2 == 0 and { 0, 0, 0, 0.4 } or { 0, 0, 0, 0.2 }
end

-- ─── Column-info factories ────────────────────────────────────────────────────

local function makeGridColInfo()
  local cols = { { name = "Profession", width = PROF_COL_W, backdrop = TRANSPARENT, justifyH = ui.justify.Left } }
  for _, abbr in ipairs(EXP_ORDER) do
    insert(cols, { name = abbr, width = EXP_COL_W, backdrop = TRANSPARENT, justifyH = ui.justify.Left })
  end
  return cols
end

local function makeCharColInfo()
  local cols = {
    { width = ICON_COL_W, backdrop = TRANSPARENT },
    { name = "Character", width = CHAR_COL_W, backdrop = TRANSPARENT, justifyH = ui.justify.Left },
  }
  for _, abbr in ipairs(EXP_ORDER) do
    insert(cols, { name = abbr, width = EXP_COL_W, backdrop = TRANSPARENT, justifyH = ui.justify.Left })
  end
  return cols
end

-- Returns the pre-built empty row used to clear stale cells in the char table.
local function makeEmptyRow(numCols)
  local r = {}
  for _ = 1, numCols do insert(r, "") end
  return r
end

-- ─── Cell helpers ─────────────────────────────────────────────────────────────

local function skillCell(best, max, onClick)
  if not best or best == 0 then
    return { text = "—", color = DISABLED_FONT_COLOR, onClick = onClick }
  end
  return {
    text    = tostring(best),
    color   = best >= max and DIM_GREEN_FONT_COLOR or NORMAL_FONT_COLOR,
    onClick = onClick,
  }
end

-- ─── Data helpers ─────────────────────────────────────────────────────────────

-- For each profession, find the best skill per expansion across all characters.
-- Returns { [profName] -> { [expAbbr] -> { best, max } } }
local function buildBestSkills(toons)
  local result = {}
  for _, toon in ipairs(toons) do
    local profs = toon.basic.professions
    if profs then
      for _, slot in ipairs({ "primary", "secondary", "fishing", "cooking" }) do
        local prof = profs[slot]
        if prof and prof.name then
          if not result[prof.name] then result[prof.name] = {} end
          local pData  = result[prof.name]
          local detail = toon.professions
                      and toon.professions.details
                      and toon.professions.details[prof.skillID]
          if detail and detail.expansions then
            for _, exp in ipairs(detail.expansions) do
              local abbr = EXP_ABBR[exp.name]
              if abbr then
                if not pData[abbr] or exp.skillLevel > pData[abbr].best then
                  pData[abbr] = { best = exp.skillLevel, max = exp.maxSkillLevel }
                end
              end
            end
          end
        end
      end
    end
  end
  return result
end

-- Build a sorted character list for a given profession name.
-- Returns { { toon, prof, detail } ... } sorted by skill desc then name asc.
local function buildCharList(toons, profName)
  local list = {}
  for _, toon in ipairs(toons) do
    local profs = toon.basic.professions
    if profs then
      for _, slot in ipairs({ "primary", "secondary", "fishing", "cooking" }) do
        local prof = profs[slot]
        if prof and prof.name == profName then
          local detail = toon.professions
                      and toon.professions.details
                      and toon.professions.details[prof.skillID]
          insert(list, { toon = toon, prof = prof, detail = detail })
          break
        end
      end
    end
  end
  sort(list, function(a, b)
    if a.prof.skillLevel ~= b.prof.skillLevel then return a.prof.skillLevel > b.prof.skillLevel end
    return a.toon.name < b.toon.name
  end)
  return list
end

-- ─── View ─────────────────────────────────────────────────────────────────────

---@class ProfsView: Frame
local ProfsView = Class(Frame, function(self)
  -- Account Summary grid: rows = professions, columns = expansions.
  self.gridTable = TableFrame:new{
    parent   = self,
    colInfo  = makeGridColInfo(),
    position = { TopLeft = {} },
  }

  -- Character-list section: a fixed header TableFrame + a ScrollFrame for the rows.
  -- The character table's header is placed immediately below the grid.
  -- A ScrollFrame is laid over the row area so only the header stays fixed.
  self.charTable = TableFrame:new{
    parent   = self,
    colInfo  = makeCharColInfo(),
    position = { TopLeft = { self.gridTable, ui.edge.BottomLeft, 0, -8 } },
  }

  -- charTable.offsetY is the header height; the scroll starts just below the header.
  local scrollTop = 8 + self.charTable.offsetY
  self.charScroll = ScrollFrame:new{
    parent   = self,
    position = {
      TopLeft = { self.gridTable, ui.edge.BottomLeft, 0, -scrollTop },
      Height  = CHAR_LIST_H,
      Width   = VIEW_WIDTH,
    },
  }
  self.charScroll:Child(self.charTable.rowArea)

  self.emptyHint = ui.Label:new{
    parent  = self.charScroll,
    text    = "Select a profession above to view characters",
    color   = DISABLED_FONT_COLOR,
    position = { Center = {} },
  }

  self._selectedRowIdx = nil
  self._visibleProfs   = {}
  self._toons          = nil
  self._charColCount   = 2 + #EXP_ORDER  -- icon + name + expansions

  self:Width(VIEW_WIDTH)
  self:Height(self.gridTable:Height() + scrollTop + CHAR_LIST_H)
end, {
  name   = "profs",
  _title = "Professions",
})
ProfsView.name = "profs"
ns.views.ProfsView = ProfsView

---@return Character[]
function ProfsView:GetCharacters()
  local toons = ns.api.GetAllCharacters()
  sort(toons, function(a, b)
    if a.basic.level ~= b.basic.level then return a.basic.level > b.basic.level end
    if a.equipment.ilvl ~= b.equipment.ilvl then return a.equipment.ilvl > b.equipment.ilvl end
    return a.name < b.name
  end)
  return toons
end

-- Highlight the clicked grid row and populate the character list below it.
---@param rowIdx integer  index into self._visibleProfs
function ProfsView:SelectRow(rowIdx)
  -- Restore the previous row's backdrop.
  if self._selectedRowIdx then
    local prev = self.gridTable.rows[self._selectedRowIdx]
    if prev then prev:backdropColor(unpack(rowBgColor(self._selectedRowIdx))) end
  end

  self._selectedRowIdx = rowIdx
  local row = self.gridTable.rows[rowIdx]
  if row then row:backdropColor(unpack(SELECTED_COLOR)) end

  self:RebuildCharList(self._visibleProfs[rowIdx])
end

-- Rebuild the character list for profName; pass nil to clear the list.
---@param profName string|nil
function ProfsView:RebuildCharList(profName)
  local entries = profName and buildCharList(self._toons, profName) or {}
  local current = ns.api.GetCurrentCharacter()

  -- Build data rows for real characters.
  local rowData = {}
  for _, entry in ipairs(entries) do
    local toon   = entry.toon
    local detail = entry.detail

    -- Map expansion abbreviation → data from this character's cached detail.
    local expMap = {}
    if detail and detail.expansions then
      for _, exp in ipairs(detail.expansions) do
        local abbr = EXP_ABBR[exp.name]
        if abbr then expMap[abbr] = exp end
      end
    end

    local nameText = toon.name
    if toon.name == current then
      nameText = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14:14:14|t " .. nameText
    end

    local row = {
      -- Faction icon.
      ns.factionIcon[toon.isAlliance],
      -- Character name (class coloured; realm on hover).
      {
        text    = nameText,
        color   = Colors[toon.classKey],
        onEnter = function(self)
          ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
          ui.tip:ClearLines()
          ui.tip:AddLine(toon.realm)
          ui.tip:Show()
        end,
        onLeave = function() ui.tip:Hide() end,
      },
    }

    -- One cell per expansion, green if at cap.
    for _, abbr in ipairs(EXP_ORDER) do
      local exp = expMap[abbr]
      if exp then
        insert(row, {
          text  = exp.skillLevel,
          color = exp.skillLevel >= exp.maxSkillLevel and DIM_GREEN_FONT_COLOR or NORMAL_FONT_COLOR,
        })
      else
        insert(row, { text = "—", color = DISABLED_FONT_COLOR })
      end
    end

    insert(rowData, row)
  end

  -- Grow the row pool to cover all real entries (update() would do this too,
  -- but doing it here lets us set backdrops before the update call).
  for _ = #self.charTable.rows + 1, #entries do
    self.charTable:addRow({})
  end

  -- Pad data with empty rows to clear stale cells from a previous (larger) selection.
  local emptyRow = makeEmptyRow(self._charColCount)
  for _ = #entries + 1, #self.charTable.rows do
    insert(rowData, emptyRow)
  end

  -- Update backdrops: alternating colours for real rows, transparent for padding.
  for i, tblRow in ipairs(self.charTable.rows) do
    if i <= #entries then
      tblRow:backdropColor(unpack(rowBgColor(i)))
    else
      tblRow:backdropColor(0, 0, 0, 0)
    end
  end

  self.charTable.data = rowData
  self.charTable:update()
  self.emptyHint:SetShown(#entries == 0)
end

-- Called automatically by Region:Show() just before the frame becomes visible.
function ProfsView:OnBeforeShow()
  self._toons = self:GetCharacters()
  local bestSkills = buildBestSkills(self._toons)

  -- Build grid rows only for professions present in the warband.
  local visibleProfs = {}
  local gridRowData  = {}

  for _, profName in ipairs(PROF_ORDER) do
    local data = bestSkills[profName]
    if data then
      local rowIdx  = #visibleProfs + 1
      local onClick = function() self:SelectRow(rowIdx) end

      insert(visibleProfs, profName)
      local row = { { text = profName, onClick = onClick } }
      for _, abbr in ipairs(EXP_ORDER) do
        local skill = data[abbr]
        insert(row, skillCell(skill and skill.best, skill and skill.max, onClick))
      end
      insert(gridRowData, row)
    end
  end

  -- Grow grid row pool; restore alternating backdrops (clears any prior selection highlight).
  for _ = #self.gridTable.rows + 1, #visibleProfs do
    self.gridTable:addRow({})
  end
  for i, tblRow in ipairs(self.gridTable.rows) do
    if i <= #visibleProfs then tblRow:backdropColor(unpack(rowBgColor(i))) end
  end

  self.gridTable.data = gridRowData
  self.gridTable:update()

  self._visibleProfs   = visibleProfs
  self._selectedRowIdx = nil

  -- Clear the character list.
  self:RebuildCharList(nil)

  local scrollTop = 8 + self.charTable.offsetY
  self:Width(VIEW_WIDTH)
  self:Height(self.gridTable:Height() + scrollTop + CHAR_LIST_H)
end
