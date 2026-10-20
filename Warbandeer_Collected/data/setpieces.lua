---@type Warbandeer_Collected
local ns = select(2, ...)
local GetAllSourceIDs = C_TransmogSets.GetAllSourceIDs
local GetSourcesForSlot = C_TransmogSets.GetSourcesForSlot
local GetSourceInfo = C_TransmogCollection.GetSourceInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant

-- A set's pieces by paper-doll slot, read from its appearance sources. Shared by the scan
-- (commands.lua), the dressing-room slots, model and outfit composer, and the hover InfoTip.
--
-- **A set id the client doesn't know is normal, not an error.** `GetAllSourceIDs` returns nil for
-- it rather than an empty table: an upcoming PTR set on a live client, and on WoW: Forever every
-- Retail set the curated tables name (#989 — `/collected scan` died here on Retail set 853).
-- `SetSourceIDs` (and so `SetSlotPieces`) and `SetSlotSources` read that as "no pieces", so a
-- caller sees an empty result and moves on.

-- Equip-location string → paper-doll slot id, for bucketing a set's pieces by item
-- when the per-slot source API yields nothing (see ns.SetSlotPieces). Cloak folds
-- into the Back slot; robes into Chest.
local EQUIP_SLOT = {
  INVTYPE_HEAD = 1, INVTYPE_SHOULDER = 3, INVTYPE_CLOAK = 15,
  INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_WAIST = 6,
  INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
}

---@class Warbandeer_Collected
---@field SetSourceIDs fun(setID: number): number[]
---@field SetSlotSources fun(setID: number, slot: number): table[]
---@field SetSlotPieces fun(setID: number): table<number, { itemID: number, isCollected: boolean }>
---@field SourceSlot fun(sourceID: number): number?

---A set's appearance source ids; empty (never nil) for a set id this client doesn't have.
---@param setID number
---@return number[]
function ns.SetSourceIDs(setID)
  return GetAllSourceIDs(setID) or {}
end

---One slot's appearance sources for a set (`C_TransmogSets.GetSourcesForSlot`); empty (never nil)
---for a set id this client doesn't have.
---@param setID number
---@param slot number  inventory slot id
---@return table[]
function ns.SetSlotSources(setID, slot)
  return GetSourcesForSlot(setID, slot) or {}
end

-- Bucket a set's appearance sources into paper-doll slots by each piece's equip
-- location, with collected status + itemID from GetSourceInfo. A fallback for sets
-- (e.g. Trading Post recolors) where C_TransmogSets.GetSourcesForSlot returns
-- nothing per slot even though GetAllSourceIDs still has all the pieces (and the
-- model wears them). Shared by the scan, the dressing-room slots and the hover InfoTip.
---@param setID number
---@return table<number, { itemID: number, isCollected: boolean }>  keyed by slot id
function ns.SetSlotPieces(setID)
  local out = {}
  for _, sourceID in ipairs(ns.SetSourceIDs(setID)) do
    local info = GetSourceInfo(sourceID)
    local itemID = info and info.itemID
    local loc = itemID and select(4, GetItemInfoInstant(itemID))
    local slot = loc and EQUIP_SLOT[loc]
    if slot then out[slot] = { itemID = itemID, isCollected = info.isCollected } end
  end
  return out
end

-- Resolve a single appearance source to its paper-doll slot id (nil if it maps to
-- no shown slot — e.g. a weapon). Lets Dress drop the sources of slots the user has
-- toggled off. Same equip-location mapping as ns.SetSlotPieces, one source at a time.
---@param sourceID number
---@return number?
function ns.SourceSlot(sourceID)
  local info = GetSourceInfo(sourceID)
  local itemID = info and info.itemID
  local loc = itemID and select(4, GetItemInfoInstant(itemID))
  return loc and EQUIP_SLOT[loc]
end
