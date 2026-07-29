---@type Warbandeer_Collected
local ns = select(2, ...)
local ui, Colors = ns.ui, ns.Colors
local lists, prepend = ns.lua.lists, ns.lua.lists.prepend
local GameTooltip = GameTooltip
local DataView = ns.DataView

-- Build the column layout: a zero-width auto-sized name column then one icon column
-- per class. The windowed grid prepends a narrow lock column (the lockout glyph);
-- `embedded` hosts omit it entirely, so the name column is col 1 there and col 2 in
-- the window. Passed in at construction by each host (defaults can't branch on the
-- per-instance `embedded` flag, since the base table consumes colInfo first).
---@param embedded boolean?  true → no lock column (host owns lockouts)
---@return table
local function buildColInfo(embedded)
  local cols = lists.map(ns.icons.classes, function(icon, classId)
    return {
      atlas = icon,
      atlasSize = false,
      width = ns.gridCellWidth,
      padding = 2,
      justifyH = ui.justify.Center,
      -- Name the class on hover, as the weapon grid's headers have always named their weapon type.
      -- A class atlas is recognisable rather than labelled, and at 28px the less-played ones are a
      -- guess. `ns.icons.classes` is indexed BY class id, so the name comes straight off the index
      -- (parenthesised: GetClassInfo also returns the class file + id).
      tooltip = (GetClassInfo(classId)),
      backdrop = {color = Colors.TransparentBlack},
    }
  end)
  if embedded then
    return prepend(cols, { width = 0, backdrop = {color = Colors.TransparentBlack} })
  end
  return prepend(cols,
    { width = 15, backdrop = {color = Colors.TransparentBlack} },  -- lock
    { width =  0, backdrop = {color = Colors.TransparentBlack} })  -- name
end

-- Column-layout builder, exposed so each host passes its own `colInfo` at
-- construction (windowed = with lock column, embedded = without).
---@param embedded boolean?
---@return table
DataView.BuildColInfo = buildColInfo

---Flip the row order between oldest-first (expansion 1→12) and newest-first (12→1).
---Clears any active lockout selection first — its row index moves on re-sort — then
---rebuilds the grid in place.
---@return boolean reversed  the new order state
function DataView:ToggleOrder()
  self._reverse = not self._reverse
  if not self.embedded then self:_clearSelection() end
  self.data = self:GetData()
  self:update()
  return self._reverse
end

---Toggle the "wanted only" filter, rebuilding the grid to just the rows holding a
---wanted set (non-wanted class cells within a shown row still blank; an empty result
---shows a centered "no wanted sets" message).
---
---**Through `_refilter`, for the `_clearSelection` this used to skip (#762).** It was the one
---rebuild path that didn't clear — `ToggleOrder`, `SetPtr` and `_refilter` all do — and
---`_selectedRow` is a *display* index, so an open lockout panel survived onto whatever set landed
---on that screen row: the gold name stayed put (`Cell:Label` only re-applies colour for data
---carrying a `color` field, which the name cell doesn't), the arrow stayed anchored to the pooled
---row frame, and the side panel went on listing the previous set's lockouts with nothing naming
---it — raid-lock data attributed to the wrong raid. Clicking that row then took the
---`_selectedRow == dispIdx` branch and closed the panel instead of opening its own.
---
---`onFilterChanged` stays out here: `_refilter` doesn't fire it, and the counter is filter-scoped.
---@return boolean wantedOnly  the new filter state
function DataView:ToggleWantedOnly()
  self._wantedOnly = not self._wantedOnly
  self:_refilter()
  -- The set/appearance/collected counter is filter-scoped (VisibleCounts honors
  -- _wantedOnly), so recompute it too — reachable from both the strip's star and the
  -- header's ★ N counter click.
  if self.onFilterChanged then self:onFilterChanged() end
  return self._wantedOnly
end

---Toggle "wanted only" AND sync the WANTED ONLY filter button's highlight — so other
---chrome (the wanted-count counter) can drive the same toggle and the button still
---reflects it. `_syncWantedBtn` is registered by BuildFilterStrip; no-op before then.
function DataView:ToggleWanted()
  self:ToggleWantedOnly()
  if self._syncWantedBtn then self._syncWantedBtn() end
end

---Switch between live and PTR ("upcoming") data, rebuilding the grid. Clears any
---active lockout selection first — its row index moves between datasets.
---@param on boolean  true → show ns.PtrSets (upcoming), false → live ns.Sets
---@return boolean ptr  the new mode
function DataView:SetPtr(on)
  self._ptr = on
  if self._repaintPtr then self._repaintPtr(on) end   -- keep the toggle border in sync on a programmatic set (mode swap)
  if not self.embedded then self:_clearSelection() end
  self.data = self:GetData()
  self:update()
  -- The live and PTR row counts differ wildly, so the host must refit its scroll container.
  if self.onResized then self:onResized() end
  return self._ptr
end

-- Rebuild after a filter change (shared by SetExpansion/SetCategory). Clears any
-- lockout selection first, since the visible rows change.
function DataView:_refilter()
  if not self.embedded then self:_clearSelection() end
  self.data = self:GetData()
  self:update()
  -- ResizeRows (inside update) shrank/grew the row area; let the host refit its scroll
  -- container so the scroll range matches the filtered row count (no overscroll).
  if self.onResized then self:onResized() end
end

---Filter the grid to one expansion (a release index) or "all".
---@param key number|string  a release index, or "all"
function DataView:SetExpansion(key) self._expansion = key; self:_refilter() end

---Filter the grid to one category, or "all".
---@param key string  a category name, or "all"
function DataView:SetCategory(key) self._category = key; self:_refilter() end

---Explain the counter's three numbers in GameTooltip. Shared by both hosts (the standalone
---window and the embedded view) so the wording stays in one place; each wires its own hover
---frame over its counter and calls this from OnEnter. `owner` is that raw hover frame.
---@param owner Frame  the WoW frame the tooltip anchors to
function DataView:ShowCountTooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_BOTTOMRIGHT")
  GameTooltip:SetText("Collected set totals")
  GameTooltip:AddLine("|cffffffffsets|r — set rows shown for the current filter.", 0.8, 0.8, 0.8, true)
  GameTooltip:AddLine("|cffffffffappearances|r — class-column slots that hold a set (a set counts once per class it covers).", 0.8, 0.8, 0.8, true)
  GameTooltip:AddLine("|cffffffffcollected|r — appearances you've fully collected, i.e. the green checks.", 0.8, 0.8, 0.8, true)
  GameTooltip:Show()
end

---Tooltip for the gold wanted tally, which (clickable) drives the WANTED ONLY filter.
---@param owner Frame  the WoW frame the tooltip anchors to
function DataView:ShowWantedTooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_BOTTOMRIGHT")
  GameTooltip:SetText("Wanted sets")
  GameTooltip:AddLine("Click to toggle showing only the sets you've flagged wanted.", 0.8, 0.8, 0.8, true)
  GameTooltip:Show()
end

---Dropdown option specs for the expansion filter (shared with the weapons grid — see
---`ns.expansionBadgeOptions`): "All" then one per release present in `ns.Sets`, newest-first, badged.
---@return table[]  `{ key, label }` specs for `ui.FilterDropdown`
function DataView:ExpansionOptions() return ns.expansionBadgeOptions(ns.Sets) end

-- Display order for the category filter; categories present in ns.Sets but unlisted
-- here are appended so the menu never silently drops one.
local CATEGORY_ORDER = { "Raid", "PvP", "Dungeon", "Delve", "Covenant", "Renown", "World", "Trading Post", "Event" }

---Dropdown option specs for the category filter: "All" then each category present. The body is
---`ns.CategoryOptions` in GridShared.lua, shared with the weapon grid (#770 step 1) — only the
---source table and the ordering list differ between them.
---@return table[]  `{ key, label }` specs for `ui.FilterDropdown`
function DataView:CategoryOptions() return ns.CategoryOptions(ns.Sets, CATEGORY_ORDER) end

---Build the shared filter chrome as a strip (toggle buttons + filter dropdowns), wired
---to this grid, so both hosts render the identical row above the grid. Themed via the
---grid's own theme. `onModeChanged` fires after the live/PTR toggle so the host can
---refresh its mode counter.
---@param parent table  frame to parent the strip to
---@param onModeChanged fun()?  called after the live/PTR toggle flips
---@return Frame strip
function DataView:BuildFilterStrip(parent, onModeChanged)
  -- The strip itself is `ns.BuildGridStrip` (GridShared.lua, #770 step 9) — the weapon grid
  -- built the same ~50 lines. Only the noun its tooltips read in is ours.
  return ns.BuildGridStrip(self, parent, onModeChanged, "sets")
end
