---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture

-- A small bordered "KPI" box: a big centred value on top, a small muted subtitle at the
-- bottom, and a 1px border whose colour can express state (locked/unlocked/current).
-- Lay several in a row for vault-slot / summary strips. Optional hover tooltip lines
-- (shown via the shared ui.tip). Border = FilterDropdown's bordered idiom (an outer
-- border-colour texture with the fill inset 1px).
---@class StatTile: Frame
---@field value string|number?    big top text
---@field subtitle string?        small bottom text
---@field valueColor string|table  value colour token/rgba (default "text")
---@field subtitleColor string|table  subtitle colour token/rgba (default "muted")
---@field borderColor string|table  1px border colour token/rgba (default "divider")
---@field fill string|table       inner fill colour token/rgba (default "backdrop")
---@field valueFont string        font object (name) for the big value (default "GameFontHighlightLarge")
---@field width number            tile width (default 64) — intrinsic size, survives any `position`
---@field height number           tile height (default 40)
---@field tooltip string|string[]?  hover tooltip line(s)
---@field valueLabel Label
---@field subtitleLabel Label
---@field _border Texture
---@field _fill Texture
local StatTile = Class(Frame, function(self)
  -- intrinsic size (not a `position` default: a caller's position table would replace it)
  self:Size(self.width, self.height)
  self._border = Texture:new{
    parent = self, layer = ui.layer.Background, color = self.borderColor,
    position = { All = true },
  }
  self._fill = Texture:new{
    parent = self, layer = ui.layer.Border, color = self.fill,
    position = { TopLeft = {1, -1}, BottomRight = {-1, 1} },
  }

  self.valueLabel = Label:new{
    parent = self, text = self.value, color = self.valueColor,
    fontObj = self.valueFont,
    position = { Top = {self, ui.edge.Top, 0, -5} },
  }
  self.subtitleLabel = Label:new{
    parent = self, text = self.subtitle, color = self.subtitleColor,
    font = ui.fonts.GameFontHighlightSmall,
    position = { Bottom = {self, ui.edge.Bottom, 0, 4} },
  }

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
  type          = "Frame",
  valueColor    = "text",
  subtitleColor = "muted",
  borderColor   = "divider",
  fill          = "backdrop",
  valueFont     = "GameFontHighlightLarge",
  width         = 64,
  height        = 40,
})
ui.StatTile = StatTile

-- Get/set the big value text.
---@param v string|number?
---@return string|StatTile
function StatTile:Value(v)
  if v == nil then return self.valueLabel:Text() end
  self.valueLabel:Text(v)
  return self
end

-- Get/set the subtitle text.
---@param v string?
---@return string|StatTile
function StatTile:Subtitle(v)
  if v == nil then return self.subtitleLabel:Text() end
  self.subtitleLabel:Text(v)
  return self
end

-- Restyle the state colours in one call; nil fields leave that colour unchanged.
---@param colors { value: string|table?, subtitle: string|table?, border: string|table?, fill: string|table? }
---@return StatTile
function StatTile:Colors(colors)
  if colors.value then self.valueLabel:Color(colors.value) end
  if colors.subtitle then self.subtitleLabel:Color(colors.subtitle) end
  if colors.border then self._border:Color(colors.border) end
  if colors.fill then self._fill:Color(colors.fill) end
  return self
end
