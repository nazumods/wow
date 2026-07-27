---@type Warbandeer_Collected
local ns = select(2, ...)

-- The WoW-side outfit helpers shared across the room, the transmogrifier and the library window —
-- dressing a MODEL from an `itemTransmogInfoList`, and stamping a look with who saved it (#699).
--
-- The dressing is one implementation shared by the dressing room (`DressingRoom:ApplyOutfit`, which
-- mirrors the result onto its own composed-look fields afterwards) and the library window's preview
-- pane.
--
-- Split out of controls/DressingRoomOutfit.lua when the library window gained a model of its own:
-- the two were otherwise about to hold byte-identical copies of this loop, and a drift between them
-- would surface as a look that renders differently depending on which window you opened it from.
--
-- A file of its own rather than a home in outfit.lua purely for size — that file is already past the
-- budget — and it can't live in outfitlibrary.lua, which stays WoW-free so it can be unit-tested.

---@class Warbandeer_Collected
---@field DressModelFromList fun(model: Model, list: table[])
---@field LocalOutfitMeta fun(list: table[]): OutfitMeta
---@field MainHandSecondary fun(sourceID: number): number

---The value a main hand's `secondaryAppearanceID` must carry: it is not an appearance there but a
---**discriminator**, `-1` for an ordinary weapon and `0` for half of a paired Legion artifact.
---
---Never leave it nil on a main hand. `ItemTransmogInfoMixin:Init` defaults nil to 0 — which IS
---"paired" — and a paired main hand overrides the off-hand, so a Titan's Grip pair renders as the
---off-hand alone. `ns.PairedArtifactWeapon` in outfit.lua carries the full rationale and Blizzard's
---own note on the override; it lives there rather than here because outfit.lua is closed to growth.
---
---Shared by both paths that dress a main hand — this file's `DressModelFromList` and the look
---builder's `_applyLook` — because having it in only one of them was #755: a look loaded from the
---library was flagged differently from the same look composed in the builder.
---@param sourceID number  the appearance being put in the main hand
---@return number  -1 individual, 0 paired
function ns.MainHandSecondary(sourceID)
  return ns.PairedArtifactWeapon(sourceID) and Constants.Transmog.MainHandTransmogIsPairedWeapon
    or Constants.Transmog.MainHandTransmogIsIndividualWeapon
end

---Dress `model` from an outfit list, replacing whatever it was showing.
---
---Every slot is driven through `SlotTransmog` over a bare body rather than through `Outfit`:
---`TryOn` drops an appearance the previewed character's class can't equip, while SlotTransmog
---renders any appearance on anyone (the same reason the look builder uses it), and it is re-applied
---per slot across the model's async re-skins so the outfit survives a race change.
---@param model Model
---@param list table[]
function ns.DressModelFromList(model, list)
  ns.SanitizeOutfit(list)

  -- Drop any override left over from a previous outfit or look, so slots this outfit leaves
  -- empty actually come out empty instead of inheriting the last one.
  for slot = 1, INVSLOT_LAST_EQUIPPED do model:ClearSlotTransmog(slot) end
  -- Reset the remembered list only — every slot is driven through SlotTransmog just below, so the
  -- actor needs no undressing here. This was `Outfit({})` until #754 gave Outfit a drop diff, under
  -- which an empty list means "undress everything the last outfit held" — a real strip this path
  -- never wanted, and a bare frame before the SlotTransmog writes land.
  model:ForgetOutfit()

  for _, slotID in ipairs(ns.OutfitSlotOrder) do
    local info = list[slotID]
    local appearanceID = info and info.appearanceID or 0
    if appearanceID > 0 then
      model:SlotTransmog(slotID, appearanceID, {
        -- One field name, two different meanings, so it is forwarded per slot: the SHOULDERS take a
        -- real split-shoulder secondary appearance, the MAIN HAND takes the paired-artifact
        -- discriminator, and every other slot forwards nothing. The main hand used to be left nil
        -- here on the stated grounds that the model would read it as an appearance id — untrue, and
        -- the reason a library-loaded look flagged every main hand as a paired artifact (#755).
        --
        -- `MainHandSecondary` returns -1 for an ordinary weapon and 0 for a paired one. Both are
        -- truthy in Lua, so the `or` chain carries them intact — note it must NOT be written as the
        -- `x > 0 and x or nil` idiom used above, which would drop both of the values that matter.
        --
        -- The shoulder side guards for nil: `SanitizeOutfit` only zeroes a secondary that fails
        -- validation, so a stored look predating the field still arrives without one.
        secondaryAppearanceID =
          (slotID == INVSLOT_SHOULDER and (info.secondaryAppearanceID or 0) > 0
            and info.secondaryAppearanceID)
          or (slotID == INVSLOT_MAINHAND and ns.MainHandSecondary(appearanceID))
          or nil,
        illusionID = (info.illusionID and info.illusionID > 0) and info.illusionID or nil,
      })
    end
  end
end

---Who saved a look, stamped at save time because none of it survives otherwise — a stored outfit is
---appearance ids and nothing else.
---
---`forClass` is deliberately absent. It answers "which class's set was this composed from", which
---only a set PREVIEW can know; a look staged at the transmogrifier, or imported from a game set,
---carries no such memory. `ns.FilterOutfits` reads a nil facet as "unknown, matches everything",
---which is the honest answer where a guess would hide the look behind a class it may have nothing
---to do with. The dressing room keeps its own `_outfitMeta` precisely because it CAN derive one.
---@param list table[]
---@return OutfitMeta
function ns.LocalOutfitMeta(list)
  local name, realm = UnitFullName("player")
  local _, class = UnitClass("player")
  return {
    char = realm and realm ~= "" and (name .. "-" .. realm) or name,
    class = class,
    armor = ns.OutfitArmorType(list),
  }
end
