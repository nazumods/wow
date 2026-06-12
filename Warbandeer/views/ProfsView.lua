---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Class, Frame, TableFrame, ScrollFrame, Texture =
  ns.lua.Class, ui.Frame, ui.TableFrame, ui.ScrollFrame, ui.Texture
local Colors = ns.Colors
local theme = ns.theme
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

-- Transparent rows/columns let the void window surface show
-- through; the selected grid row reads as a muted-gold wash, empty cells dim.
local TRANSPARENT = { color = { 0, 0, 0, 0 } }
local SELECTED    = theme.colors.selected
local DIM         = { 0.82, 0.776, 0.671, 0.35 } -- muted at low alpha (— cells)

-- ─── Column-info factories ────────────────────────────────────────────────────
-- Headers are uppercased (the muted color comes from the theme); columns stay
-- transparent so the void window surface shows through behind the rows.

local function makeGridColInfo()
  local cols = {
    -- cells inset via hPadL; the header label insets via the symmetric `padding`
    -- (left inset only matters under left-justification) so the two line up
    { name = "PROFESSION", width = PROF_COL_W, backdrop = TRANSPARENT,
      justifyH = ui.justify.Left, hPadL = 8, padding = 8 },
  }
  for _, abbr in ipairs(EXP_ORDER) do
    insert(cols, { name = abbr:upper(), width = EXP_COL_W, backdrop = TRANSPARENT,
      justifyH = ui.justify.Left })
  end
  return cols
end

local function makeCharColInfo()
  local cols = {
    { width = ICON_COL_W, backdrop = TRANSPARENT },
    { name = "CHARACTER", width = CHAR_COL_W, backdrop = TRANSPARENT,
      justifyH = ui.justify.Left },
  }
  for _, abbr in ipairs(EXP_ORDER) do
    insert(cols, { name = abbr:upper(), width = EXP_COL_W, backdrop = TRANSPARENT,
      justifyH = ui.justify.Left })
  end
  return cols
end

-- Returns the pre-built empty row used to clear stale cells in the char table.
local function makeEmptyRow(numCols)
  local r = {}
  for _ = 1, numCols do insert(r, "") end
  return r
end

-- Lazily attach a 1px top divider to a pooled table row (mirrors the other
-- restyled table views). Returns the texture so callers can show/hide it.
local function rowDivider(row)
  if not row._divider then
    row._divider = Texture:new{
      parent = row,
      layer = ui.layer.Overlay,
      position = {
        TopLeft = { row, ui.edge.TopLeft, 0, 0 },
        TopRight = { row, ui.edge.TopRight, 0, 0 },
        Height = 1,
      },
      color = theme.colors.divider,
    }
  end
  return row._divider
end

-- ─── Cell helpers ─────────────────────────────────────────────────────────────

local function skillCell(best, max, onClick)
  if not best or best == 0 then
    return { text = "—", color = DIM, onClick = onClick }
  end
  return {
    text    = tostring(best),
    color   = best >= max and theme.colors.green or theme.colors.text,
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
    backdrop = TRANSPARENT,
    position = { TopLeft = {} },
  }

  -- Character-list section: a fixed header TableFrame + a ScrollFrame for the rows.
  -- The character table's header is placed immediately below the grid.
  -- A ScrollFrame is laid over the row area so only the header stays fixed.
  self.charTable = TableFrame:new{
    parent   = self,
    colInfo  = makeCharColInfo(),
    backdrop = TRANSPARENT,
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
    color   = theme.colors.muted,
    position = { Center = {} },
  }

  self._selectedRowIdx = nil
  self._visibleProfs   = {}
  self._toons          = nil
  self._charToons      = {}
  self._charColCount   = 2 + #EXP_ORDER  -- icon + name + expansions

  self:Width(VIEW_WIDTH)
  self:Height(self.gridTable:Height() + scrollTop + CHAR_LIST_H)
end, {
  name   = "profs",
  background = theme.colors.window,
})
ProfsView.name = "profs"
ProfsView._title = "Professions"
ns.views.ProfsView = ProfsView

---@return Character[]
function ProfsView:GetCharacters()
  local toons = ns.api.GetAllCharacters()
  sort(toons, ns.byLevelIlvl)
  return toons
end

-- Highlight the clicked grid row and populate the character list below it.
---@param rowIdx integer  index into self._visibleProfs
function ProfsView:SelectRow(rowIdx)
  -- Restore the previous row's resting (transparent) backdrop.
  if self._selectedRowIdx then
    local prev = self.gridTable.rows[self._selectedRowIdx]
    if prev then prev:backdropColor(0, 0, 0, 0) end
  end

  self._selectedRowIdx = rowIdx
  local row = self.gridTable.rows[rowIdx]
  if row then row:backdropColor(SELECTED) end

  self:RebuildCharList(self._visibleProfs[rowIdx])
end

-- Resting backdrop for a grid row: gold wash if selected, otherwise transparent.
function ProfsView:RestoreGridRow(rowIdx)
  local row = self.gridTable.rows[rowIdx]
  if not row then return end
  if self._selectedRowIdx == rowIdx then
    row:backdropColor(SELECTED)
  else
    row:backdropColor(0, 0, 0, 0)
  end
end

-- Rebuild the character list for profName; pass nil to clear the list.
---@param profName string|nil
function ProfsView:RebuildCharList(profName)
  local entries = profName and buildCharList(self._toons, profName) or {}
  local current = ns.api.GetCurrentCharacter()
  self._charToons = {}

  -- Build data rows for real characters.
  local rowData = {}
  for i, entry in ipairs(entries) do
    local toon   = entry.toon
    local detail = entry.detail
    self._charToons[i] = toon

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
        onEnter = function(s)
          ui.tip:AnchorTo(s, "ANCHOR_BOTTOMRIGHT", -10, 10)
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
          color = exp.skillLevel >= exp.maxSkillLevel and theme.colors.green or theme.colors.text,
        })
      else
        insert(row, { text = "—", color = DIM })
      end
    end

    insert(rowData, self:decorateCharRow(row, i, toon))
  end

  -- Grow the row pool to cover all real entries (update() would do this too,
  -- but doing it here lets us set backdrops/dividers before the update call).
  for _ = #self.charTable.rows + 1, #entries do
    self.charTable:addRow({})
  end
  self.charTable:ResizeRows(#entries)

  -- Pad data with empty rows to clear stale cells from a previous (larger) selection.
  local emptyRow = makeEmptyRow(self._charColCount)
  for _ = #entries + 1, #self.charTable.rows do
    insert(rowData, emptyRow)
  end

  -- Rows stay transparent (the void surface shows through); a thin divider sits
  -- above each real row, hidden on the empty padding rows.
  for i, tblRow in ipairs(self.charTable.rows) do
    tblRow:backdropColor(0, 0, 0, 0)
    rowDivider(tblRow):SetShown(i <= #entries)
  end

  self.charTable.data = rowData
  self.charTable:update()
  self.emptyHint:SetShown(#entries == 0)
end

-- Make every cell in char row `i` drive the row hover highlight and open that
-- character in the Detail view on click, chaining onto any existing cell handlers
-- (so the name's realm tooltip keeps working). Each cell is a shallow COPY of the
-- source data — the faction-icon cell is a shared table object (ns.factionIcon[...]),
-- so mutating it in place would chain wrappers across every row sharing it.
---@param cells table  the row's per-column cell data array
---@param i integer    row index
---@param toon table   the character this row represents
---@return table cells
function ProfsView:decorateCharRow(cells, i, toon)
  for n, cell in ipairs(cells) do
    local src = type(cell) == "table" and cell or { text = cell }
    local copy = {}
    for k, v in pairs(src) do copy[k] = v end
    local onEnter, onLeave, onClick = src.onEnter, src.onLeave, src.onClick
    copy.onEnter = function(s)
      local row = self.charTable.rows[i]
      if row then row:backdropColor(theme.colors.hover) end
      if onEnter then onEnter(s) end
    end
    copy.onLeave = function(s)
      local row = self.charTable.rows[i]
      if row then row:backdropColor(0, 0, 0, 0) end
      if onLeave then onLeave(s) end
    end
    copy.onClick = function(s)
      if onClick then onClick(s) end
      local w = ns.MainWindow
      if toon and w then
        w:getView("detail"):Select(toon)
        w:view("detail")
      end
    end
    cells[n] = copy
  end
  return cells
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
      -- Whole row brightens on hover unless it's the selected row.
      local onEnter = function()
        if self._selectedRowIdx ~= rowIdx then
          local row = self.gridTable.rows[rowIdx]
          if row then row:backdropColor(theme.colors.hover) end
        end
      end
      local onLeave = function() self:RestoreGridRow(rowIdx) end

      insert(visibleProfs, profName)
      local row = { { text = profName, onClick = onClick, onEnter = onEnter, onLeave = onLeave } }
      for _, abbr in ipairs(EXP_ORDER) do
        local skill = data[abbr]
        local cell = skillCell(skill and skill.best, skill and skill.max, onClick)
        cell.onEnter = onEnter
        cell.onLeave = onLeave
        insert(row, cell)
      end
      insert(gridRowData, row)
    end
  end

  -- Grow grid row pool; rows stay transparent with a divider above each visible one.
  for _ = #self.gridTable.rows + 1, #visibleProfs do
    self.gridTable:addRow({})
  end
  self.gridTable:ResizeRows(#visibleProfs)
  for i, tblRow in ipairs(self.gridTable.rows) do
    tblRow:backdropColor(0, 0, 0, 0)
    rowDivider(tblRow):SetShown(i <= #visibleProfs)
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
