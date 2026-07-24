---@type Warbandeer_Collected
local ns = select(2, ...)
local ui, Colors = ns.ui, ns.Colors
local lists, prepend = ns.lua.lists, ns.lua.lists.prepend
local GameTooltip = GameTooltip
local WeaponView = ns.WeaponView

-- The Weapons grid's filter/sort chrome: the column layout, the toggles the strip drives, the
-- dropdown option specs, and BuildFilterStrip itself. Reopens the WeaponView class. The armor
-- analogue — same responsibilities, same order — is DataViewFilters.lua.

-- Column layout: an autosized name column (col 1) then one narrow column per weapon type (a
-- house-style icon header — abbreviation fallback — plus the full-name header tooltip). No lock
-- column — weapons have no lockouts.
---@return table
function WeaponView.BuildColInfo()
  local usable = ns.WeaponUsableTypes()
  -- Types this class can wield POP in gold (the grid's active accent); ones it can't recede to a dim
  -- 40% neutral. A hue split (gold vs grey), not just brightness, so the usable columns read at a
  -- glance. Real texture header (TableCol renders `path` as a Texture, not |T…|t markup) so the icon
  -- can carry the vertexColor — a fully-collected unusable column shows green checks the cell paint
  -- can't grey, so this header tint is the reliable "not for your class" cue. #690 greying hint.
  local USABLE_TINT, DIM_TINT = {1, 0.843, 0, 1}, {1, 1, 1, 0.4}
  local cols = lists.map(ns.WeaponTypeOrder, function(t)
    return { name = ns.WeaponTypeAbbr[t], path = ns.WeaponTypeIcon[t],
      vertexColor = usable[t] and USABLE_TINT or DIM_TINT,
      width = 34, padding = 2, justifyH = ui.justify.Center,
      tooltip = ns.WeaponTypeName[t], backdrop = { color = Colors.TransparentBlack } }
  end)
  return prepend(cols, { name = "", width = 0, backdrop = { color = Colors.TransparentBlack } })
end

-- Rebuild after a filter change; let the host refit its scroll container to the new row count.
function WeaponView:_refilter()
  self.data = self:GetData()
  self:update()
  if self.onResized then self:onResized() end
end
---@param key number|string
function WeaponView:SetExpansion(key) self._expansion = key; self:_refilter() end
---@param key string
function WeaponView:SetCategory(key) self._category = key; self:_refilter() end

---Toggle the "wanted only" filter, rebuilding the grid to just the rows holding a wanted weapon look
---(cells holding none still blank within a shown row; an empty result shows a centered message).
---@return boolean wantedOnly  the new filter state
function WeaponView:ToggleWantedOnly()
  self._wantedOnly = not self._wantedOnly
  self:_refilter()
  -- The source/appearance/collected counter is filter-scoped (VisibleCounts honors _wantedOnly), so
  -- recompute it too — reachable from both the strip's star and the header's ★ N counter click.
  if self.onFilterChanged then self:onFilterChanged() end
  return self._wantedOnly
end

---Toggle "wanted only" AND sync the ★ filter button's highlight — so other chrome (the header's
---wanted count) can drive the same toggle and the button still reflects it. `_syncWantedBtn` is
---registered by BuildFilterStrip; no-op before then. Named to match the armor grid's, so a host can
---drive whichever grid is active without branching.
function WeaponView:ToggleWanted()
  self:ToggleWantedOnly()
  if self._syncWantedBtn then self._syncWantedBtn() end
end

---Swap the grid between live weapons and the PTR-preview (upcoming) weapons. Clears the dressed-cell
---cursor (no drill-in for unreleased weapons), rebuilds, and lets the host refit + refresh its counter.
---@param on boolean
---@return boolean
function WeaponView:SetPtr(on)
  self._ptr = on
  if self._repaintPtr then self._repaintPtr(on) end   -- keep the toggle border in sync on a programmatic set (mode swap)
  self:HighlightWeaponCell(nil, nil, false)   -- no dressing-room preview for weapons that aren't out yet
  self:_refilter()
  return self._ptr
end
---@return boolean
function WeaponView:ToggleOrder()
  self._reverse = not self._reverse
  self.data = self:GetData()
  self:update()
  return self._reverse
end

-- Expansion filter options (shared with the armor grid — see ns.expansionBadgeOptions): "All" then one
-- per release present in ns.WeaponSources (newest first, badged); release 0 shows as "Other".
---@return table[]
function WeaponView:ExpansionOptions() return ns.expansionBadgeOptions(ns.WeaponSources) end

local CATEGORY_ORDER = { "Raid", "Dungeon", "World Boss", "Quest", "Vendor", "World Drop", "Crafted", "Trading Post", "Achievement", "Other" }
---@return table[]
function WeaponView:CategoryOptions()
  local seen = {}
  for _, g in ipairs(ns.WeaponSources) do if g.category then seen[g.category] = true end end
  local opts, used = { { key = "all", label = "Category" } }, {}
  for _, c in ipairs(CATEGORY_ORDER) do if seen[c] then opts[#opts + 1] = { key = c, label = c }; used[c] = true end end
  for c in pairs(seen) do if not used[c] then opts[#opts + 1] = { key = c, label = c } end end
  return opts
end

---Tooltip for the gold wanted tally, which (clickable) drives the WANTED ONLY filter.
---@param owner table  the WoW frame the tooltip anchors to
function WeaponView:ShowWantedTooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_BOTTOMRIGHT")
  GameTooltip:SetText("Wanted weapon looks")
  GameTooltip:AddLine("Click to toggle showing only the weapons you've flagged wanted.", 0.8, 0.8, 0.8, true)
  GameTooltip:Show()
end

-- Filter strip for the weapon grid: a PTR toggle + Wanted (★) + Sort toggle + Expansion / Category
-- dropdowns, in the armor strip's order so the two read alike. The Armor/Weapons mode toggle is
-- host-owned (persistent across both grids). Themed from the grid, matching DataView:BuildFilterStrip.
--
-- `onModeChanged` re-tallies the host's counter, and every control that changes WHICH ROWS ARE SHOWN
-- has to fire it — the PTR pill and both dropdowns — because the counter is filter-scoped
-- (ns.WeaponVisibleCounts honours `matches`). The dropdowns didn't, so narrowing to one expansion
-- re-filtered the grid while the counter kept reading the whole table; the armor strip has always
-- fired it from all three (DataView:BuildFilterStrip). The ★ toggle goes through `onFilterChanged`
-- instead, which ToggleWantedOnly fires for the same reason.
---@param parent table
---@param onModeChanged fun()?  fired after the PTR toggle or either dropdown changes the shown rows
---@return Frame
function WeaponView:BuildFilterStrip(parent, onModeChanged)
  local theme = self:Theme()
  local gold = theme.colors.gold or theme.colors.header
  local divider = theme.colors.divider
  local BH, GAP, DW, DW_EXP = WeaponView.STRIP_H, 6, 110, 190
  local IB, BW = BH, 48
  local TEX = [[Interface\AddOns\Warbandeer_Collected\textures\]]
  local NEWEST_ICON, OLDEST_ICON = TEX .. "sort-newest", TEX .. "sort-oldest"
  local strip = ui.Frame:new{ parent = parent, position = { Height = BH } }

  -- PTR PREVIEW toggle (text pill, first) — swaps the grid to the upcoming (PTR-only) weapons; the
  -- gold border marks it active. Mirrors the armor grid's PTR toggle (DataView:BuildFilterStrip).
  local x = 0
  local ptrBorder, wantedBorder, sortIcon
  ptrBorder = ns.filterToggle(strip, theme, {
    x = x, text = "PTR", active = false,
    onClick = function()
      self:SetPtr(not self._ptr)   -- repaints the border via _repaintPtr below
      if onModeChanged then onModeChanged() end
    end,
  })
  -- Lets SetPtr repaint the border when the state is set programmatically: the host's Armor/Weapons
  -- swap carries the PTR mode across so both grids' toggles stay in sync (see SetMode).
  self._repaintPtr = function(on) ptrBorder:Color(on and gold or divider) end
  x = x + BW + GAP

  -- Wanted (★) toggle — the armor strip's, on the weapon grid's own per-appearance flags (#689).
  wantedBorder = ns.filterToggle(strip, theme, {
    x = x, atlas = ns.WantedIcon, tint = false, active = false,
    tip = function() return self._wantedOnly and "Wanted only — click to show all weapons"
                                             or  "Show only weapons you've flagged wanted" end,
    onClick = function() self:ToggleWanted() end,
  })
  -- Let other chrome (the header's wanted count) drive the same toggle and keep the button's border
  -- in sync (the star keeps its natural gold).
  self._syncWantedBtn = function() wantedBorder:Color(self._wantedOnly and gold or divider) end
  x = x + IB + GAP

  -- Sort toggle (neutral border, always-on control; the gold calendar glyph carries the direction) —
  -- the shared filter-strip button primitive, same as the armor strip's Sort toggle.
  sortIcon = select(2, ns.filterToggle(strip, theme, {
    x = x, tex = NEWEST_ICON, tint = gold,
    tip = function() return self._reverse and "Newest first — click for oldest first"
                                           or "Oldest first — click for newest first" end,
    onClick = function()
      local rev = self:ToggleOrder()
      sortIcon:Texture(rev and NEWEST_ICON or OLDEST_ICON)
      if self.onResized then self:onResized() end
    end,
  }))
  x = x + IB + GAP

  local dx = x
  ui.FilterDropdown:new{
    parent = strip, position = { TopLeft = {dx, 0} }, width = DW_EXP, menuWidth = 200,
    bordered = true, selected = "all", options = self:ExpansionOptions(),
    onSelect = function(_, key) self:SetExpansion(key); if onModeChanged then onModeChanged() end end,
  }
  ui.FilterDropdown:new{
    parent = strip, position = { TopLeft = {dx + DW_EXP + GAP, 0} }, width = DW, menuWidth = 120,
    bordered = true, selected = "all", options = self:CategoryOptions(),
    onSelect = function(_, key) self:SetCategory(key); if onModeChanged then onModeChanged() end end,
  }
  strip:Width(dx + DW_EXP + GAP + DW)
  return strip
end
