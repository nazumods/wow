---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local GetItemIcon = C_Item.GetItemIconByID
local RequestItem = C_Item.RequestLoadItemDataByID
local DressingRoom = ns.DressingRoom
local k = DressingRoom._k
local SELECTED, IDLE = k.SELECTED, k.IDLE

-- What an armour slot IS right now, and what it looks like (#654). Split from the sibling
-- DressingRoomSlots.lua, which builds and fills the columns; this file owns the per-slot state
-- machine, the painting of all of its states, and the master Undress toggle that drives them in
-- bulk. Reopens the DressingRoom class.
--
-- **Three states, one gesture.** Left-clicking an armour slot cycles it:
--
--   worn  →  hidden  →  empty  →  worn
--
-- | state    | `_hiddenSlots` | composes as              | means                                    |
-- |----------|----------------|--------------------------|------------------------------------------|
-- | worn     | (absent)       | the set's piece          | the piece is on                          |
-- | hidden   | `"hidden"`     | the slot's hide visual   | explicitly hidden — a real appearance    |
-- | empty    | `"empty"`      | `0` (`NoTransmogID`)     | no transmog: equipped gear shows at a mog|
--
-- The first click means **hidden**, not empty, and that is the whole point of #654: the model
-- already renders a toggled-off slot as bare skin (`UndressSlot`), which is exactly what a hide
-- visual renders — so composing it as `0` saved and exported the *opposite* of what was on screen
-- (at a transmogrifier `0` shows whatever the character has equipped). Empty is still reachable,
-- one click further along, because "leave my equipped helm alone" is a real thing to want from an
-- outfit — it just isn't what turning a piece off in a preview means.
--
-- `_hiddenSlots` holds the state string rather than `true`, so every truthiness test over it —
-- `_currentSources`, `_anyWorn`, the dim below — keeps reading as "off the model" unchanged. Only
-- `ComposeOutfit` (controls/DressingRoomOutfit.lua) tells the two apart.
--
-- Both off-states render identically on the model, deliberately: the room previews a set on an
-- arbitrary race with no equipped gear to fall back to, so bare skin is the honest render for
-- "no transmog" as much as for "hidden". They differ on the paper doll, and in what they save.

-- The question-mark fallback icon. The slot-status green/red live on `ns` (DressingRoomLookSlots.lua)
-- — five files painted the same two colours from their own copies.
local QUESTION = 134400                    -- inv_misc_questionmark fileID
local DIM      = 0.30                      -- icon vertex value for a slot that isn't being worn

-- The two off-states, published for ComposeOutfit (the only other file that has to tell them apart).
local HIDDEN, EMPTY = "hidden", "empty"
k.HIDDEN, k.EMPTY = HIDDEN, EMPTY

-- Advance one step round the cycle. A slot whose category exposes no hide visual skips straight to
-- empty — the collection isn't always populated the moment the room opens, and degrading to the
-- old two-state toggle beats offering a state that would compose as nothing.
---@param state string?  the slot's current state
---@param hideable boolean  whether this slot has a hide visual to offer
---@return string?
local function nextState(state, hideable)
  if state == nil then return hideable and HIDDEN or EMPTY end
  if state == HIDDEN then return EMPTY end
  return nil
end

-- The tooltip's trailing hint: what this slot is, and what the next click does.
local HINT = {
  [HIDDEN] = "Hidden — click to leave the slot untransmogged instead",
  [EMPTY]  = "No transmog: your equipped gear shows — click to wear the piece",
}

---The hint line for `slotID`'s current state, or nil when there's no gesture to describe (outfit
---mode drives the slots off the applied list, not off the toggles).
---@param slotID number
---@return string?
function DressingRoom:_slotHint(slotID)
  if self._outfit then return nil end
  local state = self._hiddenSlots[slotID]
  if state then return HINT[state] end
  return ns.HideVisual(slotID) and "Click to hide this slot" or "Click to leave the slot untransmogged"
end

---Paint one armour slot for its current state — both the icon and the border, so a state change is
---a single call and `UpdateSlots` and the toggles can't drift apart. `UpdateSlots` resolves the
---set's piece into `e.itemID`/`e.collected` and delegates the rest here.
---@param e table  a slot entry from self._slots
---@return boolean missing  true when the piece's icon isn't cached yet, so the caller retries
function DressingRoom:_paintSlot(e)
  local state = self._hiddenSlots[e.slotID]
  if state == HIDDEN then
    -- The game's own Hidden Helm / Hidden Cloak / … art, so a hidden slot never reads as a greyed
    -- version of the piece it replaced. It comes from the appearance API rather than from item
    -- data, so there is nothing to stream and nothing to retry.
    local _, icon = ns.HideVisual(e.slotID)
    e.icon:Texture(icon or ui.media.unresolved)
    e.icon:SetVertexColor(1, 1, 1, 1)
    e.icon:Show()
    e.border:Color(IDLE)
    return false
  end

  local missing = false
  if e.itemID then
    local tex = GetItemIcon(e.itemID)
    if not tex then RequestItem(e.itemID); missing = true end
    e.icon:Texture(tex or QUESTION)
    -- Green/red is the piece's collected status, and only worn slots are making a claim about the
    -- piece; an emptied one has stepped out of the way, so it drops to idle like a slot with
    -- nothing in it.
    e.border:Color(state and IDLE or (e.collected and ns.slotOK or ns.slotMissing))
  else
    -- No piece for this slot in the set: the "nothing here" marker — and the same outfit value
    -- (`0`) an explicitly emptied slot composes to, which is why the two look alike.
    e.icon:Texture(ui.media.unresolved)
    e.border:Color(IDLE)
  end
  local v = state and DIM or 1
  e.icon:SetVertexColor(v, v, v, 1)
  e.icon:Show()
  return missing
end

---Cycle a slot through worn → hidden → empty, applied in place (no full model reload).
---@param e table  a slot entry from self._slots
function DressingRoom:ToggleSlot(e)
  -- Outfit mode has no per-slot toggles: the armour on the model came from an applied list, while
  -- `_set` still points at the last set clicked in the grid — so `_currentSources()` below would
  -- re-dress the model with a set that isn't on screen. Preview a set again to get the toggles back.
  if self._outfit then return end
  local state = nextState(self._hiddenSlots[e.slotID], ns.HideVisual(e.slotID) ~= nil)
  self._hiddenSlots[e.slotID] = state
  -- Re-set the remembered outfit (re-adds a re-shown piece via TryOn), then strip the one slot for
  -- either off-state — TryOn alone can't remove an already-worn piece.
  self._model:Outfit(self:_currentSources())
  if state then self._model:UndressSlot(e.slotID) end
  self:_paintSlot(e)
  self:_syncUndressBorder()
end

-- Repaint every armour slot from `_hiddenSlots` (after a master show/hide) without re-resolving
-- the set's pieces. Cosmetic slots have no state of their own, so they're never touched.
function DressingRoom:_refreshSlotStates()
  for _, e in ipairs(self._slots) do
    if not e.cosmetic then self:_paintSlot(e) end
  end
end

-- Master show/hide: the Undress button is just a bulk per-slot toggle — hide every
-- piece-bearing slot when anything's worn, else restore all.
function DressingRoom:ToggleUndress()
  self:SetUndressed(self:_anyWorn())
end

---@param undressed boolean  true to strip every slot off the model, false to restore all
function DressingRoom:SetUndressed(undressed)
  for _, e in ipairs(self._slots) do
    -- Cosmetic slots have no per-slot toggle and aren't set pieces, so they take no _hiddenSlots
    -- entry; the composed look re-applies them below.
    --
    -- HIDDEN rather than EMPTY: "show me the bare race" is what the button says and what the eye
    -- then sees, and hidden is the outfit value that means that. Saving from here writes a
    -- deliberately hidden look, not an empty one.
    if e.itemID and not e.cosmetic then self._hiddenSlots[e.slotID] = undressed and HIDDEN or nil end
  end
  -- Apply in place (no reload): re-set the outfit (redress re-adds every piece via
  -- TryOn), then bare the whole body when undressing — TryOn alone can't strip.
  --
  -- Undress bares EVERYTHING, the composed look included: Model:Undress strips the slots set
  -- through SetItemTransmogInfo along with the armor, which is what "show the bare race" should
  -- mean. But the re-dress path only re-TryOns the outfit's sources and never re-asserts those
  -- per-slot overrides, so without the _applyLook here the weapons, illusion, shirt and tabard
  -- stay gone until the next model re-skin happens to restore them (#650).
  --
  -- Tracked explicitly rather than derived from `_anyWorn()`: hiding every armor slot one at a
  -- time leaves the composed look genuinely ON the model (ToggleSlot's UndressSlot only bares its
  -- own armor slot), so only this master toggle may grey the weapon/cosmetic icons.
  self._undressed = undressed or nil
  self._model:Outfit(self:_currentSources())
  if undressed then self._model:Undress() else self:_applyLook() end
  self:_refreshSlotStates()
  -- The composed-look slots have no _hiddenSlots entry, so _refreshSlotStates doesn't reach them —
  -- repaint them here so their icons grey with the armor instead of still reading as worn.
  self:UpdateLookSlots()
  self:_syncUndressBorder()
end

-- True while at least one piece-bearing slot is still worn. Cosmetic slots don't count: the
-- Undress button is the master switch for the previewed SET's pieces, and a picked shirt would
-- otherwise keep it reading "something is worn" with the whole set hidden.
---@return boolean
function DressingRoom:_anyWorn()
  for _, e in ipairs(self._slots) do
    if e.itemID and not e.cosmetic and not self._hiddenSlots[e.slotID] then return true end
  end
  return false
end

-- Light the Undress button while nothing is worn (the master toggle is just "every slot off"),
-- idle while anything is.
function DressingRoom:_syncUndressBorder()
  self._undressBorder:Color(self:_anyWorn() and IDLE or SELECTED)
end
