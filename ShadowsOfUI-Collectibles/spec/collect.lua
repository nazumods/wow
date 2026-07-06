-- Loads ShadowsOfUI-Collectibles/detect.lua against a scriptable fake WoW
-- environment so the tooltip-load negative-cache gating (IsKnown / IsCollectible)
-- can be unit-tested — the real bug is a tooltip load-window race that can't be
-- reproduced in-game. Tests mutate the returned `state` table to script API
-- responses. Path is relative to the AddOns root, where busted runs.
local M = {}

local unpack = table.unpack or unpack

-- Minimal strsplit for the SpecialItems path (splits on a literal separator).
local function strsplit(sep, s)
  local out, pos = {}, 1
  while true do
    local i = s:find(sep, pos, true)
    if not i then out[#out + 1] = s:sub(pos); break end
    out[#out + 1] = s:sub(pos, i - 1); pos = i + #sep
  end
  return unpack(out)
end

---@return table ns, table state
function M.load()
  -- Distinct sentinel class ids; the real Enum values are opaque, we only need
  -- detect.lua's equality checks to line up with what the fake item info reports.
  _G.Enum = {
    ItemClass = { Recipe = 1, Miscellaneous = 2, Housing = 3, Consumable = 4 },
    ItemMiscellaneousSubclass = { CompanionPet = 20 },
    ItemHousingSubclass = { Decor = 30 },
    HousingCatalogEntrySubtype = { OwnedUnmodifiedStack = 1, OwnedModifiedStack = 2 },
  }

  local state = {
    itemInfo = {},       -- [itemID] = { name=, classID=, subClassID=, icon=, srcLink= }
    tooltip = {},        -- [link]  = { "line1", ... }   (nil = tooltip not loaded yet)
    toys = {},           -- [itemID] = true
    mounts = {},         -- [itemID] = mountID
    collectedMounts = {},-- [mountID] = true
    questDone = {},      -- [questID] = true
  }

  local function idOf(key)
    if type(key) == "number" then return key end
    return tonumber(tostring(key):match("item:(%d+)"))
  end

  _G.C_Item = {
    -- returns: itemID, _, _, _, icon, classID, subClassID
    GetItemInfoInstant = function(key)
      local id = idOf(key)
      local info = id and state.itemInfo[id]
      if not info then return id end
      return id, nil, nil, nil, info.icon, info.classID, info.subClassID
    end,
    -- returns: name, link(srcLink)
    GetItemInfo = function(key)
      local id = idOf(key)
      local info = id and state.itemInfo[id]
      if not info or not info.name then return nil end
      return info.name, info.srcLink
    end,
  }

  _G.C_TooltipInfo = {
    GetHyperlink = function(link)
      local t = state.tooltip[link]
      if not t then return nil end
      local lines = {}
      for _, txt in ipairs(t) do lines[#lines + 1] = { leftText = txt } end
      return { lines = lines }
    end,
  }

  _G.C_MountJournal = {
    GetMountFromItem = function(itemID) return state.mounts[itemID] end,
    GetMountInfoByID = function(mountID)
      return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, state.collectedMounts[mountID] or false
    end,
  }

  _G.C_PetJournal = {
    GetNumCollectedInfo = function() return 0 end,
    GetNumPets = function() return 0 end,
    GetPetInfoByIndex = function() end,
  }

  _G.C_ToyBox = { GetToyInfo = function(itemID) return state.toys[itemID] and "toy" or nil end }
  _G.PlayerHasToy = function(itemID) return state.toys[itemID] and true or false end
  _G.C_QuestLog = { IsQuestFlaggedCompleted = function(q) return state.questDone[q] or false end }
  _G.C_HousingCatalog = nil
  _G.strsplit = strsplit
  _G.ITEM_SPELL_KNOWN = "Already known."
  _G.ITEM_PET_KNOWN = nil
  _G.HOUSING_DECOR_OWNED_COUNT_FORMAT = nil

  local ns = {
    registerEvent = function() end,
    Refresh = function() end,
    QuestItems = {},
    SpecialItems = {},
    ContainerItems = {},
  }
  assert(loadfile("ShadowsOfUI-Collectibles/detect.lua"))("ShadowsOfUI-Collectibles", ns)
  return ns, state
end

return M
