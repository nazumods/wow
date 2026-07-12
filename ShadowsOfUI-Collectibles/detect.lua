---@type ShadowsOfUI_Collectibles
local ns = select(2, ...)

local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetItemInfo = C_Item.GetItemInfo

-- Recipe item subclass (Enum.ItemRecipeSubclass) -> parent profession skill line.
-- Mirrors ShadowsOfUI-Known's map; Book/FirstAid/Fishing teach no craftable recipe.
local RECIPE_SUBCLASS_TO_SKILL = {
  [1] = 165, [2] = 197, [3] = 202, [4] = 164, [5] = 185,
  [6] = 171, [8] = 333, [10] = 755, [11] = 773,
}

-- "You already know this battle pet." with the trailing "(x/y)" count stripped.
local S_PET_KNOWN = ITEM_PET_KNOWN and ITEM_PET_KNOWN:match("[^%(]+")

-- Session caches, keyed by link. Positives are stable (something known stays
-- known). Negatives are cached only by the expensive tooltip-scanned paths, and
-- only once the item's data is loaded (an incomplete tooltip reads as a false
-- negative); known-negatives are wiped on collection-gain events below, while
-- collectible-negatives are permanent (an item's *type* never changes).
local knownCache, collectibleCache = {}, {}

-- A collection gain can flip a cached "not known" to known: drop the negative
-- entries (positives stay) and re-tint whatever is on screen.
local function forgetKnownNegatives()
  local dropped = false
  for link, v in pairs(knownCache) do
    if v == false then knownCache[link], dropped = nil, true end
  end
  if dropped then ns.Refresh() end
end
for _, e in ipairs({
  "NEW_RECIPE_LEARNED", "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "TOYS_UPDATED",
  "TRANSMOG_COLLECTION_SOURCE_ADDED", "QUEST_TURNED_IN", "HOUSING_STORAGE_UPDATED",
}) do
  ns:registerEvent(e, forgetKnownNegatives)
end

local function itemIDFromLink(link)
  return tonumber(link:match("item:(%d+)"))
end

local function speciesFromLink(link)
  return tonumber(link:match("battlepet:(%d+)"))
end

-- Recipe item name minus its "Recipe:/Pattern:/…" prefix — the crafted name as
-- captured in Warbandeer's learned-recipe data.
local function craftedName(itemName)
  if not itemName then return nil end
  return itemName:match("^[^:]+:%s*(.+)$") or itemName
end

-- Cross-alt: does any character have this recipe learned in the given profession?
local function anyAltKnowsRecipe(skillLineID, name)
  local api = ns.api
  if not (skillLineID and name and api and api.GetAllCharacters) then return false end
  for _, toon in ipairs(api:GetAllCharacters()) do
    local det = toon.professions and toon.professions.details and toon.professions.details[skillLineID]
    for _, bucket in pairs(det and det.recipes or {}) do
      for _, r in ipairs(bucket.learned or {}) do
        if r.name == name then return true end
      end
    end
  end
  return false
end

local function knowsCompanion(itemName, itemIcon)
  local numPets = C_PetJournal.GetNumPets()
  for i = 1, numPets do
    local _, _, owned, _, _, _, _, speciesName, icon = C_PetJournal.GetPetInfoByIndex(i)
    if owned and itemIcon == icon and itemName and speciesName and itemName:match(speciesName) then
      return true
    end
  end
  return false
end

-- Direct itemID -> mount lookup (no icon/name guessing): GetMountFromItem returns the
-- mountID for any mount item, then GetMountInfoByID's 11th return is isCollected.
local GetMountFromItem = C_MountJournal.GetMountFromItem
local function isMountItem(itemID) return itemID and GetMountFromItem(itemID) or nil end
local function knowsMount(mountID)
  return select(11, C_MountJournal.GetMountInfoByID(mountID)) and true or false
end

-- Owned-state for a decor item, delegated to ShadowsOfUI-HousingVendor's shared
-- decor detection (X-NUI-API `HousingDecorApi`) so the catalog derivation lives in
-- exactly one place. When HousingVendor isn't installed, the helper is absent and a
-- false here falls through to scanTooltipKnown, whose "Total Owned:" line covers
-- owned decor on its own (and reads even before the housing catalog has cached it).
local function knowsDecor(link)
  local api = _G.HousingDecorApi
  local d = api and api.EntryFor and api.EntryFor(link)
  return d ~= nil and d.owned
end

-- Lua pattern capturing the "owned" count from the decor tooltip's "Total Owned: N …"
-- line (HOUSING_DECOR_OWNED_COUNT_FORMAT): strip colour codes, escape parens, turn the
-- %d placeholders into number captures. The first capture is the owned total.
local S_DECOR_OWNED = HOUSING_DECOR_OWNED_COUNT_FORMAT and (
  HOUSING_DECOR_OWNED_COUNT_FORMAT
    :gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn%u+:", ""):gsub("|r", "")
    :gsub("([%(%)])", "%%%1"):gsub("%%d", "(%%d+)")
)

-- Tooltip fallback for owned-state the item-class paths above don't cover: the current
-- character's own recipe knowledge, cosmetics, misc "Already known" mounts, and decor
-- (its "Total Owned:" line — read even when the housing catalog hasn't cached the item).
-- Returns (known, sawTooltip). `sawTooltip` is true only when GetHyperlink
-- returned a populated tooltip — a negative is trustworthy only then, because the
-- "already known / owned" line resolves on its own schedule and an unloaded
-- tooltip reads as a false negative.
local function scanTooltipKnown(link)
  local data = C_TooltipInfo.GetHyperlink(link)
  local lines = data and data.lines
  if not (lines and lines[1]) then return false, false end
  for _, line in ipairs(lines) do
    local text = line.leftText
    if text == ITEM_SPELL_KNOWN then
      return true, true
    elseif S_PET_KNOWN and text and text:match(S_PET_KNOWN) then
      return true, true
    elseif S_DECOR_OWNED and text then
      local owned = text:match(S_DECOR_OWNED)
      if owned and tonumber(owned) > 0 then return true, true end
    end
  end
  return false, true
end

-- Whether the current account/character already owns/knows the item.
---@param link string  an item hyperlink or "item:<id>" string
---@return boolean
function ns.IsKnown(link)
  if not link then return false end
  local cached = knownCache[link]
  if cached ~= nil then return cached end

  local species = speciesFromLink(link)
  if species then
    local known = C_PetJournal.GetNumCollectedInfo(species) > 0
    if known then knownCache[link] = true end
    return known
  end

  local itemID = itemIDFromLink(link) or select(1, GetItemInfoInstant(link))
  if itemID then
    local q = ns.QuestItems[itemID]
    if q then
      -- Quest completion is monotonic, so a positive is safe to cache forever;
      -- a not-yet-done negative stays uncached (it flips on QUEST_TURNED_IN).
      if C_QuestLog.IsQuestFlaggedCompleted(q) then knownCache[link] = true return true end
      return false
    end

    local sp = ns.SpecialItems[itemID]
    if sp then
      local _, srcLink = GetItemInfo(sp[1])
      if not srcLink then return false end
      local field = tonumber((select(sp[2], strsplit(":", srcLink))))
      -- The whistle-upgrade state is monotonic too — cache the positive.
      if field == sp[3] then knownCache[link] = true return true end
      return false
    end

    local contents = ns.ContainerItems[itemID]
    if contents then
      for _, inner in ipairs(contents) do
        if not ns.IsKnown("item:" .. inner) then return false end
      end
      knownCache[link] = true
      return true
    end

    if PlayerHasToy(itemID) then knownCache[link] = true return true end

    local mountID = isMountItem(itemID)
    if mountID then
      if knowsMount(mountID) then knownCache[link] = true return true end
      return false
    end
  end

  local _, _, _, _, itemIcon, classID, subClassID = GetItemInfoInstant(itemID or link)
  local itemName = itemID and GetItemInfo(itemID)
  local known, sawTooltip
  if classID == Enum.ItemClass.Recipe then
    known = anyAltKnowsRecipe(RECIPE_SUBCLASS_TO_SKILL[subClassID], craftedName(itemName))
    if not known then known, sawTooltip = scanTooltipKnown(link) end
  elseif classID == Enum.ItemClass.Miscellaneous and subClassID == Enum.ItemMiscellaneousSubclass.CompanionPet then
    known = knowsCompanion(itemName, itemIcon)
    if not known then known, sawTooltip = scanTooltipKnown(link) end
  elseif classID == Enum.ItemClass.Housing and subClassID == Enum.ItemHousingSubclass.Decor then
    known = knowsDecor(link)
    if not known then known, sawTooltip = scanTooltipKnown(link) end
  else
    known, sawTooltip = scanTooltipKnown(link)
  end

  if known then
    knownCache[link] = true
  elseif sawTooltip then
    -- Trust a negative only once the tooltip actually loaded: the "already known"
    -- line resolves on its own schedule, so an unloaded tooltip reads as a false
    -- negative. Wiped anyway on a collection-gain event.
    knownCache[link] = false
  end
  return known
end

-- Whether the item is a recognized collectible *type*, whether or not it's owned.
-- Drives the "still collectible" tint; owned ones are caught first by IsKnown.
---@param link string
---@return boolean
function ns.IsCollectible(link)
  if not link then return false end
  local cached = collectibleCache[link]
  if cached ~= nil then return cached end

  local result = false
  local itemID
  local sawTooltip = false
  if speciesFromLink(link) then
    result = true
  else
    itemID = itemIDFromLink(link) or select(1, GetItemInfoInstant(link))
    local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemID or link)
    if itemID and (ns.QuestItems[itemID] or ns.SpecialItems[itemID] or ns.ContainerItems[itemID]) then
      result = true
    elseif classID == Enum.ItemClass.Recipe then
      result = true
    elseif isMountItem(itemID) then
      result = true
    elseif classID == Enum.ItemClass.Miscellaneous and subClassID == Enum.ItemMiscellaneousSubclass.CompanionPet then
      result = true
    elseif classID == Enum.ItemClass.Housing and subClassID == Enum.ItemHousingSubclass.Decor then
      result = true
    elseif itemID and C_ToyBox.GetToyInfo(itemID) then
      result = true
    else
      -- "Use to learn" plans that aren't a Recipe item class (Blizzard tags some as
      -- Consumable) — catch the recipe-teach line. "Teaches you" is enUS-specific.
      local data = C_TooltipInfo.GetHyperlink(link)
      local lines = data and data.lines
      sawTooltip = (lines and lines[1]) ~= nil
      for _, line in ipairs(lines or {}) do
        local text = line.leftText
        if text and text:find("Teaches you", 1, true) then
          result = true
          break
        end
      end
    end
  end

  if result then
    collectibleCache[link] = true
  elseif itemID and sawTooltip then
    -- Cache the permanent negative only once the tooltip actually loaded: the
    -- "Teaches you" line resolves asynchronously and collectible-negatives are
    -- never wiped, so caching on an unloaded tooltip would lock a false negative
    -- for the whole session. Synchronous class-typed items never reach here.
    collectibleCache[link] = false
  end
  return result
end
