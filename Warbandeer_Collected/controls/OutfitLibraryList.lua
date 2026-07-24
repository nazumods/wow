---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label = ui.Frame, ui.Label
local OutfitLibraryWindow = ns.OutfitLibraryWindow
local k = OutfitLibraryWindow._k
local LEFTW, ROW_H, ANY = k.LEFTW, k.ROW_H, k.ANY
local EMPTY_LIBRARY, EMPTY_MATCH = k.EMPTY_LIBRARY, k.EMPTY_MATCH

-- The library window's **list**: the pooled rows and the filtering that decides which of them show.
-- Reopens OutfitLibraryWindow; the shell and filter strip are controls/OutfitLibraryWindow.lua, the
-- preview pane is controls/OutfitLibraryPreview.lua. Split for file size, as the dressing room is.
--
-- The filter RULE itself isn't here — it's `ns.FilterOutfits` / `ns.LibraryFacets` in
-- outfitlibrary.lua, which is WoW-free and unit-tested. This file is only widgets.

-- Shown for an entry saved before #655 recorded provenance. Named rather than left blank so the
-- row reads as "we don't know" instead of as a rendering bug — these entries deliberately survive
-- every filter (see the note in outfitlibrary.lua).
local NO_PROVENANCE = "no provenance recorded"
-- Row fill alphas. The selected fill is brighter than the hover one so a selection still reads as
-- selected while the pointer sits on some other row.
local SEL_A, HOVER_A = 0.22, 0.12

---@param row Frame
---@param alpha number
local function paint(row, alpha) row.background:Color(1, 1, 1, alpha) end

-- One pooled row: the look's name (class-coloured), its provenance beneath in muted text, a hover
-- fill, and a brighter fill while it is the selected one.
---@param list VirtualList
---@return Frame
function OutfitLibraryWindow:_makeRow(list)
  local row = Frame:new{ parent = list:Content(), background = {1, 1, 1, 0},
    position = { Height = ROW_H } }
  local w = LEFTW - 16
  row.name   = Label:new{ parent = row, justifyH = ui.justify.Left, wordWrap = false,
    position = { TopLeft = {8, -5}, Width = w } }
  row.origin = Label:new{ parent = row, justifyH = ui.justify.Left, wordWrap = false, color = "muted",
    position = { TopLeft = {8, -20}, Width = w } }
  row._widget:EnableMouse(true)
  -- Hover must not clobber the selected row's fill, so both scripts ask what the row IS rather than
  -- assuming they own the background.
  row._widget:SetScript("OnEnter", function()
    if row._name ~= self._selected then paint(row, HOVER_A) end
  end)
  row._widget:SetScript("OnLeave", function()
    paint(row, row._name == self._selected and SEL_A or 0)
  end)
  row._widget:SetScript("OnMouseUp", function() self:Select(row._name) end)
  return row
end

-- Re-point a pooled row at `{ outfit = <LibraryOutfit> }`. The name is coloured by `class` — WHO
-- saved it — keeping the one meaning that tint already has on the outfit row's dropdown, while the
-- class FILTER keys on `forClass`, what the look is for. The two answer different questions, so
-- the row spells `forClass` out in words rather than letting the colour try to carry both.
---@param row Frame
---@param item table
---@return number
function OutfitLibraryWindow:_fillRow(row, item)
  local o = item.outfit
  row._name = o.name
  row.name:Text(ns.ClassColored(o.name, o.class))
  local origin = ns.OutfitOrigin(o)
  local forClass = o.forClass and ns.ClassLabel(o.forClass)
  if forClass then
    forClass = ("a %s look"):format(forClass)
    origin = origin ~= "" and (origin .. "   ·   " .. forClass) or forClass
  end
  row.origin:Text(origin ~= "" and origin or NO_PROVENANCE)
  paint(row, o.name == self._selected and SEL_A or 0)
  return ROW_H
end

---Rebuild the class dropdown from what the library actually holds, then re-filter. Called on every
---open, since the library changes from the outfit row while this window is closed.
---@return OutfitLibraryWindow
function OutfitLibraryWindow:Refresh()
  local opts, valid = { { key = ANY, label = "Any class" } }, false
  for _, classFile in ipairs(ns.LibraryFacets(ns.LibraryOutfits())) do
    opts[#opts + 1] = { key = classFile, label = ns.ClassColored(ns.ClassLabel(classFile), classFile) }
    if classFile == self._filter.class then valid = true end
  end
  -- Deleting the last WARRIOR look retires that option. Drop the filter with it, or the list would
  -- stay filtered by something no longer in the dropdown and so impossible to clear from there.
  if not valid then self._filter.class = nil end
  self._classDrop:SetOptions(opts, self._filter.class or ANY)
  -- A selection can outlive the entry it named — deleted here, or renamed from the outfit row while
  -- this was closed. Drop it rather than leaving the preview showing a look that no longer exists.
  if self._selected and not ns.LibraryOutfit(self._selected) then self._selected = nil end
  self:_apply()
  self:_showPreview(self._selected)
  return self
end

-- Re-run the filter and repopulate. The title carries the count, which is the cheapest honest
-- feedback that a filter is doing something — and the only place there is room for it.
function OutfitLibraryWindow:_apply()
  local all = ns.LibraryOutfits()
  local shown = ns.FilterOutfits(all, self._filter)
  local items = {}
  for i, o in ipairs(shown) do items[i] = { outfit = o } end
  self._list:EmptyText(#all == 0 and EMPTY_LIBRARY or EMPTY_MATCH)
  self._list:SetItems(items)
  self:Title(#shown == #all and ("Outfit Library — %d"):format(#all)
    or ("Outfit Library — %d of %d"):format(#shown, #all))
end

---Drop every filter and show the whole library again.
---@return OutfitLibraryWindow
function OutfitLibraryWindow:ClearFilters()
  self._filter = {}
  self._armorDrop:Select(ANY)
  self._classDrop:Select(ANY)
  self._search:Text("")           -- fires OnTextChanged only when it wasn't already empty…
  self._hint:Show()
  self:_apply()                   -- …so re-apply unconditionally rather than relying on it
  return self
end
