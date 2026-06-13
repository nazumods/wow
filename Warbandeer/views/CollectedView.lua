---@type Warbandeer
local ns = select(2, ...)
-- luacheck: globals WarbandeerCollectedApi
local floor, max, min = math.floor, math.max, math.min
local ui = ns.ui
local lists = ns.lua.lists
local prepend = lists.prepend
local Colors = ns.Colors
local theme = ns.theme
local Class, Frame, Label, TableFrame = ns.lua.Class, ui.Frame, ui.Label, ui.TableFrame

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
  position = { TopLeft = {3, -2}, BottomRight = {-3, 2} },
}

-- Tooltip shown while hovering a class cell: set name + collection status.
local function setTip(cell, set, status)
  ui.tip:ClearLines()
  ui.tip:AddLine(set.name)
  if status == true then
    ui.tip:AddLine("Collected", 0.4, 0.85, 0.4)
  else
    ui.tip:AddLine(status.collected .. " / " .. status.total .. " appearances", 0.7, 0.7, 0.7)
    local remaining = status.total - status.collected
    if remaining > 0 then ui.tip:AddLine(remaining .. " remaining", 1, 0.82, 0) end
  end
  ui.tip:AnchorTo(cell, "ANCHOR_RIGHT", 8, 0)
  ui.tip:Show()
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
  GetData = function()
    local api = WarbandeerCollectedApi
    if not api then return {} end
    return lists.map(api.Sets, function(grp)
      local gstat = api:GroupStatus(grp.id)
      -- One cell per class slot; grp.sets always has 13 positional entries, so the
      -- columns stay aligned even where a class has no set (blank {} cell).
      local r = lists.map(grp.sets, function(set)
        local status = set.id and gstat and gstat[set.id]
        if not status then return {} end
        local cell
        if status == true then
          cell = {
            atlas = GreenCheck.atlas, atlasSize = GreenCheck.atlasSize,
            position = GreenCheck.position,
          }
        else
          cell = {
            text = status.total - status.collected,
            justifyH = ui.justify.Center,
            color = shades[max(1, floor(status.collected / status.total * 10))],
          }
        end
        cell.onEnter = function(c) setTip(c, set, status) end
        cell.onLeave = function() ui.tip:Hide() end
        return cell
      end)
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
