---@type Warbandeer_Collected
local ns = select(2, ...)
local Enum = Enum
local GetCategoryAppearances = C_TransmogCollection.GetCategoryAppearances
local GetAppearanceSourceInfo = C_TransmogCollection.GetAppearanceSourceInfo

-- Per-slot **hide visuals** (#654) — the "Hidden Helm" / "Hidden Cloak" / … appearances, looked up
-- once per slot and cached. A sibling of data/cosmeticbrowser.lua, which already carries the same
-- `isHideVisual` flag for the two cosmetic slots; this generalises it to the whole paper doll.
--
-- **Hidden is not empty.** In an `itemTransmogInfoList`, `appearanceID = 0`
-- (`Constants.Transmog.NoTransmogID`) means "no transmog on this slot" — at a transmogrifier that
-- renders whatever the character has equipped. Hidden is a real appearance with a real sourceID,
-- and renders nothing. Two different values, opposite visual results, so a slot the user hid in the
-- preview has to save and export as the hide visual, never as 0.
--
-- Every one of the eleven armour categories exposes one (measured in game, #642), so hiding is
-- offered uniformly across the paper doll with no per-slot exceptions. Nothing at category 12+
-- carries the flag — weapons can't be hidden, and "no illusion" is a separate flag `ns.Illusions`
-- already filters out.
--
-- Blizzard drops hide visuals from its wardrobe grid entirely
-- (`WardrobeItemsCollectionMixin:FilterVisuals`) and offers hiding through a separate control; the
-- dressing room's own control is the three-state slot toggle (controls/DressingRoomSlotStates.lua).

-- Inventory slot id → the appearance category whose hide visual empties that slot.
local HIDE_CATEGORY = {
  [INVSLOT_HEAD]     = Enum.TransmogCollectionType.Head,
  [INVSLOT_SHOULDER] = Enum.TransmogCollectionType.Shoulder,
  [INVSLOT_BACK]     = Enum.TransmogCollectionType.Back,
  [INVSLOT_CHEST]    = Enum.TransmogCollectionType.Chest,
  [INVSLOT_BODY]     = Enum.TransmogCollectionType.Shirt,
  [INVSLOT_TABARD]   = Enum.TransmogCollectionType.Tabard,
  [INVSLOT_WRIST]    = Enum.TransmogCollectionType.Wrist,
  [INVSLOT_HAND]     = Enum.TransmogCollectionType.Hands,
  [INVSLOT_WAIST]    = Enum.TransmogCollectionType.Waist,
  [INVSLOT_LEGS]     = Enum.TransmogCollectionType.Legs,
  [INVSLOT_FEET]     = Enum.TransmogCollectionType.Feet,
}

local _cache = {}   -- [slotID] = { sourceID, icon } — successes only, see below

---@class Warbandeer_Collected
---@field HideVisual fun(slotID: number): number?, number?
---@field IsHideVisual fun(slotID: number, sourceID: number?): boolean

---The appearance that hides `slotID`, as a sourceID plus its icon — nil for a slot that has no
---hide visual (a weapon, a ring, anything outside the paper doll).
---
---Cached per slot, but **only on success**: the appearance collection isn't necessarily populated
---the first time this is asked (a fresh login), and caching that miss would leave the slot
---permanently un-hideable for the session. A miss is cheap to repeat and self-heals.
---@param slotID number  inventory slot id
---@return number? sourceID, number? icon
function ns.HideVisual(slotID)
  local hit = _cache[slotID]
  if hit then return hit.sourceID, hit.icon end
  local category = HIDE_CATEGORY[slotID]
  if not category then return nil end
  for _, v in ipairs(GetCategoryAppearances(category) or {}) do
    if v.isHideVisual then
      -- One resolver for every category — the same one the cosmetic picker resolves its own
      -- Hidden Shirt / Hidden Tabard rows through.
      local src = ns.AppearanceSource(v.visualID)
      if src then
        local info = GetAppearanceSourceInfo(src.sourceID)
        local entry = { sourceID = src.sourceID, icon = info and info.icon }
        _cache[slotID] = entry
        return entry.sourceID, entry.icon
      end
    end
  end
end

---Whether `sourceID` is the appearance that hides `slotID` — the read side of the same lookup, for
---telling a deliberately hidden slot apart from a real piece sitting in it.
---@param slotID number
---@param sourceID number?
---@return boolean
function ns.IsHideVisual(slotID, sourceID)
  if not sourceID or sourceID == 0 then return false end
  return sourceID == ns.HideVisual(slotID)
end
