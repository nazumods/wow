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

  -- `ns.api` is the shared X-NUI-API table LibNAddOn seeds in-game (HousingDecorApi);
  -- provide an empty one so decor.lua's exposure of `EntryFor` runs and is testable.
  local ns = { api = {} }
  assert(loadfile("ShadowsOfUI-HousingVendor/decor.lua"))("ShadowsOfUI-HousingVendor", ns)
  return ns, state
end

---Load the REAL overlay.lua + surfaces.lua against a fake merchant frame, so the Buy/Buyback
---overlay cleanup can be driven out of game. Frames/regions are recording fakes (`shown`, `text`);
---`hooksecurefunc` stores the hooks so a test can fire Blizzard's repaint functions by name.
---`state.links[index]` is what GetMerchantItemLink returns, `state.decor[link]` what the stubbed
---ns.DecorEntryFor resolves; `state.db` is the addon's setting table.
---@return table w  { ns, state, buttons, hooks, refreshers }
function M.loadSurfaces()
  local PER_PAGE = 3
  _G.MERCHANT_ITEMS_PER_PAGE = PER_PAGE
  _G.WarbandeerHousingDecorApi = nil

  local function region()
    local r = { shown = true }
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetText(t) self.text = t end
    local noop = function() end
    for _, m in ipairs({ "SetFont", "SetPoint", "SetAtlas", "SetSize", "SetTexture", "SetTextColor", "SetAllPoints", "SetFrameLevel" }) do
      r[m] = noop
    end
    return r
  end
  _G.CreateFrame = function()
    local f = region()
    function f:CreateFontString() return region() end
    function f:CreateTexture() return region() end
    return f
  end

  local buttons = {}
  for i = 1, PER_PAGE do
    local b = region()
    b.GetFrameLevel = function() return 1 end
    buttons[i] = b
    _G["MerchantItem" .. i .. "ItemButton"] = b
  end

  local state = { links = {}, decor = {}, db = { countBadge = true, ownedCheck = true, bonusBadge = true } }
  _G.MerchantFrame = {
    page = 1, selectedTab = 1, shown = true,
    IsShown = function(self) return self.shown end,
  }
  _G.GetMerchantItemLink = function(index) return state.links[index] end

  local hooks, refreshers = {}, {}
  _G.hooksecurefunc = function(name, fn) hooks[name] = fn end
  local ns = {
    DecorEntryFor = function(link) return state.decor[link] end,
    AddRefresher = function(fn) refreshers[#refreshers + 1] = fn end,
  }
  ns.db = state.db
  assert(loadfile("ShadowsOfUI-HousingVendor/overlay.lua"))("ShadowsOfUI-HousingVendor", ns)
  assert(loadfile("ShadowsOfUI-HousingVendor/surfaces.lua"))("ShadowsOfUI-HousingVendor", ns)
  return { ns = ns, state = state, buttons = buttons, hooks = hooks, refreshers = refreshers }
end

return M
