---@type Warbandeer_Collected
local ns = select(2, ...)
local GetCategoryForItem = C_TransmogCollection.GetCategoryForItem
local GetSourceInfo = C_TransmogCollection.GetSourceInfo
local GetItemIcon = C_Item.GetItemIconByID
local RequestItem = C_Item.RequestLoadItemDataByID
local C_Timer = C_Timer
local DressingRoom = ns.DressingRoom
-- The one slot state this file has to tell apart from the others — a hidden slot composes as its
-- hide visual, an empty one as 0 (DressingRoomSlotStates.lua owns the cycle).
local HIDDEN = DressingRoom._k.HIDDEN
-- Slot status colors, matching the armor columns' green/red (DressingRoomSlotStates.lua owns the
-- originals; outfit mode paints the same slots, so it has to agree with them).
local OUTFIT_GREEN = {0, 104/255, 55/255, 1}
local OUTFIT_RED   = {165/255, 0, 38/255, 1}

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
---@field EnterOutfitMode fun(self: DressingRoom, name: string, list: table[])
---@field UpdateSlotsFromOutfit fun(self: DressingRoom, retry: boolean?)

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
---drops the slots the user switched off. Which of the two off-states each of those is in decides
---what it composes as: see the hidden pass below.
---@return table[]
function DressingRoom:ComposeOutfit()
  local list = ns.EmptyOutfitList()

  -- Armor comes from whatever the room is actually SHOWING, which is not always the previewed set:
  -- in outfit mode (`self._outfit`) the armor on the model came from a loaded look, while `_set`
  -- still points at the last set clicked in the grid. Reading `_set` there composed a different
  -- outfit than the one on screen — and since Save overwrites the selected entry with this list, it
  -- silently replaced a loaded look with the stale set's armor. Per-slot toggles are honoured in
  -- both modes.
  --
  -- A browsed weapon needs no case of its own: it's a pick in the composed look, so the look fields
  -- below carry it exactly as a look-builder pick, whichever branch the armour comes from (#673).
  if self._outfit then
    for _, slotID in ipairs(ns.OutfitSlotOrder) do
      local info = self._outfit[slotID]
      local appearanceID = info and info.appearanceID or 0
      -- The look fields below own the weapon and cosmetic slots in both modes; taking them from the
      -- applied list too would overwrite a pick made since it was loaded.
      if appearanceID > 0 and not self._hiddenSlots[slotID]
        and slotID ~= INVSLOT_MAINHAND and slotID ~= INVSLOT_OFFHAND
        and slotID ~= INVSLOT_BODY and slotID ~= INVSLOT_TABARD then
        list[slotID].appearanceID = appearanceID
        list[slotID].secondaryAppearanceID = info.secondaryAppearanceID or 0
      end
    end
  elseif self._set and self._set.id then
    for _, src in ipairs(self:_currentSources()) do
      local slot = ns.SourceSlot(src)
      if slot then list[slot].appearanceID = src end
    end
  end

  -- **Hidden is not empty** (#654). Both branches above leave a slot the user switched off at the
  -- empty list's `0` — `Constants.Transmog.NoTransmogID`, which at a transmogrifier renders whatever
  -- the character has EQUIPPED. That's the opposite of the bare slot the preview was showing, so a
  -- slot in the `hidden` state is written as its own hide visual instead: a real appearance with a
  -- real sourceID, which renders nothing wherever the look is applied. The `empty` state is the one
  -- that genuinely means `0`, and it keeps the value both branches already left.
  --
  -- Only armour slots reach here: the cosmetic and weapon slots never take a `_hiddenSlots` entry,
  -- and the look fields below own them regardless.
  for slotID, state in pairs(self._hiddenSlots) do
    if state == HIDDEN then
      local hide = ns.HideVisual(slotID)
      if hide then
        list[slotID].appearanceID = hide
        list[slotID].secondaryAppearanceID = 0
      end
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
    mh:ConfigureSecondaryForMainHand(ns.PairedArtifactWeapon(self._lookMH))
  end

  -- A main-hand with no room for an off-hand suppresses that pick exactly as it is suppressed on
  -- the model (#618, #661) — the outfit records what is actually being worn, not what is parked.
  -- A Titan's Grip pairing is worn, so it is recorded.
  local oh = list[INVSLOT_OFFHAND]
  oh.appearanceID = (not self._lookNoOH and self._lookOH) or 0

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

-- Whether a loaded look's main-hand leaves no room for an off-hand, so `_lookNoOH` can be
-- re-derived for a look this file didn't compose. viewsync.lua owns the category sets and explains
-- why they have to be explicit lists rather than a capability-flag test.
--
-- A loaded Titan's Grip look answers false here, so its off-hand comes back live rather than
-- greyed — which is what makes a saved 2H+2H look survive a round-trip (#661).
---@param sourceID number
---@return boolean
local function suppressesOffHand(sourceID)
  return ns.SuppressesOffHand(sourceID and GetCategoryForItem(sourceID))
end

---Dress the room from an outfit list — the inverse of ComposeOutfit.
---
---The model dressing itself is `ns.DressModelFromList` (outfitmodel.lua), shared with the library
---window's preview pane so the two can't drift. What stays here is the room-specific half: mirroring
---the result onto the composed-look fields.
---@param list table[]
---@return DressingRoom
function DressingRoom:ApplyOutfit(list)
  ns.DressModelFromList(self._model, list)

  -- Mirror the outfit onto the composed-look fields so the weapon slots, the cosmetic slots and
  -- the picker's selection borders all show what is actually being worn.
  local mh = list[INVSLOT_MAINHAND]
  local illusionID = mh and mh.illusionID or 0
  self._lookMH        = pick(mh)
  self._lookIllusion  = illusionID > 0 and illusionID or nil
  self._lookOH        = pick(list[INVSLOT_OFFHAND])
  self._lookShirt     = pick(list[INVSLOT_BODY])
  self._lookTabard    = pick(list[INVSLOT_TABARD])
  self._lookNoOH      = suppressesOffHand(self._lookMH) or nil

  self:UpdateWeaponSlots()
  self:UpdateCosmeticSlots()
  return self
end

-- ── Outfit mode ────────────────────────────────────────────────────────────────--
--
-- A loaded custom set is a look that is NOT a `ns.Sets` entry, so the room can't drive its armor
-- columns off `self._set` the way `UpdateSlots` does: `self._outfit` holds the applied list, the
-- armor slots render from THAT, and everything keyed to a set id (rank buttons, Wanted, the id
-- label, the class icon, the difficulty tier bars) is hidden because an outfit has no set to rate.
-- Previewing any set again runs `_load`, which clears the mode.
--
-- This is the room's ONE alternate mode now. The weapon-cell preview used to be a second — `_load`
-- branched on `group.weaponCell` and rendered a bare body — until #673 made a browsed weapon an
-- ordinary pick in the composed look, on the same doll, needing no mode at all.

---Show a loaded custom set: apply it, retitle to the set's name, and swap the room into
---outfit mode. `_load` is the only way back out.
---@param name string
---@param list table[]
function DressingRoom:EnterOutfitMode(name, list)
  self:ApplyOutfit(list)
  self._outfit = list
  -- A loaded look replaces the weapons too (ApplyOutfit writes them into the look fields), so the
  -- browsed cell goes with the doll it was on: leaving it would dock a chooser whose highlighted row
  -- names a weapon the model isn't holding, and point ↑/↓ at it. Both grid cursors clear below for
  -- the same reason — a loaded look belongs to neither.
  self._cell = nil
  self._cellHand = nil
  self._focus = "armor"
  self:Title(name)
  self._idLabel:Text("")
  self._masterName = nil
  -- A loaded look isn't one of the tracked sets, but it does have a class, so the title-bar class
  -- icon and the class-themed backdrop stay meaningful here instead of blanking to a plain dark
  -- room (#699).
  --
  -- **`forClass` wins over `class`.** The two answer different questions — what the look is FOR
  -- versus who saved it — and it is the former this backdrop illustrates: a Death Knight can
  -- compose a Druid look, and it's the Druid view that belongs behind it. `class` is the fallback
  -- rather than the primary because `forClass` is unrecoverable for a set imported from the game or
  -- a look saved at the transmogrifier, where only the saving character is knowable.
  --
  -- Entries predating #655 carry no provenance at all, and a pasted name may not be in the library;
  -- both fall back to nil, which is exactly the old behaviour. The expansion badge is left alone.
  local entry = ns.LibraryOutfit(name)
  self:_showClass(entry and ns.ClassId(entry.forClass or entry.class))
  self._tierBarL:Hide()
  self._tierBarR:Hide()
  if self._ratingsBoxes then for _, b in ipairs(self._ratingsBoxes) do b:Hide() end end
  if self._wantBox then self._wantBox:Hide() end
  self:HideCellChooser()
  self:UpdateSlotsFromOutfit()
  self:_syncUndressBorder()
  -- Both grids clear their cursor: what's on screen is no longer one of their cells.
  ns:NotifyDressedSetChanged(nil)
  ns:NotifyDressedWeaponCellChanged(nil, nil)
end

---Fill the armor slots from the applied outfit instead of from a previewed set — the outfit-mode
---counterpart of `UpdateSlots`. Same icon/status/retry behaviour, but each slot reads its
---appearance straight out of the list. Cosmetic slots are skipped as ever (UpdateCosmeticSlots
---owns them, and ApplyOutfit already fed them from the same list).
---@param retry boolean?  internal: true on the self-scheduled re-run
function DressingRoom:UpdateSlotsFromOutfit(retry)
  local list = self._outfit
  if not list then return end
  if not retry then self._outfitRetries = 0 end
  local missing = false
  for _, e in ipairs(self._slots or {}) do
    if not e.cosmetic then
      local info = list[e.slotID]
      local appearanceID = info and info.appearanceID or 0
      local src = appearanceID > 0 and GetSourceInfo(appearanceID) or nil
      if src and src.itemID then
        e.itemID = src.itemID
        local tex = GetItemIcon(src.itemID)
        if not tex then RequestItem(src.itemID); missing = true end
        e.icon:Texture(tex or ns.ui.media.unresolved)
        e.icon:Show()
        -- A hidden slot carries a real appearance, but it isn't a set PIECE — paint it idle, as
        -- the preview's own hidden state does, rather than claiming a collected/missing status for
        -- the Hidden item. Its icon is already the game's Hidden art, straight off the source.
        e.border:Color(ns.IsHideVisual(e.slotID, appearanceID) and DressingRoom._k.IDLE
          or (src.isCollected and OUTFIT_GREEN or OUTFIT_RED))
      else
        -- Empty slot in the outfit: the same "nothing here" marker an unused set slot shows.
        e.itemID = nil
        e.icon:Texture(ns.ui.media.unresolved)
        e.icon:Show()
        e.border:Color(DressingRoom._IDLE)
      end
      e.icon:SetVertexColor(1, 1, 1, 1)   -- outfit mode has no per-slot state cycle to dim for
    end
  end

  if self._outfitTimer then self._outfitTimer:Cancel(); self._outfitTimer = nil end
  if missing and (self._outfitRetries or 0) < 10 then
    self._outfitRetries = (self._outfitRetries or 0) + 1
    self._outfitTimer = C_Timer.NewTimer(0.2, function()
      self._outfitTimer = nil
      self:UpdateSlotsFromOutfit(true)
    end)
  end
end
