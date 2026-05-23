---@class LibNAddOn
local ns = select(2, ...)
local G = _G

---@class AddOn
---@field lua Lua Lua utility functions
---@field wow table WoW API functions
---@field icons table icon utility functions
---@field Colors Colors color utility functions
---@field api table? API table for add-on to expose functions to other add-ons
---@field ui table? UI utility functions

---@class LibNAddOn
---@field linkGlobals fun(addOn: AddOn, features: table) link global variables to addOn
function ns.linkGlobals(addOn, features)
  addOn[features.lua or "lua"] = ns.lua
  addOn[features.wow or "wow"] = ns.wow

  addOn[features.icons or "icons"] = ns.icons
  addOn[features.colors or "Colors"] = ns.Colors

  local apiName = features.api or addOn:GetMetadata("X-NUI-API")
  if apiName then
    if not G[apiName] then
      G[apiName] = {}
    end
    addOn.api = G[apiName]
  end

  local uiName = features.ui or addOn:GetMetadata("X-NUI-UI")
  if uiName then
    addOn.ui = G[uiName]
  end
end
