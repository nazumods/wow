---@type Warbandeer_Collected
local ns = select(2, ...)
local Enum = Enum
local GetCategoryInfo = C_TransmogCollection.GetCategoryInfo
local GetCategoryAppearances = C_TransmogCollection.GetCategoryAppearances

-- Shirt + tabard browse layer — the read-only query surface the cosmetic slots and their picker
-- (#641) sit on, and the vocabulary outfit.lua uses to name those two slots. Pure API/data, no
-- frames. A sibling of data/weaponbrowser.lua rather than part of it: that file is already at the
-- top of the repo's 200–300 line budget, and these categories need none of its class-scoping.
--
-- Why these two slots need their own layer at all: transmog SETS (C_TransmogSets) never carry a
-- shirt or a tabard, so unlike every other paper-doll slot there is no set piece to read them
-- from. They are browsed straight off the appearance collection instead, like weapons are.
--
-- No withClassFilter dance here (contrast weaponbrowser.lua): shirts and tabards are usable by
-- every class, so GetCategoryAppearances returns the same list whatever the wardrobe filter says.

---@class CosmeticCategory
---@field category number  Enum.TransmogCollectionType value
---@field slot number      inventory slot id a pick from this category applies to
---@field name string      localized category name ("Shirt", "Tabard")
---@field empty string     Blizzard paper-doll placeholder texture for an empty slot

---@class Warbandeer_Collected
---@field CosmeticCategories fun(): CosmeticCategory[]
---@field CosmeticAppearances fun(category: number): WeaponAppearance[]
---@field CosmeticCategoryForSlot fun(slot: number): CosmeticCategory?

-- Static descriptors; `name` is resolved lazily below (the localized strings aren't reliably
-- available at file-load time). `fallback` is the last-resort English label — only reached on a
-- client where neither the wardrobe category name nor the paper-doll slot string resolves.
local COSMETICS = {
  { category = Enum.TransmogCollectionType.Shirt,  slot = INVSLOT_BODY,
    slotString = "INVTYPE_BODY",   fallback = "Shirt",
    empty = [[Interface\PaperDoll\UI-PaperDoll-Slot-Shirt]] },
  { category = Enum.TransmogCollectionType.Tabard, slot = INVSLOT_TABARD,
    slotString = "INVTYPE_TABARD", fallback = "Tabard",
    empty = [[Interface\PaperDoll\UI-PaperDoll-Slot-Tabard]] },
}

local _categories                 -- CosmeticCategory[] (static per client, built once)
local _appearances = {}           -- [category] = WeaponAppearance[] (wiped on collection change)

---The cosmetic categories the dressing room offers, with their localized names. Prefers the
---wardrobe's own category label, falling back to the paper-doll slot string, then the English
---literal. Cached — the set is static per client.
---@return CosmeticCategory[]
function ns.CosmeticCategories()
  if _categories then return _categories end
  local out = {}
  for _, c in ipairs(COSMETICS) do
    local name = GetCategoryInfo(c.category) or _G[c.slotString] or c.fallback
    out[#out + 1] = { category = c.category, slot = c.slot, name = name, empty = c.empty }
  end
  _categories = out
  return out
end

---The descriptor whose pick lands in `slot`, or nil when that slot isn't a cosmetic one. Lets a
---caller route an inventory slot id back to its category without knowing the mapping.
---@param slot number  inventory slot id
---@return CosmeticCategory?
function ns.CosmeticCategoryForSlot(slot)
  for _, c in ipairs(ns.CosmeticCategories()) do
    if c.slot == slot then return c end
  end
end

---Every appearance in a cosmetic category, with account-wide collected state. Same shape as
---`ns.WeaponAppearances` so the picker can render either through one row builder; resolve a
---chosen visual to a usable source with `ns.AppearanceSource`. Cached per category, wiped on
---TRANSMOG_COLLECTION_UPDATED.
---@param category number  Enum.TransmogCollectionType
---@return WeaponAppearance[]
function ns.CosmeticAppearances(category)
  if _appearances[category] then return _appearances[category] end
  local out = {}
  for _, v in ipairs(GetCategoryAppearances(category) or {}) do
    out[#out + 1] = { visualID = v.visualID, isCollected = v.isCollected }
  end
  _appearances[category] = out
  return out
end

-- A newly collected shirt/tabard has to flip its isCollected on the next query. Additive to the
-- other TRANSMOG_COLLECTION_UPDATED handlers (commands.lua rescan, weaponbrowser cache wipe) —
-- registerEvent keeps a per-event handler list, so all three coexist.
ns:registerEvent("TRANSMOG_COLLECTION_UPDATED", function()
  _appearances = {}
end)
