---@class LibNAddOn
local ns = select(2, ...)
-- luacheck: globals MinimalSliderWithSteppersMixin
local Settings = Settings

---@class Setting
local Setting = {}

---@class Setting
---@field checkbox fun(db: table, category: table, data: table) create a checkbox setting
function Setting.checkbox(db, category, data)
  local setting = Settings.RegisterAddOnSetting(
    category, data.name, data.key, data.table(db), type(data.default), data.label, data.default
  )
  setting:SetValueChangedCallback(data.callback)
  Settings.CreateCheckbox(category, setting, data.tooltip)
end

---@class Setting
---@field slider fun(db: table, category: table, data: table) create a slider setting
function Setting.slider(db, category, data)
  local setting = Settings.RegisterAddOnSetting(
    category, data.name, data.key, data.table(db), type(data.default), data.label, data.default
  )
  setting:SetValueChangedCallback(data.callback)
  local options = Settings.CreateSliderOptions(data.min, data.max, data.step)
  options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  Settings.CreateSlider(category, setting, options, data.tooltip)
end

---@class Setting
---@field dropdown fun(db: table, category: table, data: table) create a dropdown setting
function Setting.dropdown(db, category, data)
  local setting = Settings.RegisterAddOnSetting(
    category, data.name, data.key, data.table(db), type(data.default), data.label, data.default
  )
  setting:SetValueChangedCallback(data.callback)
  Settings.CreateDropdown(
    category, setting,
    function()
      local container = Settings.CreateControlTextContainer()
      for i,option in ipairs(data.options) do
        container:Add(i, option)
      end
      return container:GetData()
    end,
    data.tooltip
  )
end

---@class LibNAddOn
---@field registerSettings fun(addOn: AddOn, addOnName: string, features: table) register settings for an add-on
function ns.registerSettings(addOn, addOnName, features)
  addOn:registerEvent("ADDON_LOADED", function(self, name)
    if name ~= addOnName then return end
    local db = addOn.db
    local cb = function(setting, value)
      if addOn.settingChanged then
        addOn:settingChanged(setting.variableKey, value, setting:GetVariable(), setting)
      end
    end
    for _,cat in ipairs(features) do
      local category = Settings.RegisterVerticalLayoutCategory(cat.title)

      for _,data in ipairs(cat.fields) do
        if not data.callback then data.callback = cb end
        Setting[data.typ](db, category, data)
      end

      Settings.RegisterAddOnCategory(category)
      addOn.settingsCategory = category
    end
  end, 2) -- run after db, but before addOn.onLoad
end
