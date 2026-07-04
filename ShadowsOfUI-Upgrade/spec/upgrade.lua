-- Loads ShadowsOfUI-Upgrade's pure logic (data + resolve + equip + upgrade) into
-- a fresh ns with stubbed WoW globals and a fake WarbandeerApi.  Mirrors
-- LibNAddOn/spec/libn.lua: specs call h = up.harness() per test for an isolated
-- world, then populate h.items / h.addChar / h.pools / h.warband and drive the
-- published api in h.Api.  Paths are relative to the AddOns root (busted's cwd).
--
-- core.lua and tooltip.lua are NOT loaded — core.lua bootstraps via LibNAddOn
-- (needs the real addon environment) and tooltip.lua only touches frames.  The
-- logic under test (resolve/equip/upgrade) is reachable without either: the
-- harness seeds the few ns fields core.lua would (ns.api, ns.wow, ns.UpgradeApi).

local up = {}

-- Files in toc order, minus core.lua (bootstrap), tooltip.lua (frames), and
-- data/vendorgear.lua (its real item links don't resolve against the stub item table —
-- the harness substitutes the synthetic h.vendor list instead; see h.ns.VendorGear below).
-- Data must precede resolve/equip/upgrade (they read ns.StatPriority etc.).
local FILES = {
  "data/statpriority.lua",
  "data/primarystat.lua",
  "data/classgear.lua",
  "data/enchantslots.lua",
  "data/enchants.lua",
  "data/gems.lua",
  "resolve.lua",
  "equip.lua",
  "evaluate.lua",
  "upgrade.lua",
  "upgradesources.lua",
  "classcodex.lua",
  "enchants.lua",
  "gems.lua",
}

-- Armour type per class (the real ns.wow.Armor.byClass the addon reads in-game).
local ARMOR_BY_CLASS = {
  Warrior = "Plate", Paladin = "Plate", DeathKnight = "Plate",
  Hunter = "Mail", Shaman = "Mail", Evoker = "Mail",
  Rogue = "Leather", Druid = "Leather", Monk = "Leather", DemonHunter = "Leather",
  Mage = "Cloth", Priest = "Cloth", Warlock = "Cloth",
}

-- classID → { token, specs = {specID by GetSpecialization() index} } for the spec
-- map resolve.lua builds.  Real Blizzard spec IDs in real index order (Monk's
-- index order is Brewmaster/Mistweaver/Windwalker = 268/270/269).
local CLASSES = {
  [1]  = { token = "WARRIOR",     specs = { 71, 72, 73 } },
  [2]  = { token = "PALADIN",     specs = { 65, 66, 70 } },
  [3]  = { token = "HUNTER",      specs = { 253, 254, 255 } },
  [4]  = { token = "ROGUE",       specs = { 259, 260, 261 } },
  [5]  = { token = "PRIEST",      specs = { 256, 257, 258 } },
  [6]  = { token = "DEATHKNIGHT", specs = { 250, 251, 252 } },
  [7]  = { token = "SHAMAN",      specs = { 262, 263, 264 } },
  [8]  = { token = "MAGE",        specs = { 62, 63, 64 } },
  [9]  = { token = "WARLOCK",     specs = { 265, 266, 267 } },
  [10] = { token = "MONK",        specs = { 268, 270, 269 } },
  [11] = { token = "DRUID",       specs = { 102, 103, 104, 105 } },
}

---Build an isolated world: loads the addon logic against fresh stubs.
---@return table h handle with ns, Api, api, items and helpers
function up.harness()
  local h = {
    ns = {},
    items = {},        -- keyed by both link (string) and itemID (number)
    chars = {},        -- name → Character
    allChars = {},     -- array, drives GetAllCharacters()
    pools = {},        -- name → { bags = {...}, bank = {...} }
    warband = {},      -- array of candidates
    wq = {},           -- name → array of world-quest reward candidates
    vendor = {},        -- array of VendorGear entries (mirrors ns.VendorGear)
    clock = 1000,      -- GetTime() seconds; advance with h:advance(n)
  }

  -- ----- WoW global stubs (captured by the addon files at load) ------------
  _G.Enum = {
    ItemClass = { Weapon = 2, Armor = 4 },
    ItemQuality = { Artifact = 6 },
  }

  local function lookup(linkOrId) return h.items[linkOrId] end

  _G.C_Item = {
    GetItemInfoInstant = function(linkOrId)
      local i = lookup(linkOrId)
      if not i then return nil end
      return i.itemID, nil, nil, i.equipLoc, nil, i.classID, i.subClassID
    end,
    GetDetailedItemLevelInfo = function(linkOrId)
      local i = lookup(linkOrId)
      return i and i.ilvl
    end,
    GetItemStats = function(linkOrId)
      local i = lookup(linkOrId)
      return i and i.stats
    end,
    GetItemQualityByID = function(linkOrId)
      local i = lookup(linkOrId)
      return i and i.rarity
    end,
  }

  _G.GetTime = function() return h.clock end

  -- Spec map globals consumed by resolve.lua's buildSpecMap.
  _G.GetNumClasses = function() return 11 end
  _G.GetClassInfo = function(classID)
    local c = CLASSES[classID]
    if c then return c.token, c.token end
  end
  _G.GetNumSpecializationsForClassID = function(classID)
    local c = CLASSES[classID]
    return c and #c.specs or 0
  end
  _G.GetSpecializationInfoForClassID = function(classID, i)
    local c = CLASSES[classID]
    return c and c.specs[i]
  end

  -- ----- fake WarbandeerApi (ns.api) ---------------------------------------
  local api = {}
  function api:ClassifyGearItem(itemID)
    local i = h.items[itemID]
    if i then return i.equipLoc, i.classID, i.subClassID end
  end
  function api:GetCharacterData(name) return h.chars[name] end
  function api:GetAllCharacters() return h.allChars end
  function api:GetCharacterGearCandidates(name)
    return h.pools[name] or { bags = {}, bank = {} }
  end
  function api:GetWarbandBankGear() return h.warband end
  function api:GetWorldQuestRewards(name) return h.wq[name] or {} end
  h.api = api

  -- ----- seed the ns fields core.lua would, then load the logic ------------
  h.ns.api = api
  h.ns.wow = { Armor = { byClass = ARMOR_BY_CLASS } }
  h.ns.UpgradeApi = {}
  for _, f in ipairs(FILES) do
    assert(loadfile("ShadowsOfUI-Upgrade/" .. f))("ShadowsOfUI-Upgrade", h.ns)
  end
  h.Api = h.ns.UpgradeApi
  -- The bundled quartermaster list (data/vendorgear.lua) isn't loaded — its real
  -- 14 item links don't resolve against the stub item table — so VendorUpgrades
  -- reads this synthetic list the tests build via h.addVendor.
  h.ns.VendorGear = h.vendor

  -- ----- test helpers -------------------------------------------------------

  ---Register an item under both its link and itemID so every WoW stub resolves it.
  ---@param info table { link, itemID, equipLoc, classID, subClassID, ilvl, stats? }
  ---@return table info the same table (for inline use as a candidate)
  function h.defItem(info)
    if info.link then h.items[info.link] = info end
    if info.itemID then h.items[info.itemID] = info end
    return info
  end

  ---Add a character and make it visible to GetCharacterData / GetAllCharacters.
  ---@param char table Character ({ name, classKey, equipment, basic? })
  function h.addChar(char)
    h.chars[char.name] = char
    table.insert(h.allChars, char)
  end

  ---Add a world-quest reward candidate for a character (drives GetWorldQuestRewards).
  ---@param name string character name
  ---@param reward table reward candidate ({ link, itemID, equipLoc, ..., questID, title, zone })
  ---@return table reward the same table (for inline use)
  function h.addWQ(name, reward)
    h.wq[name] = h.wq[name] or {}
    table.insert(h.wq[name], reward)
    return reward
  end

  ---Add a quartermaster-gear entry (drives VendorUpgrades via ns.VendorGear).
  ---@param entry table VendorGearEntry ({ quartermaster, zone, mapID, cost, ilvl, equipLoc, classID, options })
  ---@return table entry the same table (for inline use)
  function h.addVendor(entry)
    table.insert(h.vendor, entry)
    return entry
  end

  ---Advance the GetTime() clock (for the per-character memo TTL).
  function h.advance(seconds) h.clock = h.clock + seconds end

  return h
end

return up
