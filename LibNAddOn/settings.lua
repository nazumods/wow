---@class LibNAddOn
local ns = select(2, ...)
local Settings = Settings

---@class Setting
local Setting = {}

-- Register the backing setting shared by every control type. The Settings registry
-- keys each setting by a GLOBALLY-unique `variable` string; passing a human label
-- (e.g. "Auctions", "Bank") risks colliding with another addon's — or Blizzard's —
-- registered variable, so we namespace it per-addon. The saved value lives in
-- variableTbl[variableKey], so the variable is only an id: renaming it does not
-- touch saved data. A nil variableTbl makes Settings throw a cryptic batch of
-- errors during registration, so skip with a clear message if the caller's `table`
-- closure doesn't yield one.
---@param db table
---@param category table
---@param data table
---@param addOnName string
---@return table? setting nil when the backing table is missing (caller then skips the control)
local function register(db, category, data, addOnName)
  local variable = addOnName .. "." .. (data.key or data.name)
  local tbl = data.table(db)
  if type(tbl) ~= "table" then
    ns:Print(("settings: %q (%s) has no backing table; skipping"):format(variable, addOnName))
    return nil
  end
  local setting = Settings.RegisterAddOnSetting(
    category, variable, data.key, tbl, type(data.default), data.label, data.default
  )
  setting:SetValueChangedCallback(data.callback)
  return setting
end

---@class Setting
---@field checkbox fun(db: table, category: table, data: table, addOnName: string) create a checkbox setting
function Setting.checkbox(db, category, data, addOnName)
  local setting = register(db, category, data, addOnName)
  if setting then Settings.CreateCheckbox(category, setting, data.tooltip) end
end

---@class Setting
---@field slider fun(db: table, category: table, data: table, addOnName: string) create a slider setting
function Setting.slider(db, category, data, addOnName)
  local setting = register(db, category, data, addOnName)
  if not setting then return end
  local options = Settings.CreateSliderOptions(data.min, data.max, data.step)
  options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  Settings.CreateSlider(category, setting, options, data.tooltip)
end

---@class Setting
---@field dropdown fun(db: table, category: table, data: table, addOnName: string) create a dropdown setting
function Setting.dropdown(db, category, data, addOnName)
  local setting = register(db, category, data, addOnName)
  if not setting then return end
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

---@class AddOn
---@field settingsCategory table?

-- Top-level categories keyed by display name. LibNAddOn loads once, so this table
-- is shared across every addon: any addon referencing the same name converges on
-- one Settings-panel group, created+registered the first time. A group may be an
-- empty parent (only subcategories nest under it, e.g. "Shadows of UI") or carry
-- its own settings (e.g. "Warbandeer", under which Warbandeer_Alias nests) —
-- whichever addon touches the name first creates it, the rest reuse it.
local parents = {}
local function getParent(name)
  if not parents[name] then
    local category = Settings.RegisterVerticalLayoutCategory(name)
    Settings.RegisterAddOnCategory(category)
    parents[name] = category
  end
  return parents[name]
end

---@class LibNAddOn
---@field getSettingsParent fun(name: string): table get-or-create a shared parent Settings category
ns.getSettingsParent = getParent

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
      -- A `parent` name nests this as a subcategory under that shared group.
      -- Otherwise it's a top-level group routed through getParent, so its own name
      -- is reusable as a parent (e.g. Warbandeer_Alias nests under "Warbandeer").
      local category = cat.parent
        and Settings.RegisterVerticalLayoutSubcategory(getParent(cat.parent), cat.title)
        or getParent(cat.title)

      for _,data in ipairs(cat.fields) do
        if not data.callback then data.callback = cb end
        Setting[data.typ](db, category, data, addOnName)
      end

      if not addOn.settingsCategories then addOn.settingsCategories = {} end
      table.insert(addOn.settingsCategories, category)
      addOn.settingsCategory = addOn.settingsCategories[1]
    end
  end, 2) -- run after db, but before addOn.onLoad
end
