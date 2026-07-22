---@type Warbandeer_Collected
local ns = select(2, ...)
local GetCategoryForItem = C_TransmogCollection.GetCategoryForItem
local DressingRoom = ns.DressingRoom

-- The room-coupled half of the outfit layer: turning what the dressing room is currently
-- showing into an `itemTransmogInfoList`, and dressing the room from one. Reopens the
-- DressingRoom class, like the other controls/DressingRoom*.lua files. The store wrappers and
-- validation are outfit.lua; the `/customset v1` codec is outfitcodec.lua.
--
-- An `itemTransmogInfoList` is a dense array indexed by INVENTORY SLOT ID, each entry an
-- ItemTransmogInfo carrying { appearanceID, secondaryAppearanceID, illusionID }. The field named
-- `appearanceID` holds an **itemModifiedAppearanceID** — a sourceID, not a visualID — which is
-- exactly what `_currentSources` and the look-builder's `_lookMH`/`_lookOH` already deal in, so
-- nothing needs converting on the way in or out.

---@class DressingRoom
---@field ComposeOutfit fun(self: DressingRoom): table[]
---@field ApplyOutfit fun(self: DressingRoom, list: table[]): DressingRoom
---@field ClearOutfitArmor fun(self: DressingRoom)

---Drop the per-slot overrides an applied outfit left on the model's ARMOR slots, so the next
---previewed set skins those slots itself.
---
---`Model` re-applies every SlotTransmog override after each async re-skin — that persistence is
---the whole point for the look builder, whose weapon picks are meant to outlive stepping between
---sets. But an applied outfit writes overrides across the armor slots too, and those must not
---survive: without this, `Dress()` re-skins to the new set and the stale outfit immediately
---repaints over it, slot by slot.
---
---Scoped by walking the paper-doll slot entries rather than a duplicated list of slot ids, so it
---tracks whatever the columns hold. Cosmetic entries (shirt/tabard) are skipped deliberately:
---like the weapons, they're the user's own composed-look picks, not something the previewed set
---supplies. Call before a re-skin — `ClearSlotTransmog` forgets the override but doesn't restrip
---the model in place.
function DressingRoom:ClearOutfitArmor()
  for _, e in ipairs(self._slots or {}) do
    if not e.cosmetic then self._model:ClearSlotTransmog(e.slotID) end
  end
end

---Everything the room is currently showing, as an outfit list.
---
---Composed from the room's own state rather than read back off the model
---(`actor:GetItemTransmogInfoList`): that keeps it deterministic — unaffected by where an async
---re-skin has got to — and it honours the per-slot toggles, since `_currentSources` already
---drops the slots the user switched off.
---@return table[]
function DressingRoom:ComposeOutfit()
  local list = ns.EmptyOutfitList()

  -- Armor comes from the previewed set. A weapon-cosmetic preview (group.kind) has a synthetic
  -- set id with no C_TransmogSets sources behind it, so there is no armor half to walk — its
  -- weapon lives in the look fields below like any other pick.
  if self._set and self._set.id and not (self._group and self._group.kind) then
    for _, src in ipairs(self:_currentSources()) do
      local slot = ns.SourceSlot(src)
      if slot then list[slot].appearanceID = src end
    end
  end

  -- Shirt and tabard are never set pieces — they only ever come from the cosmetic picker (#641),
  -- so they are read straight off the composed look. Absent until that lands, hence the `or 0`.
  list[INVSLOT_BODY].appearanceID   = self._lookShirt or 0
  list[INVSLOT_TABARD].appearanceID = self._lookTabard or 0

  local mh = list[INVSLOT_MAINHAND]
  mh.appearanceID = self._lookMH or 0
  mh.illusionID = self._lookIllusion or 0
  -- The main-hand secondary is a discriminator, not an appearance: -1 means "an ordinary
  -- weapon", 0 means "a paired Legion artifact, derive the off-hand from me". Getting this
  -- backwards makes the game invent an off-hand, so set it through the mixin rather than by hand
  -- — and only when a weapon is actually held, since an empty hand has nothing to discriminate
  -- and should stay at the empty list's 0.
  if self._lookMH then
    mh:ConfigureSecondaryForMainHand(
      GetCategoryForItem(self._lookMH) == Enum.TransmogCollectionType.Paired)
  end

  -- A two-handed main-hand occupies both hands, so the off-hand pick is suppressed exactly as it
  -- is on the model (#618) — the outfit records what is actually being worn, not what is parked.
  local oh = list[INVSLOT_OFFHAND]
  oh.appearanceID = (not self._lookMH2H and self._lookOH) or 0

  return list
end

-- A slot's appearance as the look fields want it: the sourceID, or nil for an empty slot. The
-- look fields are nil-or-a-sourceID (an empty slot must read as "nothing picked", not as
-- appearance 0), while the list uses 0 for empty — this is the one conversion between them.
---@param info table?  an ItemTransmogInfo from the list
---@return number?
local function pick(info)
  local appearanceID = info and info.appearanceID or 0
  return appearanceID > 0 and appearanceID or nil
end

-- Weapon categories that occupy both hands, borrowed from the look builder (WeaponPicker.lua
-- owns the list and explains why it has to be an explicit set rather than a flag test). Read at
-- call time so this file carries no load-order dependency on it.
---@param sourceID number
---@return boolean
local function isTwoHanded(sourceID)
  local twoHanded = DressingRoom._TWO_HANDED
  local category = sourceID and GetCategoryForItem(sourceID)
  return (twoHanded and category and twoHanded[category]) or false
end

---Dress the room from an outfit list — the inverse of ComposeOutfit.
---
---Every slot is driven through `SlotTransmog` over a bare body rather than through `Outfit`:
---`TryOn` drops an appearance the previewed character's class can't equip, while SlotTransmog
---renders any appearance on anyone (the same reason the look builder uses it), and it is
---re-applied per slot across the model's async re-skins so the outfit survives a race change.
---@param list table[]
---@return DressingRoom
function DressingRoom:ApplyOutfit(list)
  ns.SanitizeOutfit(list)

  -- Drop any override left over from a previous outfit or look, so slots this outfit leaves
  -- empty actually come out empty instead of inheriting the last one.
  for slot = 1, INVSLOT_LAST_EQUIPPED do self._model:ClearSlotTransmog(slot) end
  self._model:Outfit({})

  for _, slotID in ipairs(ns.OutfitSlotOrder) do
    local info = list[slotID]
    local appearanceID = info and info.appearanceID or 0
    if appearanceID > 0 then
      self._model:SlotTransmog(slotID, appearanceID, {
        -- Only a real split-shoulder secondary is forwarded; the main-hand's -1/0 discriminator
        -- is meaningless to the model and would be read as an appearance id.
        secondaryAppearanceID = (slotID == INVSLOT_SHOULDER and info.secondaryAppearanceID > 0)
          and info.secondaryAppearanceID or nil,
        illusionID = (info.illusionID and info.illusionID > 0) and info.illusionID or nil,
      })
    end
  end

  -- Mirror the outfit onto the composed-look fields so the weapon slots, the cosmetic slots and
  -- the picker's selection borders all show what is actually being worn.
  local mh = list[INVSLOT_MAINHAND]
  local illusionID = mh and mh.illusionID or 0
  self._lookMH        = pick(mh)
  self._lookIllusion  = illusionID > 0 and illusionID or nil
  self._lookOH        = pick(list[INVSLOT_OFFHAND])
  self._lookShirt     = pick(list[INVSLOT_BODY])
  self._lookTabard    = pick(list[INVSLOT_TABARD])
  self._lookMH2H      = isTwoHanded(self._lookMH) or nil

  self:UpdateWeaponSlots()
  self:UpdateCosmeticSlots()
  return self
end
