---@type ShadowsOfUI_Castbar
local ns = select(2, ...)
local ui = ns.ui
local TitleFrame, Slider, CheckButton = ui.TitleFrame, ui.Slider, ui.CheckButton
local Label, Frame = ui.Label, ui.Frame

-- Per-bar config popup — our stand-in for Blizzard's EditModeSystemSettingsDialog. A single
-- shared window re-attaches itself next to whichever bar was clicked in Edit Mode and exposes
-- that bar's settings: its enable toggle, the (shared) text size, and a reset-position button.

local TEXT_MIN, TEXT_MAX = 8, 22

-- Lazily build the shared popup the first time a bar is clicked.
---@return TitleFrame
function ns:_buildConfig()
  if self._config then return self._config end

  local win = TitleFrame:new{ strata = "DIALOG", title = "Cast Bar" }
  win:Size(232, 150)

  win._enable = CheckButton:new{
    parent = win, text = "Show this cast bar",
    position = { TopLeft = {win, ui.edge.TopLeft, 6, -34}, Width = 26, Height = 26 },
    OnToggle = function(_, checked)
      local bar = win._bar
      ns.db[bar.unit .. "Enabled"] = checked
      ns:SetBarEnabled(bar.unit, checked)
    end,
  }

  win._slider = Slider:new{
    parent = win, min = TEXT_MIN, max = TEXT_MAX, step = 1,
    label = "Text size",
    valueFormat = function(v) return math.floor(v + 0.5) .. "px" end,
    position = { TopLeft = {win, ui.edge.TopLeft, 14, -96}, TopRight = {win, ui.edge.TopRight, -14, -96}, Height = 16 },
    OnChange = function(_, value, userInput)
      if userInput then
        value = math.floor(value + 0.5)
        ns.db.textSize = value
        ns:ApplyTextSize(value)
      end
    end,
  }

  win._reset = Frame:new{ type = "Button", parent = win, background = {1, 1, 1, 0.08},
    position = { BottomLeft = {win, ui.edge.BottomLeft, 10, 10}, BottomRight = {win, ui.edge.BottomRight, -10, 10}, Height = 22 } }
  Label:new{ parent = win._reset, text = "Reset position", layer = ui.layer.Overlay, justifyH = ui.justify.Center,
    position = { Center = {win._reset, ui.edge.Center} } }
  win._reset:SetScript("OnClick", function()
    local d = ns.DEFAULT_POS[win._bar.unit]
    win._bar:ResetPosition(d.x, d.y)
    ns:AttachConfig(win._bar)
  end)
  win._reset:SetScript("OnEnter", function() win._reset.background:Color(1, 1, 1, 0.16) end)
  win._reset:SetScript("OnLeave", function() win._reset.background:Color(1, 1, 1, 0.08) end)

  win:Hide()
  self._config = win
  return win
end

-- Open (or re-point) the popup for a clicked bar, marking it selected.
---@param bar CastBar
function ns:OpenConfig(bar)
  local win = self:_buildConfig()
  win._bar = bar
  win:Title(bar._label)
  win._enable:Checked(self.db[bar.unit .. "Enabled"])
  win._slider:Value(self.db.textSize) -- fires OnChange (userInput=false) → syncs the value label
  for _, b in pairs(self.bars) do b:SetSelected(b == bar) end
  self:AttachConfig(bar)
  win:Show()
end

-- Anchor the popup just below a bar (it then follows the bar live while it's dragged).
---@param bar CastBar
function ns:AttachConfig(bar)
  local win = self._config
  if not win then return end
  win:ClearAllPoints()
  win._widget:SetPoint("TOPLEFT", bar._widget, "BOTTOMLEFT", 0, -6)
end

-- Close the popup and clear every bar's selection (Edit Mode exit).
function ns:CloseConfig()
  if self._config then self._config:Hide() end
  if self.bars then
    for _, bar in pairs(self.bars) do bar:SetSelected(false) end
  end
end
