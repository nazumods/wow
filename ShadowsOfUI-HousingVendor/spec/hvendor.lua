-- Loads ShadowsOfUI-HousingVendor/decor.lua against a scriptable fake WoW
-- environment so the pure count/bonus normalizer and the class-gate + cache
-- behaviour can be unit-tested. Tests mutate the returned `state` table to script
-- API responses. Path is relative to the AddOns root, where busted runs.
local M = {}

---@return table ns, table state
function M.load()
  -- Distinct sentinel class ids; the real Enum values are opaque, we only need
  -- decor.lua's equality checks to line up with what the fake item info reports.
  _G.Enum = {
    ItemClass = { Recipe = 1, Housing = 3, Consumable = 4 },
    ItemHousingSubclass = { Decor = 30 },
  }

  local state = {
    itemInfo = {}, -- [itemID] = { classID=, subClassID= }
    entries = {},  -- [itemID] = HousingCatalogEntryInfo table (nil = catalog can't resolve it yet)
  }

  local function idOf(key)
    if type(key) == "number" then return key end
    return tonumber(tostring(key):match("item:(%d+)"))
  end

  _G.C_Item = {
    -- returns: itemID, _, _, _, _, classID, subClassID
    GetItemInfoInstant = function(key)
      local id = idOf(key)
      local info = id and state.itemInfo[id]
      if not info then return id end
      return id, nil, nil, nil, nil, info.classID, info.subClassID
    end,
  }

  _G.C_HousingCatalog = {
    GetCatalogEntryInfoByItem = function(link)
      return state.entries[idOf(link)]
    end,
  }

  _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

  local ns = {}
  assert(loadfile("ShadowsOfUI-HousingVendor/decor.lua"))("ShadowsOfUI-HousingVendor", ns)
  return ns, state
end

return M
