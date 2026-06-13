---@class ShadowsOfUI_Known: AddOn
local ns = LibNAddOn(...)

local insert, sort = table.insert, table.sort
local GetItemInfoInstant = C_Item.GetItemInfoInstant

-- Recipe item subclass (Enum.ItemRecipeSubclass) -> parent profession skill line ID.
-- Book(0)/FirstAid(7)/Fishing(9) subclasses teach no craftable recipe, so are absent.
local RECIPE_SUBCLASS_TO_SKILL = {
  [1]  = 165, -- Leatherworking
  [2]  = 197, -- Tailoring
  [3]  = 202, -- Engineering
  [4]  = 164, -- Blacksmithing
  [5]  = 185, -- Cooking
  [6]  = 171, -- Alchemy
  [8]  = 333, -- Enchanting
  [10] = 755, -- Jewelcrafting
  [11] = 773, -- Inscription
}

local PROF_SLOTS = { "primary", "secondary", "fishing", "cooking" }

-- A character's profession slot matching skillLineID (carries skillLevel), or nil.
---@param toon Character
---@param skillLineID integer
local function findProf(toon, skillLineID)
  local profs = toon.basic and toon.basic.professions
  if not profs then return nil end
  for _, slot in ipairs(PROF_SLOTS) do
    local p = profs[slot]
    if p and p.skillID == skillLineID then return p end
  end
end

-- Strip the "Recipe:/Pattern:/Plans:/Schematic:/Formula:/Technique:/Design:" prefix from
-- a recipe item's name, yielding the crafted recipe name as captured in learned data.
local function craftedName(itemName)
  if not itemName then return nil end
  return itemName:match("^[^:]+:%s*(.+)$") or itemName
end

-- Whether the alt's captured data already lists this recipe as learned. Learned names are
-- bucketed per expansion (midnight/tww/df); we union them. A profession never opened on
-- that alt has no capture and reads as "not learned" (so it stays listed until scanned).
---@param toon Character
local function knowsRecipe(toon, skillLineID, name)
  local det = toon.professions and toon.professions.details and toon.professions.details[skillLineID]
  local buckets = det and det.recipes
  if not buckets then return false end
  for _, bucket in pairs(buckets) do
    for _, r in ipairs(bucket.learned or {}) do
      if r.name == name then return true end
    end
  end
  return false
end

-- Profession intent rank from Warbandeer's WarbandeerDB (optional dependency): main = 1,
-- secondary = 2, everything else (gatherer / unset / no Warbandeer installed) = 3.
local INTENT_RANK = { main = 1, secondary = 2 }
local function intentRank(charName, skillLineID)
  local forChar = WarbandeerDB and WarbandeerDB.profIntent and WarbandeerDB.profIntent[charName]
  return INTENT_RANK[forChar and forChar[skillLineID]] or 3
end

---@class KnownEntry
---@field name string
---@field classKey string
---@field meets boolean    whether the alt meets the recipe's skill requirement
---@field rank integer     intent rank (1 main, 2 secondary, 3 other) for ordering
---@field level integer
---@field skill integer

-- Alts that can still learn the given recipe item: those who have its profession but
-- haven't learned it, ordered main -> secondary -> other, then level desc, skill desc,
-- name. Also returns how many characters already know it, so an empty list can be told
-- apart from "nobody has the profession". Returns nil when the item isn't a craftable
-- recipe, so callers add nothing.
---@param itemID integer
---@param reqSkill integer  skill threshold read off the item (0 = no numeric requirement)
---@param itemName string?  the recipe item's name, for the already-learned check
---@return KnownEntry[]? list
---@return integer knownCount  characters that already know the recipe
function ns.BuildLearnable(itemID, reqSkill, itemName)
  local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemID)
  if classID ~= Enum.ItemClass.Recipe then return nil end
  local skillLineID = RECIPE_SUBCLASS_TO_SKILL[subClassID]
  if not skillLineID then return nil end
  local api = ns.api
  if not api or not api.GetAllCharacters then return nil end

  local recipe = craftedName(itemName)
  local list, knownCount = {}, 0
  for _, toon in ipairs(api:GetAllCharacters()) do
    local p = findProf(toon, skillLineID)
    if p then
      if recipe and knowsRecipe(toon, skillLineID, recipe) then
        knownCount = knownCount + 1
      else
        local skill = p.skillLevel or 0
        insert(list, {
          name     = toon.name,
          classKey = toon.classKey,
          meets    = reqSkill == 0 or skill >= reqSkill,
          rank     = intentRank(toon.name, skillLineID),
          level    = toon.basic and toon.basic.level or 0,
          skill    = skill,
        })
      end
    end
  end
  sort(list, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    if a.level ~= b.level then return a.level > b.level end
    if a.skill ~= b.skill then return a.skill > b.skill end
    return a.name < b.name
  end)
  return list, knownCount
end
