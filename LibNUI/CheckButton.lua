local _, ns = ...
local ui = ns.ui
local Class = ns.lua.Class
local Button = ui.Button

local CheckButton = Class(Button, function(self)
  self._widget.Text:SetText(self.text or "")
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
    local checked = self:Checked()
    self:OnToggle(checked)
    self:Checked(not checked)
  end
end

function CheckButton:Checked(isChecked)
  if isChecked ~= nil then
    self._widget:SetChecked(isChecked)
  end
  return self._widget:GetChecked()
end
