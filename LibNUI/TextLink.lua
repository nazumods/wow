---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Label = ui.Frame, ui.Label

-- A text-only hyperlink: an accent-coloured clickable label that brightens to plain text
-- colour on hover and fires onClick. Auto-sizes to its text. For "About"-panel links,
-- inline actions beside a heading, and anywhere a full Button is too heavy.
---@class TextLink: Frame
---@field text string      link text
---@field color string|table  resting colour token/rgba (default "header")
---@field hoverColor string|table  hover colour token/rgba (default "text")
---@field onClick fun(self: TextLink)?  click handler
---@field label Label
local TextLink = Class(Frame, function(self)
  self.label = Label:new{
    parent   = self,
    text     = self.text,
    color    = self.color,
    position = { Left = {self, 0, 0} },
  }
  self:Size((self.label:StringWidth() or 20) + 2, self.label:Height() or 12)

  self._widget:SetScript("OnClick", function() if self.onClick then self:onClick() end end)
  self._widget:SetScript("OnEnter", function() self.label:Color(self.hoverColor) end)
  self._widget:SetScript("OnLeave", function() self.label:Color(self.color) end)
end, {
  type       = "Button",
  color      = "header",
  hoverColor = "text",
})
ui.TextLink = TextLink

-- Get/set the link text (re-fits the width when setting).
---@param v string?
---@return string|TextLink
function TextLink:Text(v)
  if v == nil then return self.label:Text() end
  self.label:Text(v)
  self:Size((self.label:StringWidth() or 20) + 2, self.label:Height() or 12)
  return self
end
