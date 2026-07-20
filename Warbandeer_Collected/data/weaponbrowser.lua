---@type Warbandeer_Collected
local ns = select(2, ...)
local Enum = Enum
local GetCategoryInfo = C_TransmogCollection.GetCategoryInfo
local GetCategoryAppearances = C_TransmogCollection.GetCategoryAppearances
local GetAppearanceSources = C_TransmogCollection.GetAppearanceSources
local GetAppearanceSourceDrops = C_TransmogCollection.GetAppearanceSourceDrops

-- Weapon "look builder" data layer (#596): a cached, read-only query surface over the
-- transmog appearance API, so the weapon/illusion picker UI can browse weapons by type and show
-- where each one comes from. Pure API/data — no frames.
--
-- Scoped to a CLASS (#608): the picker previews a set that belongs to a specific class, so the
-- weapon types, weapon appearances, and illusions on offer should be that class's, not the
-- logged-in viewer's. WeaponCategories AND WeaponAppearances read the wardrobe's global class
-- filter (GetCategoryInfo's type gating + GetCategoryAppearances's per-class list), so both run
-- their query under a snapshot/restore of that filter (withClassFilter); Illusions composes the
-- generic illusions with the previewed class's restricted ones. All take a classID and cache per class.
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
---@field WeaponCategories fun(classID: number?): WeaponCategory[]
---@field WeaponAppearances fun(category: number, classID: number?): WeaponAppearance[]
---@field WeaponSource fun(visualID: number): WeaponSource|false
---@field Illusions fun(classID: number?): WeaponIllusion[]

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

local _categories = {}            -- [classID] = WeaponCategory[] (each class's set is static per client)
local _appearances = {}           -- [classID] = { [category] = WeaponAppearance[] }
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

-- Run `fn` with the wardrobe's class filter temporarily set to `classID`, restoring the prior
-- filter afterward. GetCategoryInfo's weapon-type name-gating reads this GLOBAL filter (the same
-- gating Blizzard's own weapon dropdown uses), so scoping it here lets WeaponCategories reflect
-- ANY class, not just the logged-in one. A no-op when the filter already matches (the common case
-- — previewing your own class — never touches global wardrobe state). #608.
local function withClassFilter(classID, fn)
  local prev = C_TransmogCollection.GetClassFilter()
  if not classID or prev == classID then return fn() end
  C_TransmogCollection.SetClassFilter(classID)
  local result = fn()
  C_TransmogCollection.SetClassFilter(prev)
  return result
end

---The browseable weapon + off-hand categories usable by `classID` — the weapon types that class
---can transmog, with their capability flags. Cached per class (each class's set is static per
---client). `classID` defaults to whoever the wardrobe filter currently names (the logged-in char).
---@param classID number?  a chrClassID (1 Warrior .. 13 Evoker) to scope to; nil = current filter
---@return WeaponCategory[]
function ns.WeaponCategories(classID)
  classID = classID or C_TransmogCollection.GetClassFilter()
  local cached = _categories[classID]
  if cached then return cached end
  local list = withClassFilter(classID, function()
    local out = {}
    for _, cat in ipairs(WEAPON_CATEGORIES) do
      local name, isWeapon, canHaveIllusions, canMainHand, canOffHand = GetCategoryInfo(cat)
      if name then
        out[#out + 1] = {
          category = cat, name = name, isWeapon = isWeapon,
          canHaveIllusions = canHaveIllusions, canMainHand = canMainHand, canOffHand = canOffHand,
        }
      end
    end
    return out
  end)
  _categories[classID] = list
  return list
end

---Every appearance in a weapon category usable by `classID`, with account-wide collected state.
---GetCategoryAppearances reads the wardrobe's global class filter (a category the filtered class
---can't wield returns nothing), so — like WeaponCategories — the query runs under `classID`'s
---filter; otherwise a caster browsing a Warrior set's axes would see an empty list. Cached per
---(class, category); `classID` defaults to the current filter (the logged-in char).
---@param category number Enum.TransmogCollectionType
---@param classID number?  a chrClassID (1 Warrior .. 13 Evoker) to scope to; nil = current filter
---@return WeaponAppearance[]
function ns.WeaponAppearances(category, classID)
  classID = classID or C_TransmogCollection.GetClassFilter()
  local byClass = _appearances[classID]
  if not byClass then byClass = {}; _appearances[classID] = byClass end
  if byClass[category] then return byClass[category] end
  local list = withClassFilter(classID, function()
    local out = {}
    for _, v in ipairs(GetCategoryAppearances(category) or {}) do
      out[#out + 1] = { visualID = v.visualID, isCollected = v.isCollected }
    end
    return out
  end)
  byClass[category] = list
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

local _illusions = {}             -- [classID] = WeaponIllusion[] (wiped on collection change)

-- Restricted (class-specific) enchant illusions — the shimmer effects only one class can apply
-- (Rogue Poisoned, the DK Rune of Razorice, the Shaman weapon imbues). Derived lazily from the
-- #516 class weapon-cosmetics data (the illusion group in ns.Sets, whose positional `sets` maps
-- classId -> that class's illusions), so there's a single source of truth. Maps illusion sourceID
-- -> the one class that can use it; every OTHER illusion is generic (usable by any class). Static.
local _restricted
local function restrictedIllusions()
  if _restricted then return _restricted end
  _restricted = {}
  for _, g in ipairs(ns.Sets) do
    if g.kind == "illusion" then
      for classId, set in ipairs(g.sets) do
        if set.illusions then
          for _, il in ipairs(set.illusions) do _restricted[il.sourceID] = classId end
        end
      end
    end
  end
  return _restricted
end

-- Build a WeaponIllusion from a live GetIllusions entry (`info` supplied) or a bare sourceID (a
-- cross-class restricted illusion the live list can't surface). GetIllusionInfo / GetIllusionStrings
-- read account-wide + cross-class, so an illusion the logged-in char can't use still resolves.
local function illusionEntry(sourceID, info)
  info = info or C_TransmogCollection.GetIllusionInfo(sourceID)
  if not info then return nil end
  return {
    sourceID = sourceID, icon = info.icon, isCollected = info.isCollected,
    name = (C_TransmogCollection.GetIllusionStrings(sourceID)),
  }
end

---The enchant illusions usable by `classID`: every GENERIC illusion (the live GetIllusions list,
---minus the "no illusion" hide entry and any restricted illusion owned by a DIFFERENT class), plus
---the previewed class's own restricted illusions — so previewing another class's set shows THAT
---class's shimmer, not the viewer's. `classID` defaults to the logged-in character. Cached per
---class; wiped on collection change.
---@param classID number?  a chrClassID (1 Warrior .. 13 Evoker) to scope to; nil = current character
---@return WeaponIllusion[]
function ns.Illusions(classID)
  classID = classID or select(3, UnitClass("player"))
  local cached = _illusions[classID]
  if cached then return cached end
  local restricted = restrictedIllusions()
  local list, seen = {}, {}
  for _, il in ipairs(C_TransmogCollection.GetIllusions() or {}) do
    local owner = restricted[il.sourceID]
    if not il.isHideVisual and (not owner or owner == classID) then
      list[#list + 1] = illusionEntry(il.sourceID, il)
      seen[il.sourceID] = true
    end
  end
  -- The previewed class's restricted illusions the live list didn't surface (present only when
  -- logged in as that class) — resolved cross-class from their sourceIDs.
  for sourceID, owner in pairs(restricted) do
    if owner == classID and not seen[sourceID] then
      list[#list + 1] = illusionEntry(sourceID)
    end
  end
  _illusions[classID] = list
  return list
end

-- A weapon or illusion was collected (or any collection change): drop the cached collected-state so
-- the next query reflects it. Additive to commands.lua's rescan handler (registerEvent keeps a list).
ns:registerEvent("TRANSMOG_COLLECTION_UPDATED", function()
  _appearances = {}
  _sources = {}
  _illusions = {}
end)
