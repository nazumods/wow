---@type Warbandeer_Collected
local ns = select(2, ...)
local DressingRoom = ns.DressingRoom
local k = DressingRoom._k
local SELECTED, IDLE = k.SELECTED, k.IDLE

-- Weapon + illusion "look builder" (#596): the half of the docked picker that knows about weapons.
-- The pane, its rows and the compose-onto-the-model step are shared — see the companion
-- controls/AppearancePicker.lua, which this file reopens the DressingRoom class alongside.
--
-- A "Weapons | Illusions" tab row switches the pane between two modes (illusions are a peer of
-- weapons, not a weapon "type", so they get their own tab rather than hiding among the weapon-
-- category dropdown): Weapons mode shows the category dropdown + weapon list; Illusions mode
-- drops the dropdown and shows the illusion list. Both are scoped to the PREVIEWED SET's class
-- (self._classIndex), not the logged-in viewer's (#608): the weapon dropdown lists that class's
-- usable types and the illusion tab that class's illusions. _rescopePicker re-derives both when
-- the previewed class changes (Step across class columns).
--
-- Composition (the look is independent slots, re-applied together by _applyLook):
--   * main-hand weapon  self._lookMH   (a weapon appearance sourceID)
--   * off-hand weapon   self._lookOH   (shields / holdables / a second 1H)
--   * illusion          self._lookIllusion  (rides the main-hand — the picked weapon, else the
--                       character's equipped host weapon, since a shimmer needs a weapon to sit on)
-- Clicking the applied piece again clears that slot.

-- Re-derive the previewed class's weapon categories (the dropdown's source) and the id → descriptor
-- map the main/off-hand routing reads. Cached per class by the data layer, so this is cheap to
-- repeat. Split out of _rescopePicker so _buildPicker can prime the categories before it builds the
-- dropdown, without also trying to apply a target to a pane that doesn't exist yet.
function DressingRoom:_rescopeWeapons()
  self._pickerClass = self._classIndex
  self._pickerCats = ns.WeaponCategories(self._classIndex)
  self._pickerCatByID = {}
  for _, c in ipairs(self._pickerCats) do self._pickerCatByID[c.category] = c end
end

-- Re-scope the picker to the currently previewed set's class: rebuild the weapon-category list +
-- dropdown for that class (keeping the current category if the new class still has it, else the
-- first available), and repopulate the active target (the illusion list is class-scoped too).
-- Called when the previewed class changes with the pane already built — Stepping across class
-- columns (from _load, while shown) or reopening the pane after such a Step.
function DressingRoom:_rescopePicker()
  self:_rescopeWeapons()
  self:_applyPickerTarget()
end

-- Off-hand-SLOT categories: shields + off-hand frills. GetCategoryInfo can't tell these from a
-- two-handed weapon by flag — a Shield and a TwoHSword report IDENTICAL isWeapon/canMainHand/
-- canOffHand (both canOffHand=false, since that flag is "can be a dual-wield off-hand WEAPON",
-- which neither is) — so the slot split needs an explicit set, not a flag test.
local OFF_HAND_ONLY = {
  [Enum.TransmogCollectionType.Shield]   = true,
  [Enum.TransmogCollectionType.Holdable] = true,
}

-- Shape the pane for a weapon target (self._pickerTarget is "main" or "off"): restore the mode
-- tabs + title the cosmetic targets hide, filter the weapon-category dropdown to that hand's
-- categories (main-hand = anything NOT off-hand-only; off-hand = the off-hand-only set + dual-wield
-- 1H via canOffHand), keeping the current category if it's still valid else the first available;
-- hide the Illusions tab for the off-hand (illusions ride the main hand, so they're only offered
-- there); then repopulate the active mode. Shared by the open path and the class re-scope so both
-- honour the hand + class scoping in one place.
function DressingRoom:_applyWeaponTarget()
  local off = self._pickerTarget == "off"
  self._pickerTitle:Text(DressingRoom._TARGETS[self._pickerTarget].title)
  self._pickerTabs:Show()
  self._pickerTabBox.illusions:SetShown(not off)
  if off and self._pickerMode == "illusions" then self._pickerMode = "weapons" end
  local opts, valid = {}, false
  for _, c in ipairs(self._pickerCats) do
    -- Off-hand dropdown = the off-hand-only set (shields/holdables) + dual-wield 1H (`canOffHand`).
    -- Main-hand dropdown = everything NOT off-hand-only (1H, 2H, ranged, wands). Shields report the
    -- SAME flags as 2H weapons, so only the explicit OFF_HAND_ONLY set can tell them apart.
    local offHandOnly = OFF_HAND_ONLY[c.category]
    if (off and (offHandOnly or c.canOffHand)) or (not off and not offHandOnly) then
      opts[#opts + 1] = { key = c.category, label = c.name }
      if c.category == self._pickerCategory then valid = true end
    end
  end
  if not valid then self._pickerCategory = opts[1] and opts[1].key end
  self._pickerCat:SetOptions(opts, self._pickerCategory)
  self:_setPickerMode(self._pickerMode or "weapons")
end

-- Switch the pane between "weapons" and "illusions": recolor the tabs, show/hide the weapon
-- dropdown, re-anchor the list (below the dropdown in weapons mode, below the tabs in illusions
-- mode so the freed space is used), and repopulate.
---@param mode string  "weapons" | "illusions"
function DressingRoom:_setPickerMode(mode)
  self._pickerMode = mode
  self._modeTab.weapons:Color(mode == "weapons" and SELECTED or IDLE)
  self._modeTab.illusions:Color(mode == "illusions" and SELECTED or IDLE)
  self._pickerCat:SetShown(mode == "weapons")
  self:_anchorPickerList(mode == "weapons" and self._pickerCat or self._pickerTabs)
  if mode == "weapons" then
    self:_pickCategory(self._pickerCategory or (self._pickerCats[1] and self._pickerCats[1].category))
  else
    self:_populateIllusions()
  end
end

-- Switch the weapon list to category `categoryID`. Repoints the dropdown (no re-fire) and rebuilds
-- the collected appearance rows.
---@param categoryID number
function DressingRoom:_pickCategory(categoryID)
  self._pickerCategory = categoryID
  self._pickerCat:Select(categoryID)
  self:_populateWeapons()
end

-- Populate the active weapon category's COLLECTED appearances, each resolved to its WeaponSource.
-- The dropdown is already filtered to hand-appropriate categories, so the rows need no further
-- scoping — clicks and the selection border follow self._pickerTarget.
function DressingRoom:_populateWeapons()
  local items = {}
  for _, app in ipairs(ns.WeaponAppearances(self._pickerCategory, self._classIndex)) do
    if app.isCollected then
      local src = ns.AppearanceSource(app.visualID)
      if src then items[#items + 1] = { kind = "w", visualID = app.visualID, src = src } end
    end
  end
  self._pickerList:SetItems(items)
  self:_scheduleNameFill()
end

-- Populate the previewed set's class's enchant illusions (via ns.Illusions), skipping the "no
-- illusion" hide entry. Names resolve synchronously, so no async name-fill needed.
--
-- Like the cosmetic lists and unlike the weapon ones, this shows illusions you DON'T own, so the
-- rows carry `showStatus`: the green-check / red-X collected mark and the shift-click Wanted star.
-- (The list was always unfiltered; before #641 the only owned/unowned signal was the name tint.)
function DressingRoom:_populateIllusions()
  local items = {}
  for _, ill in ipairs(ns.Illusions(self._classIndex)) do
    items[#items + 1] = { kind = "i", ill = ill, showStatus = true }
  end
  self._pickerList:SetItems(items)
end

-- Weapon categories that occupy BOTH hands (no off-hand possible) — a main-hand pick in one of
-- these greys out the off-hand slot (#618). A POSITIVE list, deliberately not `not canOffHand`:
-- that flag means "can sit in the off-hand slot", which also excludes wands (a caster runs a wand
-- + off-hand) and would depend on how warglaives (dual-wield) are flagged. This names the real 2H.
local TWO_HANDED = {
  [Enum.TransmogCollectionType.TwoHAxe]   = true,
  [Enum.TransmogCollectionType.TwoHSword] = true,
  [Enum.TransmogCollectionType.TwoHMace]  = true,
  [Enum.TransmogCollectionType.Polearm]   = true,
  [Enum.TransmogCollectionType.Staff]     = true,
  [Enum.TransmogCollectionType.Bow]       = true,
  [Enum.TransmogCollectionType.Crossbow]  = true,
  [Enum.TransmogCollectionType.Gun]       = true,
}

-- Shared with the outfit path (controls/DressingRoomOutfit.lua), which has to re-derive
-- `_lookMH2H` when it loads a look it didn't compose. This file owns the list — see the comment
-- above for why it has to be an explicit set rather than a capability-flag test.
DressingRoom._TWO_HANDED = TWO_HANDED

-- Toggle a clicked piece into/out of the look: an illusion, or a weapon in the targeted hand.
-- Clicking the applied piece again clears that slot. The apply + re-color tail is the shared
-- _equipRow's (AppearancePicker.lua), which routes here for a weapon target.
---@param item table
function DressingRoom:_equipWeaponRow(item)
  if item.kind == "i" then
    self._lookIllusion = DressingRoom._togglePick(self._lookIllusion, item.ill.sourceID)
  elseif self._pickerTarget == "off" then
    self._lookOH = DressingRoom._togglePick(self._lookOH, item.src.sourceID)
  else
    local sid = item.src.sourceID
    if self._lookMH == sid then
      self._lookMH, self._lookMH2H = nil, nil          -- toggling the applied weapon off
    else
      self._lookMH = sid
      -- Grey the off-hand while a two-handed main-hand is composed (#618).
      local cat = self._pickerCatByID[self._pickerCategory]
      self._lookMH2H = (cat and TWO_HANDED[cat.category]) or nil
    end
  end
end
