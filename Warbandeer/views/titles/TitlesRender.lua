---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture
local theme = ns.theme
local min, max = math.min, math.max
local TitlesView = ns.views.TitlesView

local T = ns.titles
local ROW_H, MAX_H, ICON, MARK_W = T.ROW_H, T.MAX_H, T.ICON, T.MARK_W
local rarityCode = T.rarityCode
local CHECK = "Interface\\RaidFrame\\ReadyCheck-Ready" -- earned marker
local END, GOLD = "|r", "|cffffd200"
local RED, RED_CODE = {0.86, 0.40, 0.40}, "|cffdb6666" -- unearnable (can't currently get it)

-- ─── Rows ─────────────────────────────────────────────────────────────────────
-- VirtualList row builders. A pooled row's slot maps 1:1 to its item index, so the row carries
-- its current index in `_index` for the hover/click handlers to select by.

function TitlesView:_createRow(l)
  local row = Frame:new{
    type = "Button", parent = l:Content(),
    background = {0, 0, 0, 0},
  }
  row._widget:SetMouseMotionEnabled(true)
  row._widget:SetMouseClickEnabled(true)
  row.check = Texture:new{
    parent = row, layer = ui.layer.Artwork,
    position = { Left = {row, ui.edge.Left, 6, 0}, Size = {ICON, ICON} },
  }
  row.check:Texture(CHECK)
  row.mark = Label:new{
    parent = row, fontInfo = theme.fonts.body, justifyH = ui.justify.Right,
    position = { Right = {row, ui.edge.Right, -6, 0}, Width = MARK_W },
  }
  row.name = Label:new{
    parent = row, fontInfo = theme.fonts.body, justifyH = ui.justify.Left, wordWrap = false,
    position = { Left = {row.check, ui.edge.Right, 6, 0}, Right = {row.mark, ui.edge.Left, -6, 0} },
  }
  row._widget:SetScript("OnEnter", function() self:_select(row._index) end)
  -- Reset the shared tooltip's width cap on leave so it doesn't linger for other views.
  row._widget:SetScript("OnLeave", function() ui.tip:Hide(); ui.tip:MaxWidth(nil) end)
  row._widget:SetScript("OnMouseUp", function() self:_select(row._index) end)
  return row
end

function TitlesView:_updateRow(row, e, i)
  row._index = i
  if e.earned then
    row.check._widget:Show()
    row.name:Color(1, 1, 1)
    local rc = rarityCode(e.epithet)
    row.name:Text(rc and (rc .. e.name .. END) or e.name)
  else
    row.check._widget:Hide()
    row.name:Text(e.name)
    -- Unearnable titles read red; ordinary unearned (earnable or unknown) stay muted.
    row.name:Color(e.unearnable and RED or theme.colors.muted)
  end
  -- Right-column status tag, sharing one column: gold "Earnable" or red "Unearnable".
  if e.earnable then row.mark:Text(GOLD .. "Earnable" .. END)
  elseif e.unearnable then row.mark:Text(RED_CODE .. "Unearnable" .. END)
  else row.mark:Text("") end
  if i == self._sel then row.background:Color(theme.colors.hover) else row.background:Color(0, 0, 0, 0) end
  return ROW_H
end

function TitlesView:_renderPage()
  local list = self:_currentList()
  local n = #list
  self._sel = nil -- clear before SetItems so _updateRow paints every row unselected

  -- Size the viewport to the list (short lists shrink so MainWindow:Fit hugs them), then feed the
  -- rows in — SetItems recomputes the scroll range against the new viewport.
  local viewH = min(max(n * ROW_H, ROW_H), MAX_H)
  self.list:Height(viewH)
  self:Height(viewH)
  self.list:SetItems(list)

  self.emptyMsg[n == 0 and "Show" or "Hide"](self.emptyMsg)

  if n > 0 then self:_highlight(1) end
end

-- Move the selection highlight (and scroll it into view) without touching the tooltip.
function TitlesView:_highlight(idx)
  local list = self:_currentList()
  if #list == 0 then return end
  idx = idx < 1 and 1 or (idx > #list and #list or idx)
  if self._sel then
    local prev = self.list:Row(self._sel)
    if prev then prev.background:Color(0, 0, 0, 0) end
  end
  self._sel = idx
  local row = self.list:Row(idx)
  if row then row.background:Color(theme.colors.hover) end
  self.list:ScrollToItem(idx)
end
