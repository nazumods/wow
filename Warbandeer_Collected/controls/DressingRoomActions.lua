---@type Warbandeer_Collected
local ns = select(2, ...)
local DressingRoom = ns.DressingRoom

-- Race / form selection, the ratings row behaviour, set-load, and tier/class
-- navigation. Reopens the DressingRoom class. (Dress + class/expansion/backdrop
-- rendering live in DressingRoomModel.lua.)
local k = DressingRoom._k
local SELECTED, IDLE = k.SELECTED, k.IDLE

-- Move the gold selection border to raceID, clearing the previous one.
---@param raceID number
function DressingRoom:_highlightRace(raceID)
  if self._raceID and self._race[self._raceID] then self._race[self._raceID].border:Color(IDLE) end
  if self._race[raceID] then self._race[raceID].border:Color(SELECTED) end
end

-- The race's resolved RaceModels entry for the current form (multi-form races
-- read through the selected form; single-form races are the entry itself).
---@return table?
function DressingRoom:_resolvedForm()
  local entry = ns.RaceModels[self._raceID]
  return entry and (entry.forms and entry.forms[self._form] or entry)
end

---@param raceID number
function DressingRoom:SetRace(raceID)
  if self._raceID == raceID then return end
  self:_highlightRace(raceID)
  self._raceID = raceID
  self:_setupForms(ns.RaceModels[raceID])
  self:Dress()
  self:_refreshRatings()   -- per-race override display tracks the selected race
end

-- Highlight the active form button (gold), the rest idle.
---@param i number
function DressingRoom:_highlightForm(i)
  for j, b in ipairs(self._formButtons) do b.border:Color(j == i and SELECTED or IDLE) end
end

-- Show form-toggle buttons for the selected race's alternate forms (Worgen always;
-- Dracthyr only for a Dracthyr player, see selfFormOnly); hide the row otherwise.
-- Resets to the first (native) form.
---@param entry table?  the race's RaceModels entry
function DressingRoom:_setupForms(entry)
  local forms = entry and entry.forms
  -- `selfFormOnly` entries (Dracthyr) carry an altered form (visage) that only textures
  -- for the actual race, so the toggle is hidden unless the player is previewing their own
  -- race + has an alternate form. The buttons hide but `forms` still drives form 1 (the
  -- native form, which renders for everyone), so others just see the default body.
  local show = forms and (not entry.selfFormOnly or self:_isSelfWithAltForm())
  for i, b in ipairs(self._formButtons) do
    local f = show and forms[i]
    if f then b.label:Text(f.name); b.box:Show() else b.box:Hide() end
  end
  self._form = 1
  if show then self:_highlightForm(1) end
end

-- True when the selected race is the player's own and the player has an alternate form
-- (Worgen/Dracthyr) — the only case where the altered form renders textured.
---@return boolean
function DressingRoom:_isSelfWithAltForm()
  local _, _, playerRace = UnitRace("player")
  return self._raceID == ns.CanonRace(playerRace) and (C_PlayerInfo.GetAlternateFormInfo()) or false
end

---@param i number  index into the selected race's forms array
function DressingRoom:SetForm(i)
  if self._form == i then return end
  self._form = i
  self:_highlightForm(i)
  self:Dress()
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
    if e.itemID and not e.cosmetic then self._hiddenSlots[e.slotID] = undressed or nil end
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
  self:_refreshSlotDims()
  -- The composed-look slots have no _hiddenSlots entry, so _refreshSlotDims doesn't reach them —
  -- repaint them here so their icons grey with the armor instead of still reading as worn.
  self:UpdateWeaponSlots()
  self:UpdateCosmeticSlots()
  self:_syncUndressBorder()
end

-- ── Ratings ────────────────────────────────────────────────────────────────--

-- Sync the ratings row to the current set, race, and edit layer: the wanted star,
-- and the gold highlight on the active tier (the per-race override when "This race"
-- is on, else the baseline). Called from _load (set change) and SetRace.
function DressingRoom:_refreshRatings()
  if not self._set then return end
  -- Weapon-cell: only the ★ Wanted button applies (no S–F rank), keyed to the shown look.
  if self._group and self._group.weaponCell then
    local look = self._set._looks[self._weaponPiece or 1]
    self._wantedBorder:Color(look and ns:IsWeaponWanted(look.visualID) and SELECTED or IDLE)
    return
  end
  local setId = self._set.id
  self._wantedBorder:Color(ns:IsWanted(setId) and SELECTED or IDLE)
  local shown
  if self._raceOnly then shown = ns:RaceRank(setId, self._raceID)
  else shown = ns:BaselineRank(setId) end
  for letter, b in pairs(self._rankBtns) do
    b.border:Color(letter == shown and SELECTED or IDLE)
  end
end

-- Reflect a rating change in every registered grid right away (Collected's window
-- + Warbandeer's collected view), wherever the dressing room was opened from.
function DressingRoom:_ratingsChanged()
  ns:NotifyRatingsChanged()
end

function DressingRoom:ToggleWanted()
  if not self._set then return end
  -- Weapon-cell: flag the CURRENTLY-SHOWN look (its visualID), not a set id.
  if self._group and self._group.weaponCell then
    local look = self._set._looks[self._weaponPiece or 1]
    if look then ns:ToggleWeaponWanted(look.visualID) end
    self:_refreshRatings()
    self:_ratingsChanged()
    if self._cellList then self._cellList:Refresh() end   -- the chooser row's ★ tracks it
    return
  end
  ns:ToggleWanted(self._set.id)
  self:_refreshRatings()
  self:_ratingsChanged()
end

-- Set the tier (or clear it when nil, or when re-clicking the active one). Writes
-- the per-race override while "This race" is on, else the baseline.
---@param letter string?  a tier from ns.Ranks, or nil to clear
function DressingRoom:SetRank(letter)
  if not self._set then return end
  local setId = self._set.id
  if self._raceOnly then
    if ns:RaceRank(setId, self._raceID) == letter then letter = nil end
    ns:SetRaceRank(setId, self._raceID, letter)
  else
    if ns:BaselineRank(setId) == letter then letter = nil end
    ns:SetBaselineRank(setId, letter)
  end
  self:_refreshRatings()
  self:_ratingsChanged()
end

---@param on boolean  edit/display the per-race override instead of the baseline
function DressingRoom:SetRaceOnly(on)
  self._raceOnly = on
  self._raceOnlyBorder:Color(on and SELECTED or IDLE)
  self:_refreshRatings()
end

-- Preview a specific set within a group: refresh the title, class icon, slots and
-- model. Shared by ShowDressingRoom (initial open) and Step (navigation).
---@param group table  a group entry from ns.Sets
---@param set table    a set entry within that group
function DressingRoom:_load(group, set)
  self._group = group
  self._set = set
  wipe(self._hiddenSlots)   -- per-set toggles: each set opens fully dressed
  self._undressed = nil     -- …including the master Undress state
  -- An applied outfit (ApplyOutfit / `/collected outfit import`) leaves per-slot overrides that
  -- the model re-asserts after every re-skin. Drop the armor ones here — before the Dress() below
  -- — or they'd repaint over whatever set is being loaded. Unconditional: a weapon-cosmetic
  -- preview renders a bare body, so stale armor would show up there too. The composed look's
  -- weapons/cosmetics are deliberately left alone; they outlive a set change.
  self:ClearOutfitArmor()
  self:Title(set.name)
  -- Set id (right of the title) + its hover tooltip = the master-grid group name.
  self._masterName = group.name
  self._idLabel:Text(tostring(set.id or ""))
  -- Class = the set's position in the (positional) group.sets array.
  local classId
  for i = 1, #group.sets do if group.sets[i] == set then classId = i; break end end
  -- A weapon-source cell isn't class-specific: hide the class icon/backdrop and the armor ratings
  -- row (weapons get per-look Wanted next, not the S–F rank row).
  if group.weaponCell then classId = nil end
  self._classIndex = classId
  if self._ratingsBoxes then for _, b in ipairs(self._ratingsBoxes) do b:SetShown(not group.weaponCell) end end
  self:_showClass(classId)
  self:_showRelease(group.release)
  if group.kind then
    -- Weapon-cosmetic preview: no armor slots, no weapon slots, no difficulty tier bars (its own
    -- held-weapon render is the focus). Close the look builder and up/down nav cycles the cell's
    -- pieces from the first (see _stepWeaponPiece).
    self._weaponPiece = 1
    self:_showSlots(false)
    self:_showWeaponSlots(false)
    self._tierBarL:Hide()
    self._tierBarR:Hide()
    if self._slotTimer then self._slotTimer:Cancel(); self._slotTimer = nil end
    if self._weaponSlotTimer then self._weaponSlotTimer:Cancel(); self._weaponSlotTimer = nil end
    if self._cosmeticSlotTimer then self._cosmeticSlotTimer:Cancel(); self._cosmeticSlotTimer = nil end
    if self._picker then self:TogglePicker(false) end
    -- A weapon-source cell shows the chooser (its looks); illusion/arsenal don't.
    if group.weaponCell then self:ShowCellChooser(set._looks) else self:HideCellChooser() end
  else
    self:_showSlots(true)
    self:_showWeaponSlots(true)
    self:_setTierBars(group.name)
    self._slotRetries = 0
    self:UpdateSlots()
    self:UpdateWeaponSlots()     -- reflect any persisted look on the bottom weapon slots
    self:UpdateCosmeticSlots()   -- …and on the shirt/tabard slots (also carried across sets)
    self:HideCellChooser()
  end
  self:Dress()
  self:_syncUndressBorder()   -- wiped toggles → fully worn → Undress button idle
  self:_refreshRatings()
  -- Every previewed-set change funnels through here (open + Step/StepTier arrow nav),
  -- so broadcast it once from this choke point; the grids cursor the matching cell.
  -- classId (the set's class column) is passed too: PvP sets share a base setId across
  -- classes, so it's needed to pick the right column.
  ns:NotifyDressedSetChanged(set.id, classId)
  -- Parallel broadcast for the Weapons grid: a weapon cell carries no setId, so the line
  -- above clears armour grids; this boxes the (source, type) cell — nil for an armour set
  -- so the weapon grid clears instead. Covers open + ←/→ type-stepping (both re-enter here).
  ns:NotifyDressedWeaponCellChanged(group.weaponCell and group._source or nil,
                                    group.weaponCell and group._type or nil)
  -- Keep an open look-builder scoped to the previewed set's class. Only on an actual class change
  -- (a Step across columns) — a same-class StepTier leaves the picker's category selection alone.
  if self._picker and self._picker._widget:IsShown() and self._pickerClass ~= self._classIndex then
    self:_rescopePicker()
  end
end

-- Move to the next/previous class set in the current group, wrapping and skipping
-- empty class slots (the data has gaps for classes absent from a tier).
---@param dir number  +1 = next, -1 = previous
function DressingRoom:Step(dir)
  -- Weapon-source cell: ←/→ steps to the adjacent weapon TYPE the source has (rebuilds the preview).
  if self._group and self._group.weaponCell then
    local grp, t = self._group._source, self._group._type
    if not grp then return end
    local avail, cur = {}, nil
    for _, ty in ipairs(ns.WeaponTypeOrder) do
      if grp.types[ty] then avail[#avail + 1] = ty; if ty == t then cur = #avail end end
    end
    if not cur or #avail < 2 then return end
    cur = (cur - 1 + dir) % #avail + 1
    local newT = avail[cur]
    ns.PreviewWeaponCell(grp, newT, grp.types[newT])
    return
  end
  local sets = self._group and self._group.sets
  if not sets then return end
  local n = #sets
  local cur
  for i = 1, n do if sets[i] == self._set then cur = i; break end end
  if not cur then return end
  for _ = 1, n do
    cur = (cur - 1 + dir) % n + 1
    local s = sets[cur]
    if s and s.id then return self:_load(self._group, s) end
  end
end

-- Switch to the same class set in a sibling difficulty tier (or PvP variant) of the
-- current group, keeping the class column. Siblings are the groups that share this
-- group's base id (e.g. Hellfire Citadel Normal/Heroic/Mythic all id 28; or the PTR
-- raid's Raid Finder/Normal/Heroic/Mythic rows, all the same group id); they sit in
-- difficulty order in the data. Wraps; no-op for a single-tier group. Falls back to the
-- tier's first real set if it lacks the current class column.
---@param dir number  +1 = next tier, -1 = previous tier
function DressingRoom:StepTier(dir)
  if not self._group then return end
  -- Siblings live in the same table as the previewed group — ns.PtrSets for an upcoming
  -- set (whose difficulty/variant rows share the base group id), else live ns.Sets.
  local source = ns.Sets
  for _, g in ipairs(ns.PtrSets) do if g == self._group then source = ns.PtrSets; break end end
  local sibs, cur = {}, nil
  for _, g in ipairs(source) do
    if g.id == self._group.id then
      sibs[#sibs + 1] = g
      if g == self._group then cur = #sibs end
    end
  end
  if not cur or #sibs < 2 then return end

  -- Current class column = the set's index within its group's positional sets.
  local col
  for i = 1, #self._group.sets do if self._group.sets[i] == self._set then col = i; break end end

  for _ = 1, #sibs do
    cur = (cur - 1 + dir) % #sibs + 1
    local g = sibs[cur]
    local s = col and g.sets[col]
    if not (s and s.id) then
      for i = 1, #g.sets do if g.sets[i] and g.sets[i].id then s = g.sets[i]; break end end
    end
    if s and s.id then return self:_load(g, s) end
  end
end

-- Step tiers by on-screen direction (-1 = the row above, +1 = below). A group's
-- difficulty/variant rows always render in authored order — the grid's `a < b` tie-break
-- within one base name, independent of the expansion sort direction (only the expansion
-- ordering flips with the Sort toggle, never the tiers inside a group) — so the arrows
-- map straight to StepTier: +1 = the next authored sibling = the row below.
---@param vdir number  -1 = move to the tier shown above, +1 = below
function DressingRoom:StepTierVisual(vdir)
  -- Weapon-cosmetic cells have no difficulty tiers; up/down cycles their pieces instead.
  if self._group and self._group.kind then return self:_stepWeaponPiece(vdir) end
  self:StepTier(vdir)
end

-- Cycle the previewed weapon piece within the current cell (an arsenal's weapon
-- appearances, or a Shaman cell's illusion brands), wrapping. Driven by the up/down nav
-- in weapon-cosmetic preview, where there are no tiers to step.
---@param dir number  -1 = previous piece, +1 = next
function DressingRoom:_stepWeaponPiece(dir)
  local set = self._set
  local list
  if self._group.weaponCell then
    list = set and set._looks                              -- ↑/↓ steps through the cell's looks
  else
    list = set and (self._group.kind == "illusion" and set.illusions or set.pieces)
  end
  if not list or #list < 2 then return end
  local cur = (self._weaponPiece or 1) - 1                -- to 0-based
  self._weaponPiece = (cur + dir) % #list + 1             -- step, wrap, back to 1-based
  self:Dress()
  if self._group.weaponCell then
    self:_refreshRatings()                                -- the ★ tracks the shown look
    if self._cellList then self._cellList:Refresh() end   -- move the chooser highlight to it
  end
end

-- Select the logged-in character's race + gender. Called when the window opens
-- from a closed state, so each fresh open starts on the current character (while
-- it's open, the user's race picks stick). Set before _load so its Dress() renders
-- the right race/gender immediately.
function DressingRoom:_defaultToPlayer()
  local _, _, raceID = UnitRace("player")
  raceID = ns.CanonRace(raceID)   -- off-faction variant → the shown selector id (e.g. Horde Dracthyr 70 → 52)
  self:_highlightRace(raceID)
  self._raceID = raceID
  self._sex = UnitSex("player")   -- body gender is locked to the char; tracked for reference/debug
  self:_setupForms(ns.RaceModels[raceID])
end
