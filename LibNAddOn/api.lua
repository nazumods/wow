local _, ns = ...
-- luacheck: globals LibNAddOn

local G = _G

function ns.Print(...) print("|cFF33FF99LibNAddOn|r:", ...) end

-- C_AddOns.GetAddOnMetadata(name, variable)
---@return table AddOn object
function LibNAddOn(features, o)
  if type(features) == "string" then
    features = {
      name = features,
      addOn = o,
    }
  end
  if not features.name then ns.Print("missing field name"); return {} end
  if not features.addOn then ns.Print("missing field addOn"); return {} end
  local addOn = features.addOn
  local addOnName = features.name
  addOn._NAME = addOnName

  ns.linkCommonFunctions(addOn)

  addOn._TITLE = addOn:GetMetadata("Title") or addOnName

  ns.linkGlobals(addOn, features)

  ns.createEventListener(addOn, addOnName)

  local dbName = addOn:GetMetadata("X-NUI-DB")
  if not features.db and dbName then
    features.db = {
      name = dbName,
      version = addOn:GetMetadata("X-NUI-DB-VERSION"),
    }
  end
  if features.db then
    if not features.db.name then ns.Print("missing field db.name"); return {} end
    ns.setupDB(addOnName, addOn, features.db)

    if features.settings then
      ns.registerSettings(addOn, addOnName, features.settings)
    end
  end

  ns.registerSlashCommands(addOn, features.slashCommands)

  local compartmentFn = features.compartmentFn or addOn:GetMetadata("X-NUI-COMPARTMENT")
  if compartmentFn then
    G[compartmentFn] = function(name, buttonName)
      if name ~= addOnName then return end
      -- buttonName = LeftButton | RightButton | MiddleButton
      addOn:CompartmentClick(buttonName)
    end
  end

  return addOn
end
