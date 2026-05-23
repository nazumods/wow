---@class LibNAddOn: AddOn
local ns = select(2, ...)
local GetAddOnMetadata = C_AddOns.GetAddOnMetadata

---Get meta data value from the .toc metadata
---@param self AddOn addon
---@param variable string metadata key
---@return string? metadata value, or nil if not found
local function GetMetadata(self, variable)
  return GetAddOnMetadata(self._NAME, variable)
end

---Hook a function to run another after
---@param self AddOn addon
---@param funcName string function name to hook
---@param func fun(...) function to run after the original function
local function Hook(self, funcName, func)
  local oldFunc = self[funcName]
  self[funcName] = function(...)
    if oldFunc then oldFunc(...) end
    return func(...)
  end
end

---@class AddOn
---@field GetMetadata fun(self: AddOn, variable: string): string|nil
---@field Print fun(...: any)
---@field hook fun(self: AddOn, funcName: string, func: function)
---@field _NAME string name
---@field _TITLE string title

---@class LibNAddOn
---@field linkCommonFunctions fun(addOn: AddOn, addOnName: string) link common functions to an add-on
ns.linkCommonFunctions = function(addOn, addOnName)
  addOn.GetMetadata = GetMetadata
  addOn.Print = function(self, ...)
    local prefix = ""
    if self ~= addOn then
      prefix = " " .. self
      self = addOn
    end
    prefix = "|cFF33FF99" .. self._TITLE .. "|r:" .. prefix
    print(prefix, ...)
  end
  addOn.hook = Hook
  addOn._NAME = addOnName
  addOn._TITLE = addOn:GetMetadata("Title") or addOnName
end
ns.linkCommonFunctions(ns, select(1, ...))
