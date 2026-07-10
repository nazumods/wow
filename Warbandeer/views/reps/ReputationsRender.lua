---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture
local theme = ns.theme
local min, max = math.min, math.max
local ReputationsView = ns.views.ReputationsView

local R = ns.reps
local ROW_H, MAX_H = R.ROW_H, R.MAX_H
local ICON, SIDE, STAND_W = R.ICON, R.SIDE, R.STAND_W
local applyIcon, factionIconSpec, cleanLabel = R.applyIcon, R.factionIconSpec, R.cleanLabel

-- ─── Rows ─────────────────────────────────────────────────────────────────────
-- VirtualList row builders. A pooled row's slot maps 1:1 to its item index, so the row
-- carries its current index in `_index` for the hover/click handlers to select by.

function ReputationsView:_createRow(l)
  local row = Frame:new{
    type = "Button", parent = l:Content(),
    background = {0, 0, 0, 0},
  }
  row._widget:SetMouseMotionEnabled(true)
  row._widget:SetMouseClickEnabled(true)
  row.icon = Texture:new{
    parent = row, layer = ui.layer.Artwork,
    position = { Left = {row, ui.edge.Left, 4, 0}, Size = {ICON, ICON} },
  }
  row.standing = Label:new{
    parent = row, fontInfo = theme.fonts.body, justifyH = ui.justify.Right,
    position = { Right = {row, ui.edge.Right, -6, 0}, Width = STAND_W },
  }
  row.side = Texture:new{
    parent = row, layer = ui.layer.Artwork,
    position = { Right = {row.standing, ui.edge.Left, -6, 0}, Size = {SIDE, SIDE} },
  }
  row.name = Label:new{
    parent = row, fontInfo = theme.fonts.body, justifyH = ui.justify.Left, wordWrap = false,
    position = { Left = {row.icon, ui.edge.Right, 6, 0}, Right = {row.side, ui.edge.Left, -6, 0} },
  }
  row._widget:SetScript("OnEnter", function() self:_select(row._index) end)
  row._widget:SetScript("OnLeave", function() ui.tip:Hide() end)
  row._widget:SetScript("OnMouseUp", function() self:_select(row._index) end)
  return row
end

function ReputationsView:_updateRow(row, e, i)
  row._index = i
  applyIcon(row.icon, factionIconSpec(e.fid))
  row.name:Text(e.name or ("faction " .. e.fid))
  local h = e.highest
  row.standing:Text(h and cleanLabel(h) or "")
  if h and h.paragon then row.standing:Color(0.40, 0.70, 1.00)
  elseif h and h.done then row.standing:Color(0.40, 0.80, 0.40)
  else row.standing:Color(theme.colors.muted) end
  if e.side == nil then
    row.side._widget:Hide()
  else
    applyIcon(row.side, ns.factionIcon[e.side])
    row.side._widget:Show()
  end
  if i == self._sel then row.background:Color(theme.colors.hover) else row.background:Color(0, 0, 0, 0) end
  return ROW_H
end

function ReputationsView:_renderPage()
  local page = self._pages[self._pageIdx]
  local facs = page and page.factions or {}
  local n = #facs
  self._sel = nil -- clear before SetItems so _updateRow paints every row unselected

  -- Size the viewport to the page (short pages shrink so MainWindow:Fit hugs them), then
  -- feed the rows in — SetItems recomputes the scroll range against the new viewport.
  local viewH = min(max(n * ROW_H, ROW_H), MAX_H)
  self.list:Height(viewH)
  self:Height(viewH)
  self.list:SetItems(facs)

  self.emptyMsg[n == 0 and "Show" or "Hide"](self.emptyMsg)

  if n > 0 then self:_highlight(1) end
end

-- Move the selection highlight (and scroll it into view) without touching the tooltip.
function ReputationsView:_highlight(idx)
  local page = self._pages[self._pageIdx]
  local facs = page and page.factions
  if not facs or #facs == 0 then return end
  idx = idx < 1 and 1 or (idx > #facs and #facs or idx)
  if self._sel then
    local prev = self.list:Row(self._sel)
    if prev then prev.background:Color(0, 0, 0, 0) end
  end
  self._sel = idx
  local row = self.list:Row(idx)
  if row then row.background:Color(theme.colors.hover) end
  self.list:ScrollToItem(idx)
end
