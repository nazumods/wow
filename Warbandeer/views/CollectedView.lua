---@type Warbandeer
local ns = select(2, ...)
local min = math.min
local ui = ns.ui
local theme = ns.theme
local Class, Frame, Label = ns.lua.Class, ui.Frame, ui.Label
local Button, Texture = ui.Button, ui.Texture

-- Transmog-set collection grid. The grid itself is the sibling Collected addon's
-- own DataView, reused in `embedded` mode via the WarbandeerCollectedApi global
-- (OptionalDep) — one source of truth, maintained in Collected/DataView.lua. This
-- view owns only the surrounding chrome: the scroll container, the header counters
-- and the titlebar filter toggles. Embedded mode drops the lock column / lockout
-- side-panel — see Collected's own /collected window for those.
--
-- The whole view is only registered (see the bottom of the file) when the Collected
-- addon is loaded, so the grid is always present once a CollectedView is built.

local SCROLLBAR_W  = 20

-- The live view instance, captured so the grid's wanted-toggle hook and the
-- ratings-changed listener can refresh this view's header.
local _view

---@class CollectedView: Frame
---@field grid DataView the shared set-by-class grid (Collected's own DataView, embedded)
---@field scroll ScrollFrame
---@field counter Label
---@field wantedCount Label running "★ N" wanted-set count (mirrors the /collected window)
---@field emptyMsg Label
---@field _wantedBorder Texture "wanted only" filter border (gold while active)
---@field _ptrBorder Texture live/PTR toggle border (gold while in PTR mode)
---@field _sortBorder Texture raid-order toggle border (gold once newest-first)
---@field _sortLabel Label raid-order toggle caption
local CollectedView = Class(Frame, function(self)
  _view = self

  self.grid = WarbandeerCollectedApi.DataView:new{
    parent = self,
    position = { TopLeft = {0, 0} },
    embedded = true,
    colInfo = WarbandeerCollectedApi.DataView.BuildColInfo(true),  -- no lock column
    -- Anchor the hover InfoTip on the configured side (shared with Overview's set
    -- cells); refresh this view's wanted tally after a Shift-click toggle.
    infoTipAnchor = ns.InfoTipPosition,
    onWantedToggle = function() _view:RefreshWanted() end,
  }

  local headerH = self.grid.headerHeight
  local capH = min(self.grid.MAX_HEIGHT, self.grid.rowArea:Height())
  local gridW = self.grid:Width()

  self.scroll = ui.ScrollFrame:new{
    parent = self,
    position = {
      TopLeft = {0, -headerH},
      Width   = gridW,
      Height  = capH,
    },
  }
  self.scroll:Child(self.grid.rowArea)

  -- Counter rides the grid's header row, over the empty group-name column and in
  -- line with the class icons (mirrors the /collected window). Created after the
  -- grid so it draws above the header cells; vertically centred in the header.
  local hdrPad = (headerH - theme.fonts.title[2]) / 2
  self.counter = Label:new{
    parent = self, fontInfo = theme.fonts.title, color = theme.colors.text,
    position = { TopLeft = {2, -hdrPad} },
    text = "",
  }
  self.wantedCount = Label:new{
    parent = self, fontInfo = theme.fonts.title, color = theme.colors.gold,
    position = { Left = {self.counter, ui.edge.Right, 16, 0} },
    text = "",
  }

  -- Shown before the first /collected scan has populated any data. Centered below the
  -- header; the grid is hidden while it shows (see _showGrid) so it never overlaps the
  -- static row names.
  self.emptyMsg = Label:new{
    parent = self, fontInfo = theme.fonts.body, color = theme.colors.muted,
    justifyH = ui.justify.Center,
    position = { Top = {0, -headerH - 28}, Width = gridW, Height = 20, Hide = true },
  }

  self:Width(gridW + SCROLLBAR_W)
  self:Height(headerH + capH + 4)
end, {})
CollectedView.name = "collected"
CollectedView._title = "Collected"

-- Only surface the view (nav icon, minimap menu, and slash command all derive from
-- ns.views) when the sibling Collected addon is loaded — the whole view is its data.
-- OptionalDeps load before us, so the API global is already set here when present.
if WarbandeerCollectedApi and WarbandeerCollectedApi.DataView then
  ns.views.CollectedView = CollectedView
end

-- Live-refresh this view's grid when a rating changes in the shared dressing room
-- (registered once at load; Collected loads first via the OptionalDep order).
if WarbandeerCollectedApi and WarbandeerCollectedApi.OnRatingsChanged then
  WarbandeerCollectedApi:OnRatingsChanged(function()
    local g = _view and _view.grid
    if not g then return end
    if g._wantedOnly then g.data = g:GetData(); g:update() else g:_refreshMarks() end
    _view:RefreshWanted()
  end)
end

-- Refresh counts, grid data, and the empty-state message each time the view shows
-- (so a /collected scan run after the view was built is reflected on next open).
function CollectedView:OnBeforeShow()
  self:_render()
end

-- Show/hide the grid (header icons + scrolling rows) as a unit, so the empty-state
-- message can take over a clear area instead of overlapping the static row names.
function CollectedView:_showGrid(shown)
  self.grid:SetShown(shown)
  self.scroll:SetShown(shown)
end

-- Hide the grid and show the centered empty-state message with the given text.
function CollectedView:_showEmpty(text)
  self:_showGrid(false)
  self.emptyMsg:Text(text)
  self.emptyMsg:Show()
end

-- Render the active dataset. PTR PREVIEW shows live + upcoming together (no scan
-- needed for the upcoming rows); live-only mode shows collected/total and needs a scan.
function CollectedView:_render()
  local api = WarbandeerCollectedApi
  local ptr = self.grid._ptr
  if not ptr and not api:IsScanned() then
    self.counter:Text("")
    self.wantedCount:Text("")
    self:_showEmpty("Run /collected scan to populate")
    return
  end
  self.emptyMsg:Hide()
  self:_showGrid(true)
  if ptr then
    local seen, n = {}, 0
    for _, grp in ipairs(api.PtrSets or {}) do
      for _, set in ipairs(grp.sets) do
        if set.id and not seen[set.id] then seen[set.id] = true; n = n + 1 end
      end
    end
    self.counter:Text(("+%d sets upcoming%s"):format(n, api.PtrBuild and (" · PTR " .. api.PtrBuild.ptr) or ""))
  else
    local collected, total = api:Counts()
    self.counter:Text("Sets: " .. collected .. " / " .. total)
  end
  -- The PTR line (with the build) is longer than the live count, so shrink the counter
  -- font in PTR mode so it stays within the name column, clear of the class icons.
  self.counter:Font(ptr and {theme.fonts.title[1], 12} or theme.fonts.title)
  self:RefreshWanted()
  self.grid.data = self.grid:GetData()
  self.grid:update()
end

-- Refresh the running wanted-set count in the header (gold star + N), matching the
-- /collected window. The star is drawn from the shared WantedIcon atlas rather than
-- a literal glyph so it renders in the body font.
function CollectedView:RefreshWanted()
  local api = WarbandeerCollectedApi
  self.wantedCount:Text(("|A:%s:14:14|a %d"):format(api.WantedIcon, api:WantedCount()))
end

-- Titlebar control: three toggle buttons — a live/PTR preview switch, a "wanted
-- only" filter, and a raid (row) order flip (oldest/newest-first). Mirrors GearView's
-- filter chrome and the /collected window's own title-bar toggles.
function CollectedView:BuildFilter(parent)
  local BW, BH, PAD, GAP, DW = 96, 20, 8, 6, 110
  local box = Frame:new{ parent = parent, position = { Width = BW * 3 + (DW + GAP) * 2 + GAP * 2, Height = BH } }

  -- One framed toggle at x; returns its (recolorable) border and caption.
  local function toggle(xoff, text, active, onClick)
    local b = Frame:new{ parent = box, position = { TopLeft = {xoff, 0}, Width = BW, Height = BH } }
    local border = Texture:new{
      parent = b, layer = ui.layer.Background,
      position = { All = true }, color = active and theme.colors.gold or theme.colors.divider,
    }
    Texture:new{
      parent = b, layer = ui.layer.Border, color = {0.05, 0.05, 0.06, 0.92},
      position = { TopLeft = {1, -1}, BottomRight = {-1, 1} },
    }
    local btn = Button:new{ parent = b, position = { All = true }, glow = false, OnClick = onClick }
    local label = Label:new{
      parent = btn, fontInfo = {theme.fonts.caps[1], 10}, justifyH = ui.justify.Center,
      position = { Left = {PAD, 0}, Right = {-PAD, 0} }, text = text,
    }
    return border, label
  end

  self._ptrBorder = (toggle(0, "PTR PREVIEW", false, function()
    local on = self.grid:SetPtr(not self.grid._ptr)
    self._ptrBorder:Color(on and theme.colors.gold or theme.colors.divider)
    self:_render()
  end))

  self._wantedBorder = (toggle(BW + GAP, "WANTED ONLY", false, function()
    local on = self.grid:ToggleWantedOnly()
    self._wantedBorder:Color(on and theme.colors.gold or theme.colors.divider)
  end))

  self._sortBorder, self._sortLabel = toggle((BW + GAP) * 2, "NEWEST FIRST", true, function() self:_toggleSort() end)

  -- Expansion + category filter dropdowns (right of the toggles).
  local dx = (BW + GAP) * 3
  ui.FilterDropdown:new{
    parent = box, position = { TopLeft = {dx, 0} }, width = DW, menuWidth = 150,
    selected = "all", options = self.grid:ExpansionOptions(),
    onSelect = function(_, key) self.grid:SetExpansion(key) end,
  }
  ui.FilterDropdown:new{
    parent = box, position = { TopLeft = {dx + DW + GAP, 0} }, width = DW, menuWidth = 120,
    selected = "all", options = self.grid:CategoryOptions(),
    onSelect = function(_, key) self.grid:SetCategory(key) end,
  }

  return box
end

-- Flip the grid's row order in place (cells are reused; see Cell:Label).
function CollectedView:_toggleSort()
  local rev = self.grid:ToggleOrder()
  self._sortLabel:Text(rev and "NEWEST FIRST" or "OLDEST FIRST")
  self._sortBorder:Color(rev and theme.colors.gold or theme.colors.divider)
end
