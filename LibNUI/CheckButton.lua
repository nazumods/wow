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
  -- exactly once.
  self._widget:RegisterForClicks("LeftButtonUp")
  -- OnToggle must fire from a real OnClick script: the widget auto-toggles
  -- during click processing, AFTER the OnMouseUp script that drives the Button
  -- class OnClick hook — reading GetChecked() there returns the PRE-toggle
  -- state, inverting every consumer's stored value.
  self._widget:SetScript("OnClick", function()
    if self.OnToggle then self:OnToggle(self:Checked()) end
  end)
end, {
  type = "CheckButton",
  template = "ChatConfigCheckButtonTemplate", --"UICheckButtonTemplate",
  position = {
    Width = 32,
    Height = 32,
  },
})
ui.CheckButton = CheckButton

function CheckButton:Checked(isChecked)
  if isChecked ~= nil then
    self._widget:SetChecked(isChecked)
  end
  return self._widget:GetChecked()
end
