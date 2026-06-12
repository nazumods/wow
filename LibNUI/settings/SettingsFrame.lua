---@type LibNUI_AddOn
local ns = select(2, ...)
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Label = ui.Frame, ui.Label
local Settings = Settings

local SettingsFrame = Class(Frame, function(self)
  self._heading = Label:new{
    parent = self,
    position = {
      TopLeft = {0, 0},
      TopRight = {0, 0},
      Height = 32,
    },
    text = self.headingText or self.heading.text or "Settings",
    fontObj = self.heading.fontObj or "GameFontNormalHuge",
    color = self.heading.color or NORMAL_FONT_COLOR,
    justifyH = ui.justify.Left,
  }
  self.controls = {}
end, {
  heading = {
    text = "Settings",
    fontObj = "GameFontNormalHuge",
    color = NORMAL_FONT_COLOR,
  }
})
ui.SettingsFrame = SettingsFrame

function SettingsFrame:AddControl(control)
  control:Parent(self)
  table.insert(self.controls, control)
  if #self.controls == 1 then
    control:TopLeft(self._heading, ui.edge.BottomLeft, 0, -5)
    control:TopRight(self._heading, ui.edge.BottomRight, 0, -5)
  else
    local lastControl = self.controls[#self.controls - 1]
    control:TopLeft(lastControl, ui.edge.BottomLeft, 0, -5)
    control:TopRight(lastControl, ui.edge.BottomRight, 0, -5)
  end
  return control
end

-- type = Button, template = UIDropDownListTemplate

function SettingsFrame:RegisterCategory(name)
  local category = Settings.RegisterCanvasLayoutCategory(
    self._widget,
    name or self.headingText or self.heading.text
  )
  Settings.RegisterAddOnCategory(category)
  return category
end

function SettingsFrame:RegisterSubcategory(parentCategory, name)
  local category = Settings.RegisterCanvasLayoutSubcategory(
    parentCategory,
    self._widget,
    name or self.headingText or self.heading.text
  )
  Settings.RegisterAddOnCategory(category)
  return category
end
