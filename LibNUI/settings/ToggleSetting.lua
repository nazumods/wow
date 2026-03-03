local _, ns = ...
local ui = ns.ui
local Class = ns.lua.Class
local Frame, CheckButton, Label = ui.Frame, ui.CheckButton, ui.Label

local ToggleSetting = Class(Frame, function(self)
  self._toggle = CheckButton:new{
    parent = self,
    position = {
      TopLeft = {75, 0},
    },
    text = self.label,
    OnToggle = function(_, checked)
      if self.table and self.field then
        self.table[self.field] = checked
      end
      if self.SettingChanged then
        self:SettingChanged(checked)
      end
    end,
  }
  if self.table and self.field then
    self._toggle:Checked(self.table[self.field])
  end
  self:Height(self._toggle:Height())
end, {
  SettingChanged = function(self, state)
    -- Override this method to handle setting changes
    ns.Print("Setting changed to:", state)
  end,
})
ui.ToggleSetting = ToggleSetting

function ui.SettingsFrame:AddToggleControl(label, table, field)
  return self:AddControl(ToggleSetting:new{
    label = label,
    table = table,
    field = field,
  })
end
