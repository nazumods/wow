---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local filter = ns.lua.lists.filter
local Class, TableFrame, Texture, Button, Label = ns.lua.Class, ui.TableFrame, ui.Texture, ui.Button, ui.Label
local theme = ns.theme

-- Faction accent colours for the toggle (Alliance blue / Horde red), matching
-- the ns.factionIcon tints.
local FACTION_COLOR = {
  alliance = {0.40, 0.733, 1.0, 1},
  horde    = {1.0,  0.125, 0.125, 1},
}

-- Build the colInfo list for a given (visible) column set: shallow-copy each
-- column's colInfo with uppercased text headers (icon-only columns have no name
-- and are unaffected; the muted header color comes from the theme). The source
-- colInfo is left untouched, and a fresh list is returned each call — addCol
-- mutates colInfo in place (the dynamic DMF column), so each ClassSummary needs
-- its own copy or that column would leak into every sibling table.
---@param cols SummaryColumn[]
---@return table[]
-- A consistent gutter inserted to the LEFT of every column but the first, so
-- adjacent columns always keep a gap regardless of which the user has hidden.
-- Unlike a cell inset (hPad), this spaces the column *frames* apart and so never
-- shrinks a column's content area — the tightly-sized number columns keep their
-- full width. Added on top of any padLeft a column declares itself (e.g. the
-- catch-up column's larger group spacer).
local COL_GUTTER = 5

local function buildColInfo(cols)
  return ns.lua.lists.map(cols, function(c, i)
    local info = {}
    for k, v in pairs(c.colInfo) do info[k] = v end
    if info.name and info.name ~= "" then info.name = info.name:upper() end
    if i > 1 then info.padLeft = (info.padLeft or 0) + COL_GUTTER end
    -- inset the outer columns' cells so they don't sit against the table edges
    if i == 1 then info.hPadL = 8 end
    -- the right-aligned Gold column also insets its header to match its cells:
    -- cells use hPadR, headers use the symmetric `padding`, so set both (the
    -- header's left inset is invisible under right-justification)
    if i == #cols then info.hPadR = 8; info.padding = 8 end
    return info
  end)
end

-- Per-faction roster table: one row per character, one column per SummaryColumn.
---@class ClassSummary: TableFrame
---@field isAlliance boolean      which faction's characters this table shows
---@field columns SummaryColumn[] the visible columns this table renders (passed in)
---@field _columns SummaryColumn[] row-iteration list (columns + any dynamic DMF column)
---@field _toons Character[]      row index -> character (refreshed each OnBeforeShow)
local ClassSummary = Class(TableFrame, function(self)
  -- the row builders walk _columns; SummaryColumnsDelayed may append the DMF column
  self._columns = self.columns
  ns.SummaryColumnsDelayed(self)

  local toons = self:GetCharacters()
  self._toons = toons
  self.data = {}
  for i, t in ipairs(toons) do
    self.data[i] = self:decorateRow(self:GetRowData(t), i)
  end
  self:update()

  -- The module surface behind the table provides the glass backing; rows stay
  -- transparent with a thin divider above each one. The logged-in character's
  -- row gets the muted-gold selected wash, and still-levelling characters are
  -- dimmed so the max-level roster reads first (see restRow).
  for i, row in ipairs(self.rows) do
    self:restRow(i)
    Texture:new{
      parent = row,
      layer = ui.layer.Overlay,
      position = {
        TopLeft = {row, ui.edge.TopLeft, 0, 0},
        TopRight = {row, ui.edge.TopRight, 0, 0},
        Height = 1,
      },
      color = theme.colors.divider,
    }
  end

  self:setFooter(self:GetFooterData(toons))
end, {
  isAlliance = true,
  backdrop = {color = ns.Colors.TransparentBlack},
  footerBackdrop = {color = theme.colors.moduleHi},
})

-- This table's faction roster, sorted by level/ilvl/name.
---@return Character[]
function ClassSummary:GetCharacters()
  local toons = ns.api.GetAllCharacters() -- returns a copy
  toons = filter(toons, function(t)
    return t.isAlliance == self.isAlliance
  end)
  table.sort(toons, ns.byLevelIlvl)
  return toons
end

-- Resting backdrop for row i: muted-gold wash for the logged-in character,
-- dimmed for still-levelling characters, transparent otherwise.
---@param i integer  row index
function ClassSummary:restRow(i)
  local row, toon = self.rows[i], self._toons[i]
  if not row then return end
  if toon and toon.name == ns.api.GetCurrentCharacter() then
    row:backdropColor(theme.colors.selected)
  elseif toon and (toon.basic.level or 0) < ns.wow.maxLevel then
    row:backdropColor(0, 0, 0, 0.22)
  else
    row:backdropColor(0, 0, 0, 0)
  end
end

-- One cell per column, by position. A column's getData may return nil (no data);
-- map it to "" so the cell array stays index-aligned with the columns — `lists.map`
-- would otherwise drop nils and shift every later column left for that row.
---@param toon Character
---@return table cells  one cell per column, index-aligned with self._columns
function ClassSummary:GetRowData(toon)
  local cells = {}
  for n, c in ipairs(self._columns) do
    cells[n] = c.getData(toon) or ""
  end
  return cells
end

-- Make every cell in row `i` drive the row's hover highlight, chaining onto any
-- existing cell onEnter/onLeave (so the per-column tooltips keep working). On
-- click, a cell that carries its own onClick (e.g. iLvl/Upgrades/Catch-up → Gear,
-- enchants/gems → Detail) keeps it; cells with none open the row's character in
-- the Detail view as a fallback (mirrors Overview's TopAlts). Each cell is
-- a shallow COPY of the source data — several getData functions return shared
-- table objects (e.g. ns.factionIcon[...] for the faction icon), so mutating
-- them in place would chain wrappers across every row that shares the object (and
-- corrupt the shared table globally). Plain string cells become {text=...}. The
-- closures resolve the row + character live (self.rows[i] / self._toons[i]) so
-- they stay correct across re-sorts. Footer cells are left untouched.
---@param cells table  the row's per-column cell data array
---@param i integer    row index
---@return table cells
function ClassSummary:decorateRow(cells, i)
  for n, cell in ipairs(cells) do
    local src = type(cell) == "table" and cell or {text = cell}
    local copy = {}
    for k, v in pairs(src) do copy[k] = v end
    local onEnter, onLeave, onClick = src.onEnter, src.onLeave, src.onClick
    copy.onEnter = function(s)
      local row = self.rows[i]
      if row then row:backdropColor(theme.colors.hover) end
      if onEnter then onEnter(s) end
    end
    copy.onLeave = function(s)
      self:restRow(i)
      if onLeave then onLeave(s) end
    end
    copy.onClick = function(s)
      if onClick then onClick(s); return end
      local toon, w = self._toons[i], ns.MainWindow
      if toon and w then
        w:getView("detail"):Select(toon)
        w:view("detail")
      end
    end
    cells[n] = copy
  end
  return cells
end

-- per-column footer cell data, keyed by column index (columns without a
-- getFooter are left absent so they render no footer cell)
---@param toons Character[]
---@return table footer  per-column footer cell data, keyed by column index
function ClassSummary:GetFooterData(toons)
  local footer = {}
  for i,c in ipairs(self._columns) do
    if c.getFooter then footer[i] = c.getFooter(toons) end
  end
  return footer
end

function ClassSummary:OnBeforeShow()
  local toons = self:GetCharacters()
  self._toons = toons   -- keep row→character mapping current for hover/click
  self.data = {}
  for i,t in ipairs(toons) do
    self.data[i] = self:decorateRow(self:GetRowData(t), i)
  end
  self:update()
  self:setFooter(self:GetFooterData(toons))
  -- Re-sorting can move characters between rows, so refresh resting backdrops.
  for i in ipairs(self.rows) do self:restRow(i) end
end

---@class SummaryView: Frame
---@field alliance ClassSummary
---@field horde ClassSummary
---@field _showAlliance boolean  which faction table is visible
---@field _filter Frame?         titlebar faction toggle (built by BuildFilter)
local SummaryView = Class(ui.Frame, function(self)
  -- default to the current character's faction on first open
  local current = ns.api:GetCharacterData()
  self._showAlliance = not current or current.isAlliance

  -- The user-visible column set (identity columns + non-hidden toggleable ones),
  -- resolved fresh each build so a settings toggle is reflected on rebuild. Each
  -- table gets its OWN column list + colInfo copy: SummaryColumnsDelayed appends the
  -- dynamic DMF column to both (via _columns / addCol), so a shared list would double-add.
  local cols = ns.VisibleSummaryColumns()
  self.alliance = ClassSummary:new{
    parent = self,
    position = { TopLeft = {0, 0} },
    columns = ns.lua.lists.map(cols),
    colInfo = buildColInfo(cols),
  }
  self.horde = ClassSummary:new{
    parent = self,
    position = { TopLeft = {0, 0} },
    isAlliance = false,
    columns = ns.lua.lists.map(cols),
    colInfo = buildColInfo(cols),
  }

  self:layout()
end, {
  name   = "summary",
  background = theme.colors.window,
})
SummaryView.name = "summary"
SummaryView._title = "Summary"
ns.views.SummaryView = SummaryView

function SummaryView:layout()
  local a = self._showAlliance
  self.alliance:SetShown(a)
  self.horde:SetShown(not a)

  local t = a and self.alliance or self.horde
  self:Width(t:Width())
  self:Height(t:Height())
end

function SummaryView:toggleFaction()
  self._showAlliance = not self._showAlliance
  self._showHorde = not self._showAlliance
  self:updateFilter()
  self:layout()
  if ns.MainWindow then ns.MainWindow:Fit() end
end

-- Faction toggle: the current faction's icon + name, tinted blue (Alliance) or
-- red (Horde) with a matching 1px border. Clicking flips to the other faction.
---@param parent Frame
---@return Frame
function SummaryView:BuildFilter(parent)
  local FW, FH, PAD, ICON, GAP = 80, 20, 5, 14, 5
  local box = ui.Frame:new{
    parent = parent,
    position = { Width = FW, Height = FH },
  }
  -- faction-coloured 1px border with a dark interior
  box.border = Texture:new{
    parent = box, layer = ui.layer.Background,
    position = { All = true },
  }
  Texture:new{
    parent = box, layer = ui.layer.Border, color = {0.05, 0.05, 0.06, 0.92},
    position = { TopLeft = {1, -1}, BottomRight = {-1, 1} },
  }
  box.button = Button:new{
    parent = box,
    position = { All = true },
    glow = false,
    OnClick = function() self:toggleFaction() end,
  }
  box.icon = Texture:new{
    parent = box.button, layer = ui.layer.Artwork,
    position = { Left = {PAD, 0}, Size = {ICON, ICON} },
  }
  box.label = Label:new{
    parent = box.button,
    -- mono caps (like the column headers) — crisper than the soft Hanken display
    -- font at this size, and consistent with the rest of the chrome
    fontInfo = {theme.fonts.caps[1], 10},
    position = { Left = {box.icon, ui.edge.Right, GAP, 0} },
  }
  -- dimmed at rest, full opacity on hover
  box.button:Alpha(0.85)
  box.button.OnEnter = function(b) b:Alpha(1) end
  box.button.OnLeave = function(b) b:Alpha(0.85) end

  self._filter = box
  self:updateFilter()
  return box
end

-- Point the toggle at the currently shown faction (icon, name, accent colour).
function SummaryView:updateFilter()
  local f = self._filter
  if not f then return end
  local a = self._showAlliance
  local ico = ns.factionIcon[a]
  local col = a and FACTION_COLOR.alliance or FACTION_COLOR.horde
  f.icon:Texture(ico.path)
  f.icon:Coords(unpack(ico.coords))
  f.icon:SetVertexColor(unpack(ico.vertexColor))
  f.label:Text((a and "Alliance" or "Horde"):upper()):Color(col)
  f.border:Color(col[1], col[2], col[3], 0.9)
end

function SummaryView:OnBeforeShow()
  ns.api:RefreshCurrentCharacterField("weeklies", "keystone")
  ns.api:RefreshCurrentCharacterField("weeklies", "dungeons")
  ns.api:RefreshCurrentCharacterField("weeklies", "vault")
  ns.api:RefreshCurrentCharacterField("weeklies", "hasUnclaimedVault")
  -- DMF has no live event handler, so refresh it on show or the column stays
  -- stale after completing the faire quests this session
  ns.api:RefreshCurrentCharacterField("weeklies", "DMF")
  self.alliance:OnBeforeShow()
  self.horde:OnBeforeShow()
  self:layout()
end
