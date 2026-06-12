---@type LibNUI_AddOn
local ns = select(2, ...)
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Label, EditBox = ui.Frame, ui.Label, ui.EditBox

---@class TextSetting: Frame
---@field label string?  setting label text
---@field editor table  editor options: { fontObj, width, height, text? }
---@field table table?  settings table the value is read from / written to
---@field field string?  key in `table` holding the value
---@field SettingChanged fun(self: TextSetting, text: string)  override to handle changes
---@field _label Label  setting label (internal)
---@field _editor EditBox  text editor (internal)
local TextSetting = Class(Frame, function(self)
  self._label = Label:new{
    parent = self,
    position = {
      TopLeft = {0, 0},
      Width = 100,
    },
    text = self.label,
    justifyH = ui.justify.Right,
  }

  self._editor = EditBox:new{
    parent = self,
    position = {
      TopLeft = {self._label, ui.edge.TopRight, 10, 0},
      Width = self.editor.width,
      Height = self.editor.height,
    },
    fontObj = self.editor.fontObj,
    autoFocus = false,
    text = self.editor.text or self.table and self.table[self.field] or "",
    cursorPosition = 0,
    OnEditFocusLost = function()
      if self.table and self.field then
        self.table[self.field] = self._editor:Text()
      end
      if self.SettingChanged then
        self:SettingChanged(self._editor:Text())
      end
    end,
  }
  self:Height(self._editor:Height())
end, {
  editor = {
    fontObj = "GameFontNormal",
    width = 100,
    height = 12,
  },
  SettingChanged = function(self, text)
    -- Override this method to handle setting changes
    ns.Print("Setting changed to:", text)
  end,
})
ui.TextSetting = TextSetting

-- Convenience: build a TextSetting bound to table[field] and add it.
---@param label string  setting label text
---@param table table  settings table the value is stored in
---@param field string  key in `table` holding the value
---@return Frame  the added TextSetting
function ui.SettingsFrame:AddTextControl(label, table, field)
  return self:AddControl(TextSetting:new{
    label = label,
    table = table,
    field = field,
  })
end
