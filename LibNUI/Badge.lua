---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture

local PAD_X, PAD_Y = 5, 2

-- An inline status pill: short coloured text on a subtle fill, auto-sized to the text —
-- for "[B]"-style markers and status tags beside a name. Optional hover tooltip (a
-- one-letter badge usually needs a legend). Anchor its Left next to the text it decorates.
---@class Badge: Frame
---@field text string            badge text (keep it short)
---@field color string|table     text colour token/rgba (default "header")
---@field fill string|table      pill fill colour token/rgba (default "backdrop")
---@field tooltip string|string[]?  hover legend line(s)
---@field label Label
---@field _fill Texture
local Badge = Class(Frame, function(self)
  self._fill = Texture:new{
    parent = self, layer = ui.layer.Background, color = self.fill,
    position = { All = true },
  }
  self.label = Label:new{
    parent = self, text = self.text, color = self.color,
    font = ui.fonts.GameFontHighlightSmall,
    position = { Center = {} },
  }
  self:_fit()

  if self.tooltip then
    local lines = type(self.tooltip) == "table" and self.tooltip or {self.tooltip}
    self._widget:EnableMouse(true)
    self._widget:SetScript("OnEnter", function()
      ui.tip:ClearLines()
      for _, l in ipairs(lines) do ui.tip:AddLine(l) end
      ui.tip:ClearAllPoints()
      ui.tip:SetPoint(ui.edge.BottomLeft, self._widget, ui.edge.TopRight, 2, 2)
      ui.tip:Show()
    end)
    self._widget:SetScript("OnLeave", function() ui.tip:Hide() end)
  end
end, {
  type  = "Frame",
  color = "header",
  fill  = "backdrop",
})
ui.Badge = Badge

-- Size the pill snugly around its text. An auto-sized FontString's Height() is its
-- rendered text height.
function Badge:_fit()
  local w = self.label:StringWidth() or 8
  local h = self.label:Height() or 10
  self:Size(w + PAD_X * 2, h + PAD_Y * 2)
end

-- Get/set the badge text (re-fits the pill when setting).
---@param v string?
---@return string|Badge
function Badge:Text(v)
  if v == nil then return self.label:Text() end
  self.label:Text(v)
  self:_fit()
  return self
end
