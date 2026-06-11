---@type LibNUI_AddOn
local ns = select(2, ...)
local ui = ns.ui
local Class = ns.lua.Class
local Button = ui.Button

local CheckButton = Class(Button, function(self)
  self._widget.Text:SetText(self.text or "")
  self._widget:SetHitRectInsets(0, 0, 0, 0)
  -- Button registers "AnyDown"+"AnyUp", which fires the template's auto-toggle
  -- twice per click (cancelling out). Restrict to up-only so the template toggles
  -- exactly once and OnClick can simply read the resulting state.
  self._widget:RegisterForClicks("LeftButtonUp")
end, {
  type = "CheckButton",
  template = "ChatConfigCheckButtonTemplate", --"UICheckButtonTemplate",
  position = {
    Width = 32,
    Height = 32,
  },
})
ui.CheckButton = CheckButton

function CheckButton:OnClick()
  if self.OnToggle then
    self:OnToggle(self:Checked())
  end
end

function CheckButton:Checked(isChecked)
  if isChecked ~= nil then
    self._widget:SetChecked(isChecked)
  end
  return self._widget:GetChecked()
end
