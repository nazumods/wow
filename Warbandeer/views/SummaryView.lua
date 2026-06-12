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

-- Base column layout, built once at load: shallow-copy each column's colInfo with
-- uppercased text headers (icon-only columns have no name and are unaffected; the
-- muted header color comes from the theme). The source colInfo is left untouched.
-- Each ClassSummary instance gets its OWN shallow copy of this list (see :new
-- below) — addCol mutates self.colInfo in place (the dynamic DMF column), so a
-- shared table would leak that column into every sibling table built afterwards.
local BASE_COL_INFO = ns.lua.lists.map(ns.SummaryColumns, function(c, i)
  local info = {}
  for k, v in pairs(c.colInfo) do info[k] = v end
  if info.name and info.name ~= "" then info.name = info.name:upper() end
  -- inset the outer columns' cells so they don't sit against the table edges
  if i == 1 then info.hPadL = 8 end
  -- the right-aligned Gold column also insets its header to match its cells:
  -- cells use hPadR, headers use the symmetric `padding`, so set both (the
  -- header's left inset is invisible under right-justification)
  if i == #ns.SummaryColumns then info.hPadR = 8; info.padding = 8 end
  return info
end)

local ClassSummary = Class(TableFrame, function(self)
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
function ClassSummary:GetRowData(toon)
  local cells = {}
  for n, c in ipairs(ns.SummaryColumns) do
    cells[n] = c.getData(toon) or ""
  end
  return cells
end

-- Make every cell in row `i` drive the row's hover highlight and open that
-- character in the Detail view on click, chaining onto any existing cell
-- onEnter/onLeave/onClick (so the per-column tooltips keep working). Each cell is
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
      if onClick then onClick(s) end
      local toon, w = self._toons[i], ns.MainWindow
      if toon and w then
        w.views.detail:Select(toon)
        w:view("detail")
      end
    end
    cells[n] = copy
  end
  return cells
end

-- per-column footer cell data, keyed by column index (columns without a
-- getFooter are left absent so they render no footer cell)
function ClassSummary:GetFooterData(toons)
  local footer = {}
  for i,c in ipairs(ns.SummaryColumns) do
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

local SummaryView = Class(ui.Frame, function(self)
  -- default to the current character's faction on first open
  local current = ns.api:GetCharacterData()
  self._showAlliance = not current or current.isAlliance

  -- glass-module surface behind the active table
  -- self.moduleBg = Texture:new{
  --   parent = self, layer = ui.layer.Artwork, color = theme.colors.module,
  --   position = { TopLeft = {0, 0}, Width = 12, Height = 12 },
  -- }

  -- Each table gets its own shallow copy of the base columns; addCol (the dynamic
  -- DMF column) mutates self.colInfo in place, so a shared list would double-add.
  self.alliance = ClassSummary:new{
    parent = self,
    position = { TopLeft = {0, 0} },
    colInfo = ns.lua.lists.map(BASE_COL_INFO),
  }
  self.horde = ClassSummary:new{
    parent = self,
    position = { TopLeft = {0, 0} },
    isAlliance = false,
    colInfo = ns.lua.lists.map(BASE_COL_INFO),
  }

  self:layout()
end, {
  name   = "summary",
  _title = "Summary",
  background = theme.colors.window,
})
SummaryView.name = "summary"
ns.views.SummaryView = SummaryView

function SummaryView:layout()
  local a = self._showAlliance
  self.alliance:SetShown(a)
  self.horde:SetShown(not a)

  local t = a and self.alliance or self.horde
  -- self.moduleBg:Width(t:Width())
  -- self.moduleBg:Height(t:Height())
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
