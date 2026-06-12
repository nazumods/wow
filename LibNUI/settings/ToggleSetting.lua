---@type LibNUI_AddOn
local ns = select(2, ...)
local ui = ns.ui
local Class = ns.lua.Class
local Frame, CheckButton = ui.Frame, ui.CheckButton

---@class ToggleSetting: Frame
---@field label string?  setting label text (shown next to the checkbox)
---@field table table?  settings table the value is read from / written to
---@field field string?  key in `table` holding the value
---@field SettingChanged fun(self: ToggleSetting, state: boolean)  override to handle changes
---@field _toggle CheckButton  checkbox (internal)
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

-- Convenience: build a ToggleSetting bound to table[field] and add it.
---@param label string  setting label text
---@param table table  settings table the value is stored in
---@param field string  key in `table` holding the value
---@return Frame  the added ToggleSetting
function ui.SettingsFrame:AddToggleControl(label, table, field)
  return self:AddControl(ToggleSetting:new{
    label = label,
    table = table,
    field = field,
  })
end
