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
--   * off-hand weapon   self._lookOH   (shields / holdables / a second 1H / a Titan's Grip 2H)
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

-- Shape the pane for a weapon target (self._pickerTarget is "main" or "off"): restore the mode
-- tabs + title the cosmetic targets hide, filter the weapon-category dropdown to that hand's
-- categories (main-hand = anything NOT off-hand-only; off-hand = the off-hand-only set + dual-wield
-- 1H via canOffHand + the Titan's Grip two-handers), keeping the current category if it's still
-- valid else the first available;
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
    -- Off-hand dropdown = the off-hand-only set (shields/holdables) + dual-wield 1H (`canOffHand`)
    -- + the Titan's Grip two-handers (#661). Main-hand dropdown = everything NOT off-hand-only (1H,
    -- 2H, ranged, wands). Shields report the SAME flags as 2H weapons, so only an explicit set can
    -- tell them apart — viewsync.lua owns it.
    -- `canOffHand` stays the dual-wield test here and is NOT replaced by that file's static
    -- one-handed set: this pane is scoped to a class, and a paladin must not be offered an
    -- off-hand sword. (The class-agnostic weapon grid uses the static set — see ns.WeaponHands.)
    -- `TitansGripWeapon` is class-free even here, unlike its 1H neighbour — the set's own note in
    -- viewsync.lua gives the three reasons, the decisive one being that the grid stages the same
    -- look with no class at all, so a gate applied only here would be bypassable from there.
    -- `self._pickerCats` is already the previewed class's own list, so a class that can't wield a
    -- 2H axe never sees the option regardless.
    local offHandOnly = ns.OffHandOnlyWeapon(c.category)
    if (off and (offHandOnly or c.canOffHand or ns.TitansGripWeapon(c.category)))
      or (not off and not offHandOnly) then
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
      self._lookMH, self._lookNoOH = nil, nil          -- toggling the applied weapon off
    else
      self._lookMH = sid
      -- Grey the off-hand while a main-hand that leaves no room for one is composed: a staff, a
      -- polearm, a bow (#618). A two-handed axe/mace/sword does NOT, since Titan's Grip pairs
      -- them (#661).
      local cat = self._pickerCatByID[self._pickerCategory]
      self._lookNoOH = ns.SuppressesOffHand(cat and cat.category) or nil
    end
  end
end
