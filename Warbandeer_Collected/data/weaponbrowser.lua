---@type Warbandeer_Collected
local ns = select(2, ...)
local Enum = Enum
local GetCategoryInfo = C_TransmogCollection.GetCategoryInfo
local GetCategoryAppearances = C_TransmogCollection.GetCategoryAppearances
local GetAppearanceSources = C_TransmogCollection.GetAppearanceSources
local GetAppearanceSourceDrops = C_TransmogCollection.GetAppearanceSourceDrops

-- Weapon "look builder" data layer (#596): a cached, read-only query surface over the
-- transmog appearance API, so the weapon/illusion picker UI (a later PR in the epic) can
-- browse weapons by type and show where each one comes from. Pure API/data — no frames.
--
-- Weapons are organized by C_TransmogCollection appearance CATEGORY (Enum.TransmogCollectionType),
-- a different surface than the C_TransmogSets set ids the armor grid uses. Per category,
-- GetCategoryAppearances lists every weapon appearance with its account-wide isCollected; an
-- appearance's source + drop location resolve LAZILY via GetAppearanceSources /
-- GetAppearanceSourceDrops (resolving a source for every appearance up front would be hundreds
-- of C calls, so WeaponAppearances stays light and WeaponSource does the per-pick lookup).
--
-- Both caches are wiped on TRANSMOG_COLLECTION_UPDATED so a freshly collected weapon flips its
-- isCollected on the next query. This is a SECOND handler for that event — commands.lua registers
-- its rescan handler too; registerEvent keeps a per-event handler list, so the two coexist.

---@class WeaponCategory
---@field category number          Enum.TransmogCollectionType value
---@field name string              localized category name ("One-Handed Swords", "Shields", …)
---@field isWeapon boolean
---@field canHaveIllusions boolean weapon slots that accept an enchant illusion
---@field canMainHand boolean
---@field canOffHand boolean

---@class WeaponAppearance
---@field visualID number          appearance id (GetCategoryAppearances .visualID); feed to WeaponSource
---@field isCollected boolean      account-wide collected state

---@class WeaponSource
---@field sourceID number          itemModifiedAppearanceID — feed to Model:TryOn / Model:SlotTransmog
---@field itemID number
---@field name string
---@field isCollected boolean
---@field sourceType number        Enum.TransmogSource
---@field quality number?          best Enum.ItemQuality across the appearance's sources (nil if unknown)
---@field text string?             resolved "<encounter>, <instance>" drop line, else the generic source label

---@class WeaponIllusion
---@field sourceID number          illusion sourceID — feed to Model:SlotTransmog opts.illusionID
---@field icon number              icon fileID
---@field isCollected boolean
---@field name string?             localized illusion name (GetIllusionStrings)

---@class Warbandeer_Collected
---@field WeaponCategories fun(): WeaponCategory[]
---@field WeaponAppearances fun(category: number): WeaponAppearance[]
---@field WeaponSource fun(visualID: number): WeaponSource|false
---@field Illusions fun(): WeaponIllusion[]

-- Main-hand weapon types first (1H, then 2H, then ranged), then the off-hands. Filtered through
-- GetCategoryInfo at query time, so any category invalid on a given client simply drops out.
local WEAPON_CATEGORIES = {
  Enum.TransmogCollectionType.OneHAxe,
  Enum.TransmogCollectionType.OneHSword,
  Enum.TransmogCollectionType.OneHMace,
  Enum.TransmogCollectionType.Dagger,
  Enum.TransmogCollectionType.Fist,
  Enum.TransmogCollectionType.TwoHAxe,
  Enum.TransmogCollectionType.TwoHSword,
  Enum.TransmogCollectionType.TwoHMace,
  Enum.TransmogCollectionType.Polearm,
  Enum.TransmogCollectionType.Staff,
  Enum.TransmogCollectionType.Warglaives,
  Enum.TransmogCollectionType.Bow,
  Enum.TransmogCollectionType.Crossbow,
  Enum.TransmogCollectionType.Gun,
  Enum.TransmogCollectionType.Wand,
  Enum.TransmogCollectionType.Shield,
  Enum.TransmogCollectionType.Holdable,
}

local _categories                 -- lazily built WeaponCategory[] (the category set is static per client)
local _appearances = {}           -- [category]  = WeaponAppearance[]
local _sources = {}               -- [visualID]  = WeaponSource | false (false = no resolvable source)

-- "<encounter>, <instance>" formatter (a FrameXML global string, loaded before any addon).
local ENCOUNTER_FMT = _G["WARDROBE_TOOLTIP_ENCOUNTER_SOURCE"]

-- Best-effort human "where from" line for a picked source: a boss drop resolves to its encounter
-- + instance (the wardrobe's "from …" line); anything else falls back to the generic per-sourceType
-- label (Quest / Vendor / World Drop / …). nil when neither is known.
local function sourceText(source)
  local drops = GetAppearanceSourceDrops(source.sourceID)
  if drops and #drops > 0 then
    local d = drops[1]
    if #drops == 1 and ENCOUNTER_FMT then return ENCOUNTER_FMT:format(d.encounter, d.instance) end
    return d.instance   -- spread across encounters/instances: name the first instance
  end
  return _G["TRANSMOG_SOURCE_" .. (source.sourceType or 0)]
end

---The browseable weapon + off-hand categories with their capability flags (cached; static per client).
---@return WeaponCategory[]
function ns.WeaponCategories()
  if _categories then return _categories end
  _categories = {}
  for _, cat in ipairs(WEAPON_CATEGORIES) do
    local name, isWeapon, canHaveIllusions, canMainHand, canOffHand = GetCategoryInfo(cat)
    if name then
      _categories[#_categories + 1] = {
        category = cat, name = name, isWeapon = isWeapon,
        canHaveIllusions = canHaveIllusions, canMainHand = canMainHand, canOffHand = canOffHand,
      }
    end
  end
  return _categories
end

---Every appearance in a weapon category, with account-wide collected state (cached per category).
---@param category number Enum.TransmogCollectionType
---@return WeaponAppearance[]
function ns.WeaponAppearances(category)
  local cached = _appearances[category]
  if cached then return cached end
  local list = {}
  for _, v in ipairs(GetCategoryAppearances(category) or {}) do
    list[#list + 1] = { visualID = v.visualID, isCollected = v.isCollected }
  end
  _appearances[category] = list
  return list
end

---Resolve one appearance to a usable source (a sourceID to try on) plus a human "where from" line.
---Prefers a collected source, else the first — mirroring the wardrobe's header pick. Cached per visual.
---@param visualID number a WeaponAppearance.visualID
---@return WeaponSource|false source false when the appearance has no resolvable source
function ns.WeaponSource(visualID)
  local cached = _sources[visualID]
  if cached ~= nil then return cached end
  local pick, quality
  for _, s in ipairs(GetAppearanceSources(visualID) or {}) do
    -- pick prefers the first COLLECTED source (the wardrobe's header pick); `quality` is the
    -- BEST across ALL sources, so scan the whole list instead of breaking on the first match.
    if not pick or (s.isCollected and not pick.isCollected) then pick = s end
    if s.quality and (not quality or s.quality > quality) then quality = s.quality end
  end
  if not pick then _sources[visualID] = false; return false end
  local info = {
    sourceID = pick.sourceID, itemID = pick.itemID, name = pick.name,
    isCollected = pick.isCollected, sourceType = pick.sourceType,
    quality = quality, text = sourceText(pick),
  }
  _sources[visualID] = info
  return info
end

-- Every class-usable enchant illusion (GetIllusions is class-filtered like the weapon categories),
-- skipping the "no illusion" hide entry. Each carries its icon + collected state; the name resolves
-- synchronously via GetIllusionStrings. Cached; wiped on collection change.
local _illusions

---The character's usable enchant illusions, with collected state (cached).
---@return WeaponIllusion[]
function ns.Illusions()
  if _illusions then return _illusions end
  _illusions = {}
  for _, il in ipairs(C_TransmogCollection.GetIllusions() or {}) do
    if not il.isHideVisual then
      _illusions[#_illusions + 1] = {
        sourceID = il.sourceID, icon = il.icon, isCollected = il.isCollected,
        name = (C_TransmogCollection.GetIllusionStrings(il.sourceID)),
      }
    end
  end
  return _illusions
end

-- A weapon or illusion was collected (or any collection change): drop the cached collected-state so
-- the next query reflects it. Additive to commands.lua's rescan handler (registerEvent keeps a list).
ns:registerEvent("TRANSMOG_COLLECTION_UPDATED", function()
  _appearances = {}
  _sources = {}
  _illusions = nil
end)
