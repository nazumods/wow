---@type Warbandeer
local ns = select(2, ...)
local floor, max, min = math.floor, math.max, math.min
local ui = ns.ui
local lists = ns.lua.lists
local prepend = lists.prepend
local Colors = ns.Colors
local theme = ns.theme
local Class, Frame, Label, TableFrame = ns.lua.Class, ui.Frame, ui.Label, ui.TableFrame
local Button, Texture = ui.Button, ui.Texture

-- Transmog-set collection grid, sourced from the sibling Collected addon via the
-- WarbandeerCollectedApi global (OptionalDep). Mirrors that addon's own DataView:
-- one row per set group, one column per class, cell = uncollected appearance count
-- shaded red→green by completion (green check when a class set is fully collected).
-- Lockout columns/side-panel are intentionally omitted here — see Collected's own
-- /collected window for those.

local HDR_H        = 18   -- counter strip above the grid
local MAX_GRID_H   = 460  -- cap the scrollable row area; window stays usable
local SCROLLBAR_W  = 20

-- 10-shade red→green gradient keyed by collected fraction (matches Collected/DataView)
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
  -- Centered, ~one character wide so it lines up with the numeric count cells.
  position = { Center = {}, Size = {13, 13} },
}

-- A class set counts as fully collected when the scan flagged the base set (true)
-- or every appearance is owned (remaining <= 0). The `or` short-circuits before
-- indexing `status`, so passing the boolean `true` is safe.
local function isComplete(status)
  return status == true or status.collected >= status.total
end

-- Position the shared Collected InfoTip on the user-configured side
-- (ns.TooltipSide(): 2 = Right, extends rightward from the cell; 1 = Left, extends
-- leftward), mirroring the side behaviour of Warbandeer's other tooltips.
local function tipPosition(cell)
  if ns.TooltipSide() == 2 then
    return { TopLeft = {cell, ui.edge.TopRight, 4, 0} }
  end
  return { TopRight = {cell, ui.edge.TopLeft, -4, 0} }
end

-- ─── Grid (TableFrame) ──────────────────────────────────────────────────────

---@class CollectedGrid: TableFrame
local Grid = Class(TableFrame, function(self)
  -- Auto-size the (zero-width) name column to the widest group label, then grow
  -- the row area + frame to match (the base table built it at width 0).
  local w = 0
  for _, r in ipairs(self.cells) do
    if r[1] and r[1].label then w = max(w, r[1].label:Width()) end
  end
  self.cols[1]:Width(w)
  self.rowArea:Width(self.rowArea:Width() + w)
  self:Width(self:Width() + w)
end, {
  headerHeight = 28,
  colInfo = prepend(
    lists.map(ns.icons.classes, function(icon)
      return {
        atlas = icon,
        atlasSize = false,
        width = 28,
        padding = 2,
        justifyH = ui.justify.Center,
        backdrop = {color = Colors.TransparentBlack},
      }
    end),
    { width = 0, backdrop = {color = Colors.TransparentBlack} }  -- group-name column
  ),
  GetData = function(self)
    local api = WarbandeerCollectedApi
    if not api then return {} end
    -- Default order is ns.Sets (oldest expansion first); _reverse flips to newest first.
    local groups = api.Sets
    if self._reverse then
      groups = {}
      for i = #api.Sets, 1, -1 do groups[#groups + 1] = api.Sets[i] end
    end
    return lists.map(groups, function(grp)
      local gstat = api:GroupStatus(grp.id)
      -- One positional cell per class slot (blank {} where a class has no set).
      local r = lists.map(grp.sets, function(set)
        local status = set.id and gstat and gstat[set.id]
        if not status then return {} end
        -- Same per-slot source tooltip as the /collected window (via the API) on
        -- every cell — complete or partial; a fully-collected set shows all green.
        local onEnter = function(c)
          WarbandeerCollectedApi:ShowInfoTip(grp, set, c, tipPosition(c))
        end
        local onLeave = function() WarbandeerCollectedApi:HideInfoTip() end
        if isComplete(status) then
          return {
            atlas = GreenCheck.atlas, atlasSize = GreenCheck.atlasSize,
            position = GreenCheck.position,
            onEnter = onEnter, onLeave = onLeave,
          }
        end
        return {
          text = status.total - status.collected,
          justifyH = ui.justify.Center,
          color = shades[max(1, floor(status.collected / status.total * 10))],
          onEnter = onEnter,
          onLeave = onLeave,
        }
      end)
      -- grp.sets can stop short of the newest classes (no Demon Hunter/Evoker entry
      -- in older raids), leaving those columns cell-less. Pad to the full class count
      -- so they blank out instead of keeping another row's value on re-sort.
      for i = #r + 1, #ns.icons.classes do r[i] = {} end
      table.insert(r, 1, { text = grp.name })
      return r
    end)
  end,
})

-- ─── CollectedView ──────────────────────────────────────────────────────────

---@class CollectedView: Frame
---@field grid CollectedGrid
---@field scroll ScrollFrame
---@field counter Label
---@field emptyMsg Label
local CollectedView = Class(Frame, function(self)
  self.counter = Label:new{
    parent = self, fontInfo = theme.fonts.body, color = theme.colors.muted,
    position = { TopLeft = {2, -2}, Height = HDR_H },
    text = "",
  }

  self.grid = Grid:new{
    parent = self,
    position = { TopLeft = {0, -HDR_H} },
  }

  local rowsH = self.grid.rowArea:Height()
  local capH = min(MAX_GRID_H, rowsH)
  local gridW = self.grid:Width()

  self.scroll = ui.ScrollFrame:new{
    parent = self,
    position = {
      TopLeft = {0, -HDR_H - self.grid.headerHeight},
      Width   = gridW,
      Height  = capH,
    },
  }
  self.scroll:Child(self.grid.rowArea)

  -- Shown when there's nothing to render (Collected not installed / never scanned).
  self.emptyMsg = Label:new{
    parent = self, fontInfo = theme.fonts.body, color = theme.colors.muted,
    position = { TopLeft = {2, -HDR_H - 6}, Width = 280, Height = 20, Hide = true },
  }

  self:Width(gridW + SCROLLBAR_W)
  self:Height(HDR_H + self.grid.headerHeight + capH + 4)
end, {})
CollectedView.name = "collected"
CollectedView._title = "Collected"
ns.views.CollectedView = CollectedView

-- Refresh counts, grid data, and the empty-state message each time the view shows
-- (so a /collected scan run after the view was built is reflected on next open).
function CollectedView:OnBeforeShow()
  local api = WarbandeerCollectedApi
  if not api then
    self.counter:Text("")
    self.emptyMsg:Text("Collected add-on not loaded")
    self.emptyMsg:Show()
    return
  end
  if not api:IsScanned() then
    self.counter:Text("")
    self.emptyMsg:Text("Run /collected scan to populate")
    self.emptyMsg:Show()
    return
  end
  self.emptyMsg:Hide()
  local collected, total = api:Counts()
  self.counter:Text("Sets: " .. collected .. " / " .. total)
  self.grid.data = self.grid:GetData()
  self.grid:update()
end

-- Titlebar control: a single toggle button flipping raid (row) order between
-- oldest-first (ns.Sets order) and newest-first. Mirrors GearView's filter chrome.
function CollectedView:BuildFilter(parent)
  local BW, BH, PAD = 96, 20, 8
  local box = Frame:new{ parent = parent, position = { Width = BW, Height = BH } }

  self._sortBorder = Texture:new{
    parent = box, layer = ui.layer.Background,
    position = { All = true }, color = theme.colors.divider,
  }
  Texture:new{
    parent = box, layer = ui.layer.Border, color = {0.05, 0.05, 0.06, 0.92},
    position = { TopLeft = {1, -1}, BottomRight = {-1, 1} },
  }
  local btn = Button:new{
    parent = box, position = { All = true }, glow = false,
    OnClick = function() self:_toggleSort() end,
  }
  self._sortLabel = Label:new{
    parent = btn, fontInfo = {theme.fonts.caps[1], 10}, justifyH = ui.justify.Center,
    position = { Left = {PAD, 0}, Right = {-PAD, 0} },
    text = "OLDEST FIRST",
  }

  return box
end

-- Flip the grid's row order in place (cells are reused; see Cell:Label).
function CollectedView:_toggleSort()
  self.grid._reverse = not self.grid._reverse
  self._sortLabel:Text(self.grid._reverse and "NEWEST FIRST" or "OLDEST FIRST")
  self._sortBorder:Color(self.grid._reverse and theme.colors.gold or theme.colors.divider)
  self.grid.data = self.grid:GetData()
  self.grid:update()
end
