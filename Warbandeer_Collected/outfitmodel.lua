---@type Warbandeer_Collected
local ns = select(2, ...)

-- Dressing a MODEL from an `itemTransmogInfoList` — one implementation, shared by the dressing room
-- (`DressingRoom:ApplyOutfit`, which mirrors the result onto its own composed-look fields
-- afterwards) and the outfit library window's preview pane (#699).
--
-- Split out of controls/DressingRoomOutfit.lua when the library window gained a model of its own:
-- the two were otherwise about to hold byte-identical copies of this loop, and a drift between them
-- would surface as a look that renders differently depending on which window you opened it from.
--
-- A file of its own rather than a home in outfit.lua purely for size — that file is already past the
-- budget — and it can't live in outfitlibrary.lua, which stays WoW-free so it can be unit-tested.

---@class Warbandeer_Collected
---@field DressModelFromList fun(model: Model, list: table[])

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
  model:Outfit({})

  for _, slotID in ipairs(ns.OutfitSlotOrder) do
    local info = list[slotID]
    local appearanceID = info and info.appearanceID or 0
    if appearanceID > 0 then
      model:SlotTransmog(slotID, appearanceID, {
        -- Only a real split-shoulder secondary is forwarded; the main-hand's -1/0 discriminator
        -- is meaningless to the model and would be read as an appearance id.
        secondaryAppearanceID = (slotID == INVSLOT_SHOULDER and info.secondaryAppearanceID > 0)
          and info.secondaryAppearanceID or nil,
        illusionID = (info.illusionID and info.illusionID > 0) and info.illusionID or nil,
      })
    end
  end
end
