---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local filter = ns.lua.lists.filter
local Class, TableFrame, Texture, Button, Label = ns.lua.Class, ui.TableFrame, ui.Texture, ui.Button, ui.Label
local theme = ns.theme

-- Faction modes, left→right (also the segment order).
local FACTIONS = {"alliance", "horde", "both"}

-- A roster that would exceed ~95% of the screen height scrolls instead of growing
-- the window off the display — a large warband, or the merged "both" roster, can
-- run past the bottom of the screen. The active table is hosted in a ScrollFrame
-- capped at this height (whole table scrolls); shorter rosters fit fully and the
-- themed scrollbar hides itself. Computed live so it tracks resolution / UI-scale
-- changes; WINDOW_CHROME leaves room for the titlebar + Fit padding so the *window*
-- stays within 95%, not just the table.
local SCROLLBAR_W = 16
local WINDOW_CHROME = 34
local function maxTableHeight()
  return UIParent:GetHeight() * 0.95 - WINDOW_CHROME
end

-- Faction accent colours for the toggle (Alliance blue / Horde red / Both gold),
-- matching the ns.factionIcon tints; the neutral "both" state borrows the theme gold.
local FACTION_COLOR = {
  alliance = {0.40, 0.733, 1.0, 1},
  horde    = {1.0,  0.125, 0.125, 1},
  both     = theme.colors.gold,
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
-- `faction` selects the roster: a single side, or "both" for the merged warband list.
---@class ClassSummary: TableFrame
---@field faction "alliance"|"horde"|"both"  which roster this table shows
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

  -- Size any opted-in column (e.g. Titles) to the widest cell it actually shows. We resize the
  -- column and grow the table + rowArea by the delta directly rather than calling
  -- TableFrame:Autosize, whose width recompute is the plain sum of column widths and so drops the
  -- per-column gutters this view inserts (COL_GUTTER) — under-sizing the frame and spilling the
  -- last column past the window edge.
  for i, info in ipairs(self.colInfo) do
    if info.autosize then self:AutosizeColumn(i) end
  end
end, {
  faction = "alliance",
  backdrop = {color = ns.Colors.TransparentBlack},
  footerBackdrop = {color = theme.colors.moduleHi},
})

-- Resize column `i` to the widest text it currently renders (its header + every cell), then grow
-- the table + rowArea by the delta so the gutter-spaced column chain and the pinned footer stay
-- aligned (see the call site for why TableFrame:Autosize can't be used here). Cells and the footer
-- cell anchor to their column's edges, so the resize reflows them and every column after it.
---@param i integer  column index to size
function ClassSummary:AutosizeColumn(i)
  local col = self.cols[i]
  if not col then return end
  local widest = (col.header.label and col.header.label:UnboundedWidth()) or 0
  for r = 1, #self.rows do
    local cell = self.cells[r] and self.cells[r][i]
    if cell and cell.label then widest = math.max(widest, cell.label:UnboundedWidth()) end
  end
  local target = math.ceil(widest) + 6  -- +6: a little breathing room before the next column
  local delta = target - col:Width()
  if delta == 0 then return end
  col:Width(target)
  self:Width(self:Width() + delta)
  self.rowArea:Width(self.rowArea:Width() + delta)
end

-- This table's roster, sorted by level/ilvl/name. "both" returns the whole warband
-- unfiltered (the faction column distinguishes the sides); a single-side table
-- filters to that faction.
---@return Character[]
function ClassSummary:GetCharacters()
  local toons = ns.api.GetAllCharacters() -- returns a copy
  if self.faction ~= "both" then
    local wantAlliance = self.faction == "alliance"
    toons = filter(toons, function(t)
      return t.isAlliance == wantAlliance
    end)
  end
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
---@field both ClassSummary
---@field _scrolls table<string, ScrollFrame>  faction mode -> the table's capped scroll host
---@field _faction "alliance"|"horde"|"both"  which roster is visible
---@field _segments table<string, Frame>?     titlebar faction segments (built by BuildFilter)
---@field _filter Frame?                       titlebar faction segmented control
local SummaryView = Class(ui.Frame, function(self)
  -- default to the current character's faction on first open
  local current = ns.api:GetCharacterData()
  self._faction = (not current or current.isAlliance) and "alliance" or "horde"

  -- The user-visible column set (identity columns + non-hidden toggleable ones),
  -- resolved fresh each build so a settings toggle is reflected on rebuild. Each
  -- table gets its OWN column list + colInfo copy: SummaryColumnsDelayed appends the
  -- dynamic DMF column to each (via _columns / addCol), so a shared list would double-add.
  local cols = ns.VisibleSummaryColumns()
  self._scrolls = {}
  -- Build a roster table and host ONLY its row area in a ScrollFrame, so the header
  -- row and the totals footer stay pinned while the rows scroll (a tall warband — or
  -- the merged "both" roster — can exceed the screen). The table's `rowArea` becomes
  -- the scroll child; the footer is re-anchored just below the scroll viewport (out of
  -- the scroll area). Table (header cols + footer) and scroll (rows) are siblings in the
  -- view, so layout() toggles BOTH per faction.
  local function makeTable(faction)
    local tbl = ClassSummary:new{
      parent = self,
      position = { TopLeft = {0, 0} },
      faction = faction,
      columns = ns.lua.lists.map(cols),
      colInfo = buildColInfo(cols),
    }
    local scroll = ui.ScrollFrame:new{
      parent = self,
      scrollbar = true,
      scrollbarWidth = SCROLLBAR_W,
      position = { TopLeft = {0, -tbl.headerHeight} },
    }
    scroll:Child(tbl.rowArea)
    tbl.footerRow:ClearAllPoints()
    tbl.footerRow:TopLeft(scroll, ui.edge.BottomLeft, 0, 0)
    tbl.footerRow:Width(tbl:Width())
    self._scrolls[faction] = scroll
    return tbl
  end
  self.alliance = makeTable("alliance")
  self.horde    = makeTable("horde")
  self.both     = makeTable("both")

  self:layout()

  -- Cold-session FontString rasterization heal, mirroring Overview: the
  -- ClassSummary tables are built here on the first (lazy) open, so without this a
  -- cold-session first Summary open can render the identity cells blank. Idempotent —
  -- see ns.HealCellFonts.
  ns:after(50, function()
    ns.HealCellFonts(self.alliance)
    ns.HealCellFonts(self.horde)
    ns.HealCellFonts(self.both)
  end)
end, {
  name   = "summary",
  background = theme.colors.window,
})
SummaryView.name = "summary"
SummaryView._title = "Summary"
ns.views.SummaryView = SummaryView

-- The currently visible roster table.
---@return ClassSummary
function SummaryView:_activeTable()
  if self._faction == "horde" then return self.horde end
  if self._faction == "both" then return self.both end
  return self.alliance
end

function SummaryView:layout()
  for _, f in ipairs(FACTIONS) do
    local shown = self._faction == f
    self[f]:SetShown(shown)            -- header cols + pinned totals footer
    self._scrolls[f]:SetShown(shown)   -- the scrolling row area
  end

  -- Only the row area scrolls; the header + footer sit outside it. Cap the whole view
  -- (header + rows + footer) at ~95% of the screen height — the rows get whatever is
  -- left and scroll once they'd exceed it. The scrollbar's visibility and its reserved
  -- gutter both derive from one truth: the live scroll range (`scroll:Scrolls()`, the
  -- same range `_syncScrollbar` reads) — so a short roster keeps a tight, bar-free right
  -- edge and the two can never disagree.
  local t = self:_activeTable()
  local scroll = self._scrolls[self._faction]
  local headerH, footerH = t.headerHeight, t.footerHeight
  local rowsH = t.rowArea:Height()
  local avail = maxTableHeight() - headerH - footerH
  -- Cap the viewport at the available height, but treat a roster within ~0.5px of
  -- fitting as fitting, so float noise never trips a scrollbar for a full roster.
  local capH = rowsH <= avail + 0.5 and rowsH or avail
  scroll:Height(capH)
  scroll:Refresh()   -- settle the scroll range for this viewport + (possibly re-sorted) rows
  local scrolling = scroll:Scrolls()   -- reserve the gutter iff the bar is actually showing
  scroll:Width(t:Width() + (scrolling and SCROLLBAR_W or 0))
  -- keep the table frame (its transparent column backgrounds) covering exactly the
  -- header + visible rows + footer band
  t:Height(headerH + capH + footerH)

  self:Width(scroll:Width())
  self:Height(headerH + capH + footerH)
end

---@param mode "alliance"|"horde"|"both"
function SummaryView:setFaction(mode)
  if self._faction == mode then return end
  self._faction = mode
  self:updateFilter()
  self:_activeTable():OnBeforeShow()  -- refresh the newly shown roster before sizing
  self:layout()
  if ns.MainWindow then ns.MainWindow:Fit() end
end

-- Segment order, left to right, for both build + update.
local FACTION_SEGS = {
  { mode = "alliance", label = "ALLIANCE", icons = {true},        w = 82 },
  { mode = "horde",    label = "HORDE",    icons = {false},       w = 62 },
  { mode = "both",     label = "BOTH",     icons = {true, false}, w = 74 },
}

-- Faction filter: a joined 3-segment control (Alliance / Horde / Both), one active
-- at a time. Each segment is a bordered box (butted together so the borders read as
-- dividers), carrying its faction icon(s) + a mono-caps label; the "both" segment
-- shows both crests. The active segment is tinted its faction accent (Alliance blue /
-- Horde red / Both gold) on border + label, inactive ones muted + dimmed. Modelled on
-- GearView's armor-type strip. Clicking a segment switches the shown roster.
---@param parent Frame
---@return Frame
function SummaryView:BuildFilter(parent)
  local BH, PAD, ICON, GAP, IGAP = 20, 6, 13, 4, 2
  local totalW = 0
  for _, s in ipairs(FACTION_SEGS) do totalW = totalW + s.w end
  local box = ui.Frame:new{
    parent = parent,
    position = { Width = totalW, Height = BH },
  }

  self._segments = {}
  local x = 0
  for _, seg in ipairs(FACTION_SEGS) do
    local b = ui.Frame:new{
      parent = box,
      position = { Left = {box, ui.edge.Left, x, 0}, Width = seg.w, Height = BH },
    }
    -- faction-accent 1px border with a dark interior
    b.border = Texture:new{
      parent = b, layer = ui.layer.Background,
      position = { All = true },
    }
    Texture:new{
      parent = b, layer = ui.layer.Border, color = {0.05, 0.05, 0.06, 0.92},
      position = { TopLeft = {1, -1}, BottomRight = {-1, 1} },
    }
    b.button = Button:new{
      parent = b,
      position = { All = true },
      glow = false,
      OnClick = function() self:setFaction(seg.mode) end,
    }
    -- faction crest(s), laid out left→right so they never collide; the "both"
    -- segment shows two slightly-smaller crests side by side.
    local isz = #seg.icons > 1 and 11 or ICON
    local ix = PAD
    for _, isAlliance in ipairs(seg.icons) do
      local ico = ns.factionIcon[isAlliance]
      local t = Texture:new{
        parent = b.button, layer = ui.layer.Artwork,
        position = { Left = {ix, 0}, Size = {isz, isz} },
      }
      t:Texture(ico.path)
      t:Coords(unpack(ico.coords))
      t:SetVertexColor(unpack(ico.vertexColor))
      ix = ix + isz + IGAP
    end
    local iconRight = ix - IGAP
    b.label = Label:new{
      parent = b.button,
      -- mono caps (like the column headers) — crisper than the soft Hanken display
      -- font at this size, and consistent with the rest of the chrome
      fontInfo = {theme.fonts.caps[1], 10},
      position = { Left = {iconRight + GAP, 0} },
      text = seg.label,
    }
    self._segments[seg.mode] = b
    x = x + seg.w
  end

  self._filter = box
  self:updateFilter()
  return box
end

-- Tint each segment to reflect the active faction (accent border + label + full
-- opacity vs. muted + dimmed).
function SummaryView:updateFilter()
  if not self._segments then return end
  for _, seg in ipairs(FACTION_SEGS) do
    local b = self._segments[seg.mode]
    if b then
      local active = self._faction == seg.mode
      local col = active and FACTION_COLOR[seg.mode] or theme.colors.muted
      b.label:Color(col)
      local bc = active and FACTION_COLOR[seg.mode] or theme.colors.border
      b.border:Color(bc[1], bc[2], bc[3], active and 0.9 or 0.4)
      b.button:Alpha(active and 1 or 0.7)
    end
  end
end

function SummaryView:OnBeforeShow()
  ns.api:RefreshCurrentCharacterField("weeklies", "keystone")
  ns.api:RefreshCurrentCharacterField("weeklies", "dungeons")
  ns.api:RefreshCurrentCharacterField("weeklies", "vault")
  ns.api:RefreshCurrentCharacterField("weeklies", "hasUnclaimedVault")
  -- DMF has no live event handler, so refresh it on show or the column stays
  -- stale after completing the faire quests this session
  ns.api:RefreshCurrentCharacterField("weeklies", "DMF")
  -- Only the visible roster needs a rebuild; setFaction refreshes the others as
  -- they become active.
  self:_activeTable():OnBeforeShow()
  self:layout()
end
