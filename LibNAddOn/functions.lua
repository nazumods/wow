local ADDON_NAME, ns = ...
local GetAddOnMetadata = C_AddOns.GetAddOnMetadata
ns._NAME = ADDON_NAME

function GetMetadata(self, variable)
  return GetAddOnMetadata(self._NAME, variable)
end

function Hook(self, funcName, func)
  local oldFunc = self[funcName]
  self[funcName] = function(...)
    if oldFunc then oldFunc(...) end
    return func(...)
  end
end

ns.linkCommonFunctions = function(addOn)
  addOn.GetMetadata = GetMetadata
  addOn.Print = function(...) print("|cFF33FF99" .. addOn._TITLE .. "|r:", ...) end
  addOn.hook = Hook
end

ns.linkCommonFunctions(ns)
ns._TITLE = ns:GetMetadata("Title") or ADDON_NAME
