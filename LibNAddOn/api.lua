---@class LibNAddOn
local ns = select(2, ...)
local G = _G

---@class AddOn
---@field CompartmentClick fun(self: AddOn, buttonName: string)?

-- luacheck: globals LibNAddOn
---@param features {name: string, addOn: AddOn, [any]: any}|string
---@param o AddOn|nil
---@return AddOn addon
function LibNAddOn(features, o)
  if type(features) == "string" then
    -- called with [name, addOn]
    if not o then ns:Print("missing addOn"); return {} end
    features = {
      name = features,
      addOn = o,
    }
  end
  if not features.name then ns.Print("missing field name"); return {} end
  if not features.addOn then ns.Print("missing field addOn"); return {} end
  local addOn = features.addOn
  local addOnName = features.name

  ns.linkCommonFunctions(addOn, addOnName)

  ns.linkGlobals(addOn, features)

  ns.createEventListener(addOn)

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
