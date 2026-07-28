---@type Warbandeer_Characters
local ns = select(2, ...)
---@type WarbandeerAPI
local API = ns.api

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
---@field name string? output item's name, captured at resolve time (nil for entries cached before the field existed, backfilled on the next resolve)

---@class RecipeGearCache
---@field build string client version-build the cache was resolved against
---@field recipes table<integer, RecipeGearInfo|false> false = resolved, not prof gear

---@class WarbandeerCharactersDB
---@field recipeGear RecipeGearCache

---@class WarbandeerAPI
---@field ClassifyProfGearItem fun(self: WarbandeerAPI, itemID: integer): integer?, string?
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

-- Equip locations that don't map to a tracked equipment slot (cosmetic only).
local COSMETIC_EQUIPLOC = { INVTYPE_BODY = true, INVTYPE_TABARD = true }

---@class WarbandeerAPI
---@field ClassifyGearItem fun(self: WarbandeerAPI, itemID: integer): string?, integer?, integer?
---Classify an item as equippable gear (armour or weapon filling a real slot) by
---its static item class/subclass, for the gear-upgrade cache.  Returns nil for
---anything that can't upgrade an equipment slot (cosmetics, non-gear).  Like
---ClassifyProfGearItem this is synchronous (GetItemInfoInstant needs no load).
---@param itemID integer
---@return string? equipLoc INVTYPE_* the item fills
---@return integer? classID Enum.ItemClass (Armor | Weapon)
---@return integer? subClassID armour type / weapon subclass
function API:ClassifyGearItem(itemID)
  local _, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
  if classID ~= Enum.ItemClass.Armor and classID ~= Enum.ItemClass.Weapon then return nil end
  if not equipLoc or equipLoc == "" or COSMETIC_EQUIPLOC[equipLoc] then return nil end
  return equipLoc, classID, subClassID
end

-- The cache's recipes table, recreated empty whenever the client build changes
-- (patches can rewire recipes and items).
--
-- The build stamp alone is not enough: `name` comes from C_Item.GetItemInfo and is
-- locale-dependent, so a language switch inside one build kept foreign names and silently broke the
-- family match (#745-5). Stamp the locale too, following data/titlecatalog.lua's precedent — but
-- clear only the NAMES on a switch, since itemID / equipLoc / classID / subClassID are
-- locale-independent and expensive to re-resolve.
local function cachedRecipes()
  local db = ns.db
  local version, buildNum = GetBuildInfo()
  local build = version .. "-" .. buildNum
  local locale = GetLocale()
  if not db.recipeGear or db.recipeGear.build ~= build then
    db.recipeGear = { build = build, locale = locale, recipes = {} }
  elseif db.recipeGear.locale ~= locale then
    -- `if r then` matters: `false` is a valid cached value ("doesn't craft profession gear"). An
    -- existing cache with no `locale` key takes this path once on first load after this ships,
    -- which is correct and self-healing. ResolveRecipeOutput's lazy backfill re-resolves the names.
    for _, r in pairs(db.recipeGear.recipes) do if r then r.name = nil end end
    db.recipeGear.locale = locale
  end
  return db.recipeGear.recipes
end

---@class WarbandeerAPI
---@field ResolveRecipeOutput fun(self: WarbandeerAPI, recipeID: integer): RecipeGearInfo | false | nil
---What profession gear a recipe crafts, from the account-wide cache (resolving
---and persisting on a miss).  Returns false if the recipe doesn't craft
---profession gear, nil if the output item isn't in the client item cache yet
---(a load is requested; call again later).
---@param recipeID integer recipe spell ID
---@return RecipeGearInfo|false|nil
function API:ResolveRecipeOutput(recipeID)
  local recipes = cachedRecipes()
  local cached = recipes[recipeID]
  if cached ~= nil then
    -- Entries resolved before `name` existed keep their build (so they aren't
    -- rebuilt wholesale); fill the field in place once the item is warm.
    if cached and not cached.name then cached.name = C_Item.GetItemInfo(cached.itemID) end
    return cached
  end

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
  -- The item is warm by here (GetItemQualityByID answered), so its name resolves
  -- synchronously. Stored because consumers key a gear line by the name's last word,
  -- which an offline reader can't recover from the item id alone.
  local info = {
    itemID = itemID, rarity = rarity, equipLoc = equipLoc, skillID = skillID,
    name = C_Item.GetItemInfo(itemID),
  }
  recipes[recipeID] = info
  return info
end

-- Diagnostic: list resolved craftable profession gear, grouped by the gear's
-- profession + equip slot, showing each item's crafters as Name(craftSkill:recipe).
-- Mirrors the tooltip's buildCraftable (current professions only) so it reveals
-- exactly who is being credited with crafting what.  Optional arg filters to one
-- gear skillLineID (e.g. /wbc dump profgear 164 for Blacksmithing gear).
ns:registerDump("profgear", "Craftable Gear", "Dump resolved craftable profession gear (arg: gear skillLineID)", function(_, out, args)
  local filter = tonumber(args)
  local byProf = {}
  for name, c in pairs(ns.db.characters) do
    local active = {}
    for _, p in pairs(c.basic and c.basic.professions or {}) do
      if type(p) == "table" and p.skillID then active[p.skillID] = true end
    end
    for craftSkill, det in pairs(c.professions and c.professions.details or {}) do
      local bucket = active[craftSkill] and det.recipes and det.recipes.midnight
      for _, r in ipairs(bucket and bucket.learned or {}) do
        local res = API:ResolveRecipeOutput(r.id)
        if res and (not filter or res.skillID == filter) then
          byProf[res.skillID] = byProf[res.skillID] or {}
          local slot = byProf[res.skillID][res.equipLoc] or {}
          byProf[res.skillID][res.equipLoc] = slot
          local it = slot[res.itemID] or { rarity = res.rarity, crafters = {} }
          slot[res.itemID] = it
          table.insert(it.crafters, name .. "(" .. craftSkill .. ":" .. (r.name or r.id) .. ")")
        end
      end
    end
  end
  out:line("Craftable profession gear" .. (filter and (" for gear skill " .. filter) or "") .. ":")
  for skillID, slots in pairs(byProf) do
    out:line("== gear skill " .. skillID .. " ==")
    for equipLoc, items in pairs(slots) do
      out:line("  " .. equipLoc)
      for itemID, it in pairs(items) do
        out:line(("    %s (%d) r%s <- %s"):format(
          C_Item.GetItemInfo(itemID) or "?", itemID, tostring(it.rarity), table.concat(it.crafters, ", ")))
      end
    end
  end
end)
