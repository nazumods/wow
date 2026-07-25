---@type Warbandeer_Collected
local ns = select(2, ...)

-- What the library window's filter strip runs on (#662): the rule that decides which saved looks a
-- set of facets shows. Split out of outfitlibrary.lua for file size once that file gained its change
-- notification (#727) — the store keeps the writes, this keeps the reads over them.
--
-- Pure over the entries, like the store next door, so the whole rule is unit-tested
-- (spec/outfitfilter_spec.lua) and controls/OutfitLibraryWindow.lua is left holding nothing but
-- widgets.
--
-- **A missing field is UNKNOWN, never a non-match.** Entries saved before #655 carry no provenance
-- at all, and a filter that hid them would make looks the user still owns silently vanish from the
-- only list that shows them — the one outcome this must not have. So a nil `armor` or `forClass`
-- passes every filter, as does a stored `armor` of "Any": `ns.OutfitArmorType` returns that for a
-- cosmetic, mixed or weapon-only look, which genuinely goes on anyone and so belongs under every
-- armour type rather than under none.
--
-- Search is deliberately NOT held to the same rule. It is a positive query for text rather than a
-- facet, `name` is always present to match against, and letting provenance-less entries match every
-- term would make searching by character name useless — the opposite of the reported need.

---@class OutfitFilter
---@field armor string?  "Cloth"|"Leather"|"Mail"|"Plate"; nil or "Any" for no armour filter
---@field class string?  a class file ("WARRIOR") matched against `forClass`; nil for any
---@field search string?  matched case-insensitively against the look's name and the saving character

---@class Warbandeer_Collected
---@field FilterOutfits fun(outfits: LibraryOutfit[], filter: OutfitFilter?): LibraryOutfit[]
---@field LibraryFacets fun(outfits: LibraryOutfit[]): string[]

-- The armour type that constrains nobody, at both ends of the comparison: the "no filter" option
-- and a real stored value. `ns.OutfitArmorType` (outfit.lua) is what produces the stored one.
local ANY = "Any"

-- Trim, so an all-whitespace search term reads as no search at all. The store's own copy of this
-- (outfitlibrary.lua) is what a saved NAME goes through; duplicated rather than exported because
-- one line of pattern is cheaper than API neither file would otherwise have.
---@param s string
---@return string
local function clean(s)
  return s:match("^%s*(.-)%s*$")
end

---@param entry LibraryOutfit
---@param wanted string?
---@return boolean
local function matchesArmor(entry, wanted)
  if not wanted or wanted == ANY then return true end
  return entry.armor == nil or entry.armor == ANY or entry.armor == wanted
end

---Keys on `forClass` — the class the look was BUILT FOR — not `class`, which records who saved it.
---A look's own class is what a user filtering by class is after; `class` is provenance, and is
---already what the dropdown's colour tint means (see `DressingRoom:RefreshOutfits`). The two
---deliberately answer different questions, so the same entry can be a Druid's saved Warrior look.
---@param entry LibraryOutfit
---@param wanted string?
---@return boolean
local function matchesClass(entry, wanted)
  if not wanted or wanted == ANY then return true end
  return entry.forClass == nil or entry.forClass == wanted
end

-- Plain (non-pattern) find, so a name or search term containing `%`, `-` or `(` matches literally
-- instead of erroring or silently behaving as a pattern.
---@param entry LibraryOutfit
---@param needle string?  already trimmed and lowercased
---@return boolean
local function matchesSearch(entry, needle)
  if not needle then return true end
  if entry.name and entry.name:lower():find(needle, 1, true) then return true end
  return (entry.char and entry.char:lower():find(needle, 1, true)) ~= nil
end

---The entries matching every dimension of `filter` (an absent dimension constrains nothing), in
---the library's own order. Returns the entries themselves, not copies — callers act on them by
---name, so sharing identity is both cheaper and what lets a caller compare against a selection.
---@param outfits LibraryOutfit[]
---@param filter OutfitFilter?
---@return LibraryOutfit[]
function ns.FilterOutfits(outfits, filter)
  filter = filter or {}
  local needle = filter.search and clean(filter.search):lower()
  if needle == "" then needle = nil end
  local out = {}
  for _, o in ipairs(outfits or {}) do
    if matchesArmor(o, filter.armor) and matchesClass(o, filter.class) and matchesSearch(o, needle) then
      out[#out + 1] = o
    end
  end
  return out
end

---The `forClass` values actually present, deduped and sorted, so the class dropdown offers nothing
---that cannot match anything. Sorted by class FILE rather than by localised label to keep this
---pure (labelling is a `GetClassInfo` call) and the order stable as the library grows; the window
---labels them on the way out.
---
---Entries with no `forClass` contribute nothing — they are unknown rather than a class, and they
---pass every class filter regardless, so they need no option of their own.
---@param outfits LibraryOutfit[]
---@return string[]
function ns.LibraryFacets(outfits)
  local seen, out = {}, {}
  for _, o in ipairs(outfits or {}) do
    if o.forClass and not seen[o.forClass] then
      seen[o.forClass] = true
      out[#out + 1] = o.forClass
    end
  end
  table.sort(out)
  return out
end
