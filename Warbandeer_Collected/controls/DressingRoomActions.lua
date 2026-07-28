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


-- ── Ratings ────────────────────────────────────────────────────────────────--

-- Sync the ratings row to the current subject, race, and edit layer: the wanted star,
-- and the gold highlight on the active tier (the per-race override when "This race"
-- is on, else the baseline). Called from _load (set change) and SetRace.
--
-- **The row follows `_focus` (#827).** It used to rate the previewed ARMOUR set whether or not a
-- weapon was browsed, which meant clicking it in weapon mode silently ranked a set nowhere near
-- where the user was looking. `_focus` already says which surface the arrows drive and which object
-- the window title names, so the row reads the same answer: `_ratedWeapon` returns the shown weapon
-- look when one is focused, and the weapon half of the row lives with it in
-- controls/WeaponCellPicker.lua. Rating an armour set while a weapon is browsed therefore costs one
-- click on any armour cell, which is what returns focus to it.
function DressingRoom:_refreshRatings()
  local look = self:_ratedWeapon()
  if look then return self:_paintWeaponRatings(look) end
  self:_enableRaceOnly(true)
  -- An outfit has no set id to rate. Hidden rather than merely left alone: a weapon browsed on top
  -- of a loaded look shows this row, so every pass has to be able to take it back (#827).
  if self._outfit then return self:_hideRatingsRow() end
  -- No set previewed yet (a weapon cell browsed straight from a fresh open): nothing to rate, so
  -- drop every border rather than leaving the last set's ratings lit under an unrelated doll.
  if not self._set then
    self._wantedBorder:Color(IDLE)
    for _, b in pairs(self._rankBtns) do b.border:Color(IDLE) end
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
--
-- Every caller knows exactly what it changed, so it says so (#768 L-8): an armour set by `setId`, a
-- weapon appearance by `visualID`. This used to broadcast nothing at all, which meant "everything"
-- and walked both grids in full — around 12,000 cells for one rank-button click, most of them in the
-- grid that couldn't have changed. Pass neither only when several ratings changed at once.
---@param setId number?  the armour set that changed
---@param visualID number?  the weapon appearance that changed
function DressingRoom:_ratingsChanged(setId, visualID)
  ns:NotifyRatingsChanged(setId, visualID)
end

function DressingRoom:ToggleWanted()
  local look = self:_ratedWeapon()
  if look then return self:_wantWeapon(look) end
  if not self._set then return end
  ns:ToggleWanted(self._set.id)
  self:_refreshRatings()
  self:_ratingsChanged(self._set.id)
end

-- Set the tier (or clear it when nil, or when re-clicking the active one). Writes
-- the per-race override while "This race" is on, else the baseline — a weapon has neither, so it
-- takes the flat write and "This race" greys out while one is focused.
---@param letter string?  a tier from ns.Ranks, or nil to clear
function DressingRoom:SetRank(letter)
  local look = self:_ratedWeapon()
  if look then return self:_rateWeapon(look, letter) end
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
  self:_ratingsChanged(setId)
end

---@param on boolean  edit/display the per-race override instead of the baseline
function DressingRoom:SetRaceOnly(on)
  self._raceOnly = on
  self._raceOnlyBorder:Color(on and SELECTED or IDLE)
  self:_refreshRatings()
end

-- Preview a specific set within a group: refresh the title, class icon, slots and model. Shared by
-- ShowDressingRoom (initial open) and Step/StepTier (navigation).
--
-- A weapon cell isn't a set and no longer loads through here at all (#673): it's a browse that
-- stages onto the same doll this armour is on, so it leaves every field below untouched and goes to
-- `_loadCell` (controls/WeaponCellPreview.lua) instead. The two surfaces are live at once — the
-- armour set on the body, the browsed weapon in its hand — and `_focus` is what says which one the
-- arrow keys are driving.
---@param group table  a group entry from ns.Sets
---@param set table    a set entry within that group
function DressingRoom:_load(group, set)
  if group.weaponCell then return self:_loadCell(group, set) end
  self._focus = "armor"
  self._group = group
  self._set = set
  wipe(self._hiddenSlots)   -- per-set toggles: each set opens fully dressed
  self._undressed = nil     -- …including the master Undress state
  -- Previewing a set is the only way out of outfit mode: drop the applied list and restore the
  -- set-keyed furniture it hid (the class icon, tier bars and ratings row are re-shown below).
  --
  -- Clearing the dropdown's selection AND the name field with it matters as much as the flag. Left
  -- alone, the row keeps describing a look the room no longer shows: the dropdown reads as that
  -- entry (and `FilterDropdown` treats re-picking the current option as a no-op, so it became
  -- unloadable until something else was selected first), while the field keeps its name — which is
  -- worse, since the typed name is what Save targets, so a Save here would aim at a look nothing on
  -- screen relates to. Both go back to the neutral "+ New Look, no name" state. Only on the actual
  -- transition, so a Step between sets doesn't rebuild the option list every time.
  if self._outfit then
    self._outfit = nil
    self._outfitSel = nil
    if self._outfitName then self._outfitName:Text("") end
    if self._outfitDrop then self:RefreshOutfits() end
  end
  -- Leaving outfit mode drops a pending outfit-slot icon refresh: it would re-run against a look
  -- that is no longer on the model (#770 step 14 moved this behind ns.CancelRetry).
  ns.CancelRetry(self, "outfitSlots")
  -- A save waiting on streaming item data must not fire against a set the user has since left.
  self:_cancelSaveRetry()
  self:_disarmOutfit()
  if self._wantBox then self._wantBox:Show() end
  -- An applied outfit (ApplyOutfit / `/collected outfit import`) leaves per-slot overrides that
  -- the model re-asserts after every re-skin. Drop the armor ones here — before the Dress() below
  -- — or they'd repaint over whatever set is being loaded. The composed look's weapons/cosmetics
  -- are deliberately left alone; they outlive a set change, and a weapon browsed from the Weapons
  -- grid is one of them (#673).
  self:ClearOutfitArmor()
  self:Title(set.name)
  -- Set id (right of the title) + its hover tooltip = the master-grid group name.
  self._masterName = group.name
  self._idLabel:Text(tostring(set.id or ""))
  -- Class = the set's position in the (positional) group.sets array.
  local classId
  for i = 1, #group.sets do if group.sets[i] == set then classId = i; break end end
  self._classIndex = classId
  -- Re-shown unconditionally: the ratings row is hidden only by outfit mode, and previewing a set
  -- is the way out of it.
  if self._ratingsBoxes then for _, b in ipairs(self._ratingsBoxes) do b:Show() end end
  self:_showClass(classId)
  self:_showRelease(group.release)
  self:_setTierBars(group.name)
  ns.ResetRetry(self, "slots")   -- the icon-refresh budget is per room-open (#770 step 14)
  self:UpdateSlots()
  -- Re-assert the composed look (and repaint its slots) rather than just repainting them: the
  -- armor above went on through Outfit, which doesn't know about the per-slot overrides the
  -- weapons, illusion, shirt and tabard ride on. Runs before Dress() below, so the re-skin
  -- re-applies them on load.
  self:_applyLook()
  self:Dress()
  self:_syncUndressBorder()   -- wiped toggles → fully worn → Undress button idle
  self:_refreshRatings()
  -- Every previewed-set change funnels through here (open + Step/StepTier arrow nav),
  -- so broadcast it once from this choke point; the grids cursor the matching cell.
  -- classId (the set's class column) is passed too: PvP sets share a base setId across
  -- classes, so it's needed to pick the right column.
  ns:NotifyDressedSetChanged(set.id, classId)
  -- The Weapons grid's cursor is deliberately NOT touched here. Each surface owns its own cursor
  -- now that both are on the doll together (#673): a browsed weapon survives an armour Step, so
  -- clearing its cell would say the model had put it down. `_loadCell` broadcasts that one, and
  -- only closing the room (or loading a library look) clears both.
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
  -- A loaded outfit isn't part of any group, so there's nothing to step through; `_group`/`_set`
  -- still hold the last previewed set and stepping them would silently swap the look out from
  -- under the user. Pick a set from a grid to leave outfit mode.
  if self._outfit then return end
  -- While the Weapons grid is the surface being driven, ←/→ steps the browsed source's adjacent
  -- weapon TYPE instead of the armour group's class column.
  if self._focus == "weapons" and self._cell then return self:_stepWeaponType(dir) end
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
  if not self._group or self._outfit then return end   -- see Step: an outfit has no siblings
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
  -- A weapon cell has no difficulty tiers; up/down cycles its looks instead.
  if self._focus == "weapons" and self._cell then return self:_stepWeaponPiece(vdir) end
  self:StepTier(vdir)
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
