---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local DressingRoom = ns.DressingRoom
local PAD = DressingRoom._k.PAD
local TARGETS = DressingRoom._TARGETS

-- Shirt + tabard "look builder" (#641): the half of the docked picker that knows about the two
-- cosmetic slots. A sibling of controls/WeaponPicker.lua over the shared pane in
-- controls/AppearancePicker.lua, which this file reopens the DressingRoom class alongside.
--
-- Much simpler than the weapon half, because a cosmetic target IS its category: pointing the pane
-- at the Shirt slot means "browse shirts", so there is nothing to pick from a dropdown and no
-- second mode to tab to. The pane therefore hides both the mode tabs and the category dropdown and
-- gives the whole height to the list, titled with the category's own localized name.
--
-- The rows are the shared ones: ns.AppearanceSource resolves a shirt or tabard visual to exactly
-- the same WeaponSource shape a weapon resolves to, so _fillRow renders either without branching.

-- Shape the pane for a cosmetic target (self._pickerTarget is "shirt" or "tabard"): drop the
-- weapon furniture, retitle to the category, give the list the freed space, and populate.
function DressingRoom:_applyCosmeticTarget()
  local cat = ns.CosmeticCategoryForSlot(TARGETS[self._pickerTarget].slot)
  self._pickerTabs:Hide()
  self._pickerCat:Hide()
  self._pickerTitle:Text(cat and cat.name or "")
  -- The tabs are hidden rather than removed, so anchor to where they SIT (the pane's own top
  -- inset) instead of to their bottom edge — otherwise the list would leave a tab-sized gap.
  self._pickerList:ClearAllPoints()
  self._pickerList:Position{
    TopLeft     = {self._picker, ui.edge.TopLeft, PAD, -(PAD + 22)},
    BottomRight = {self._picker, ui.edge.BottomRight, -PAD, PAD},
  }
  self:_populateCosmetics(cat)
end

-- Populate a cosmetic category's appearances — **all** of them, owned or not, unlike the weapon
-- lists. These two slots are a browse-and-wish surface rather than a pick-what-you-own one: no set
-- ever supplies a shirt or a tabard, so this pane is the only place the full range surfaces at all.
-- Nothing technical forces the filter either way — `ns.AppearanceSource` resolves an unowned visual
-- to its first source, and an unowned appearance renders on the model and exports through
-- `/collected outfit export` exactly like an owned one. `showStatus` turns on the row's
-- green-check / red-X mark and its shift-click Wanted star, which only earn their space on a list
-- that shows both states.
---
---"Hidden Shirt" / "Hidden Tabard" (`isHideVisual`) is pinned to the top: it's the one row reached
---for most often — it's how a look deliberately empties the slot — and the API returns it buried
---mid-list. A two-bucket partition rather than a `table.sort`, so it stays stable and everything
---else keeps the wardrobe's own order. (Blizzard sorts on the same flag but only as a late
---tiebreak, below collected/usable/favourite; pinning it first is a deliberate divergence.)
---@param cat CosmeticCategory?
function DressingRoom:_populateCosmetics(cat)
  local items, rest = {}, {}
  if cat then
    for _, app in ipairs(ns.CosmeticAppearances(cat.category)) do
      local src = ns.AppearanceSource(app.visualID)
      if src then
        local row = { kind = "w", visualID = app.visualID, src = src, showStatus = true }
        local bucket = app.isHideVisual and items or rest
        bucket[#bucket + 1] = row
      end
    end
    for _, row in ipairs(rest) do items[#items + 1] = row end
  end
  self._pickerList:SetItems(items)
  self:_scheduleNameFill()
end

-- Toggle a clicked appearance into/out of the targeted cosmetic slot; clicking the applied one
-- again clears it. The apply + re-color tail is the shared _equipRow's (AppearancePicker.lua),
-- which routes here for a cosmetic target.
---@param item table
function DressingRoom:_equipCosmeticRow(item)
  local field = TARGETS[self._pickerTarget].look
  self[field] = DressingRoom._togglePick(self[field], item.src.sourceID)
end
