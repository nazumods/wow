local _, ns = ...
local G = _G

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
