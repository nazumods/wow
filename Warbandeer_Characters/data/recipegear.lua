---@type Warbandeer_Characters
local ns = select(2, ...)
local API = ns.api
-- luacheck: globals C_TradeSkillUI C_Item Enum GetBuildInfo

-- Account-wide cache of which recipes craft profession gear (recipe →
-- schematic → output item).  The resolution is static game data — identical
-- for every character and only changed by client patches — so it is persisted
-- in the DB stamped with the client build and wiped when the build changes.
-- Populated incrementally: the professions broker pre-resolves a profession's
-- current-expansion recipes at scan time (while trade-skill data is hot), and
-- ResolveRecipeOutput fills cache misses lazily for any consumer.

-- Item subclass (which profession the gear is FOR) → parent skillLineID.  The
-- crafting profession differs — e.g. Blacksmithing crafts Mining picks.
local SUBCLASS_SKILL = {
  [Enum.ItemProfessionSubclass.Blacksmithing]  = 164,
  [Enum.ItemProfessionSubclass.Leatherworking] = 165,
  [Enum.ItemProfessionSubclass.Alchemy]        = 171,
  [Enum.ItemProfessionSubclass.Herbalism]      = 182,
  [Enum.ItemProfessionSubclass.Cooking]        = 185,
  [Enum.ItemProfessionSubclass.Mining]         = 186,
  [Enum.ItemProfessionSubclass.Tailoring]      = 197,
  [Enum.ItemProfessionSubclass.Engineering]    = 202,
  [Enum.ItemProfessionSubclass.Enchanting]     = 333,
  [Enum.ItemProfessionSubclass.Fishing]        = 356,
  [Enum.ItemProfessionSubclass.Skinning]       = 393,
  [Enum.ItemProfessionSubclass.Jewelcrafting]  = 755,
  [Enum.ItemProfessionSubclass.Inscription]    = 773,
}

---@class RecipeGearInfo
---@field itemID integer
---@field rarity integer Enum.ItemQuality of the output item
---@field equipLoc string INVTYPE_PROFESSION_TOOL | INVTYPE_PROFESSION_GEAR
---@field skillID integer parent skillLineID of the profession the gear is for

---@class RecipeGearCache
---@field build string client version-build the cache was resolved against
---@field recipes table<integer, RecipeGearInfo|false> false = resolved, not prof gear

---@class WarbandeerCharactersDB
---@field recipeGear RecipeGearCache

---Classify an item as profession gear by its static item class/subclass — the
---bit that's identical for a recipe's output item and the same item sitting in a
---guild bank.  Returns nil if the item isn't profession gear.  GetItemInfoInstant
---is synchronous (no item load required), so this never blocks.
---@param itemID integer
---@return integer? skillID parent skillLineID of the profession the gear is for
---@return string? equipLoc INVTYPE_PROFESSION_TOOL | INVTYPE_PROFESSION_GEAR
function API:ClassifyProfGearItem(itemID)
  local _, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
  if classID ~= Enum.ItemClass.Profession then return nil end
  return SUBCLASS_SKILL[subClassID], equipLoc
end

-- The cache's recipes table, recreated empty whenever the client build changes
-- (patches can rewire recipes and items).
local function cachedRecipes()
  local db = ns.db
  local version, buildNum = GetBuildInfo()
  local build = version .. "-" .. buildNum
  if not db.recipeGear or db.recipeGear.build ~= build then
    db.recipeGear = { build = build, recipes = {} }
  end
  return db.recipeGear.recipes
end

---What profession gear a recipe crafts, from the account-wide cache (resolving
---and persisting on a miss).  Returns false if the recipe doesn't craft
---profession gear, nil if the output item isn't in the client item cache yet
---(a load is requested; call again later).
---@param recipeID integer recipe spell ID
---@return RecipeGearInfo|false|nil
function API:ResolveRecipeOutput(recipeID)
  local recipes = cachedRecipes()
  local cached = recipes[recipeID]
  if cached ~= nil then return cached end

  local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
  local itemID = schematic and schematic.outputItemID
  if not itemID then
    recipes[recipeID] = false
    return false
  end
  local skillID, equipLoc = self:ClassifyProfGearItem(itemID)
  if not skillID then
    recipes[recipeID] = false
    return false
  end
  local rarity = C_Item.GetItemQualityByID(itemID)
  if not rarity then
    C_Item.RequestLoadItemDataByID(itemID)
    return nil
  end
  local info = { itemID = itemID, rarity = rarity, equipLoc = equipLoc, skillID = skillID }
  recipes[recipeID] = info
  return info
end
