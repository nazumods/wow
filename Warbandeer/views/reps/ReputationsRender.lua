---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture
local theme = ns.theme
local min, max = math.min, math.max
local ReputationsView = ns.views.ReputationsView

local R = ns.reps
local ROW_H, CONTENT_W, MAX_H = R.ROW_H, R.CONTENT_W, R.MAX_H
local ICON, SIDE, STAND_W = R.ICON, R.SIDE, R.STAND_W
local applyIcon, factionIconSpec, cleanLabel = R.applyIcon, R.factionIconSpec, R.cleanLabel

-- ─── Rows ─────────────────────────────────────────────────────────────────────

function ReputationsView:_acquireRow(i)
  local row = self._rows[i]
  if row then return row end
  row = Frame:new{
    type = "Button", parent = self.list,
    position = { TopLeft = {self.list, ui.edge.TopLeft, 0, -(i - 1) * ROW_H}, Width = CONTENT_W, Height = ROW_H },
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
  row._widget:SetScript("OnEnter", function() self:_select(i) end)
  row._widget:SetScript("OnLeave", function() ui.tip:Hide() end)
  row._widget:SetScript("OnMouseUp", function() self:_select(i) end)
  self._rows[i] = row
  return row
end

function ReputationsView:_renderPage()
  local page = self._pages[self._pageIdx]
  local facs = page and page.factions or {}

  for i = 1, #facs do
    local row, e = self:_acquireRow(i), facs[i]
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
    row.background:Color(0, 0, 0, 0)
    row._widget:Show()
  end
  for i = #facs + 1, #self._rows do self._rows[i]._widget:Hide() end

  local n = #facs
  self.emptyMsg[n == 0 and "Show" or "Hide"](self.emptyMsg)
  self.list:Height(max(n * ROW_H, 1))
  self._viewH = min(max(n * ROW_H, ROW_H), MAX_H)
  self.scroll:Height(self._viewH)
  self.scroll:VerticalScroll(0)
  self:Height(self._viewH)

  self._sel = nil
  if n > 0 then self:_highlight(1) end
end

-- Move the selection highlight (and scroll it into view) without touching the tooltip.
function ReputationsView:_highlight(idx)
  local page = self._pages[self._pageIdx]
  local facs = page and page.factions
  if not facs or #facs == 0 then return end
  idx = idx < 1 and 1 or (idx > #facs and #facs or idx)
  if self._sel and self._rows[self._sel] then self._rows[self._sel].background:Color(0, 0, 0, 0) end
  self._sel = idx
  self._rows[idx].background:Color(theme.colors.hover)

  local top, bottom = (idx - 1) * ROW_H, idx * ROW_H
  local cur = self.scroll:VerticalScroll()
  if top < cur then self.scroll:VerticalScroll(top)
  elseif bottom > cur + self._viewH then self.scroll:VerticalScroll(bottom - self._viewH) end
end
