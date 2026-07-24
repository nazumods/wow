---@type Warbandeer_Collected
local ns = select(2, ...)
local max = math.max
local ui = ns.ui
local Colors = ns.Colors
local Class = ns.lua.Class
local TableFrame = ui.TableFrame
local lists, prepend = ns.lua.lists, ns.lua.lists.prepend
local GameTooltip = GameTooltip

---The Weapons grid (the Armor/Weapons toggle's weapon view): one row per weapon SOURCE, one column
---per weapon TYPE, each cell the uncollected-appearance count shaded by completion (green check when
---complete) — the identical cell renderer as the armor DataView. A standalone TableFrame subclass
---(NOT a DataView subclass), so the battle-tested armor grid is untouched. Row builder, counts, and
---the hover tooltip live in WeaponViewData.lua; the collected lookup is ns:WeaponCollectedMap.
---@class WeaponView: TableFrame
---@field _reverse boolean? sort by expansion newest-first (release 12→1; defaults true)
---@field _expansion number|string? release filter — a release index, or "all"
---@field _category string? category filter — a category name, or "all"
---@field onResized fun(self: WeaponView)? host hook fired after a filter/sort change resizes the row area
---@field onEnsureVisible fun(self: WeaponView, rowTop: number, rowH: number)? host hook to scroll a row into view (see HighlightWeaponCell)
---@field _dressedBox Frame? the white 4-edge cursor box re-anchored over the dressed weapon cell (created lazily)
---@field _dressedSource table? source group currently previewed in the shared dressing room (drives the cell cursor; nil = none)
---@field _dressedType number? weapon type currently previewed (with _dressedSource, pins the exact cell)
local WeaponView = Class(TableFrame, function(self)
  -- Autosize the name column (col 1) to the widest source name (+ its expansion badge).
  local w = 0
  for _, r in ipairs(self.cells) do
    if #r > 1 and r[1].label then w = max(w, r[1].label:Width()) end
  end
  self.cols[1]:Width(w)
  self.rowArea:Width(self.rowArea:Width() + w)
  self:Width(self:Width() + w)
end, {
  headerHeight = 28,
  _reverse = true,
  _expansion = "all",
  _category = "all",
  -- Row builder lives in WeaponViewData.lua; the base TableFrame calls it via GetData in onLoad.
  GetData = function(self) return ns.WeaponRows(self) end,
})

-- Variable-height rebuild (the visible row count changes with the filter): grow the pool for new
-- rows, pad shrinking data with blank-string cells so stale rows blank, base update, then hide the
-- dead rows below the active count. Mirrors DataView:update (minus the armor-only marks/cursor).
function WeaponView:update()
  local real = #self.data
  for _ = #self.rows + 1, real do self:addRow{} end
  if real < #self.rows then
    local blank = {}
    for c = 1, #self.cols do blank[c] = "" end
    for i = real + 1, #self.rows do self.data[i] = blank end
  end
  TableFrame.update(self)
  self:ResizeRows(real)
  -- Cells are reassigned by the rebuild, so re-resolve the dressed-weapon cursor onto the
  -- cell that still matches (source, type) — the weapon analogue of DataView re-resolving
  -- HighlightSet after a re-sort. No scroll: a passive rebuild shouldn't yank the view.
  self:HighlightWeaponCell(self._dressedSource, self._dressedType, false)
end

WeaponView.MAX_HEIGHT = 460
WeaponView.STRIP_H = 20

-- Box the exact cell of the weapon currently previewed in the shared dressing room, following it as
-- ←/→ steps across weapon-type columns (same source row). Keyed by (source, type) — the identity
-- stamped on each cell's data in WeaponRows. Broadcast from the room via ns:OnDressedWeaponCellChanged;
-- nil (close / an armour set shown) hides it. `scroll` brings the cell's row into view (via the host's
-- onEnsureVisible hook). The cursor box + cell scan are shared with the armor grid — see
-- ns.HighlightGridCell / ns.EnsureDressedCursor (the weapon analogue of DataView:HighlightSet).
---@param source table?  the previewed source group, or nil to clear the cursor
---@param weaponType number?  the previewed weapon type (pins the column)
---@param scroll boolean?  scroll the matched cell's row into view
function WeaponView:HighlightWeaponCell(source, weaponType, scroll)
  self._dressedSource = source
  self._dressedType = weaponType
  ns.HighlightGridCell(self, source and function(data)
    return data._source == source and data._type == weaponType
  end or nil, scroll)
end

-- Column layout: an autosized name column (col 1) then one narrow column per weapon type
-- (abbreviated caption + full-name header tooltip). No lock column — weapons have no lockouts.
---@return table
function WeaponView.BuildColInfo()
  local cols = lists.map(ns.WeaponTypeOrder, function(t)
    return { name = ns.WeaponTypeAbbr[t], width = 34, padding = 2, justifyH = ui.justify.Center,
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
---@return boolean
function WeaponView:ToggleOrder()
  self._reverse = not self._reverse
  self.data = self:GetData()
  self:update()
  return self._reverse
end
---@return number, number, number
function WeaponView:VisibleCounts() return ns.WeaponVisibleCounts(self) end

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

-- Tooltip for the header counter (shared wording; the host wires its own hover frame over the label).
---@param owner table  the WoW frame the tooltip anchors to
function WeaponView:ShowCountTooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_BOTTOMRIGHT")
  GameTooltip:SetText("Collected weapon totals")
  GameTooltip:AddLine("|cffffffffsources|r — weapon-source rows shown for the current filter.", 0.8, 0.8, 0.8, true)
  GameTooltip:AddLine("|cffffffffappearances|r — individual weapon looks across those sources.", 0.8, 0.8, 0.8, true)
  GameTooltip:AddLine("|cffffffffcollected|r — looks you've collected.", 0.8, 0.8, 0.8, true)
  GameTooltip:Show()
end

-- Filter strip for the weapon grid: a Sort toggle + Expansion / Category dropdowns (no PTR/Wanted —
-- those are armor concepts). The Armor/Weapons mode toggle is host-owned (persistent across both
-- grids). Themed from the grid, matching DataView:BuildFilterStrip's look.
---@param parent table
---@return Frame
function WeaponView:BuildFilterStrip(parent)
  local theme = self:Theme()
  local gold = theme.colors.gold or theme.colors.header
  local BH, GAP, DW, DW_EXP = WeaponView.STRIP_H, 6, 110, 190
  local IB = BH
  local TEX = [[Interface\AddOns\Warbandeer_Collected\textures\]]
  local NEWEST_ICON, OLDEST_ICON = TEX .. "sort-newest", TEX .. "sort-oldest"
  local strip = ui.Frame:new{ parent = parent, position = { Height = BH } }

  -- Sort toggle (neutral border, always-on control; the gold calendar glyph carries the direction) —
  -- the shared filter-strip button primitive, same as the armor strip's Sort toggle.
  local sortIcon
  sortIcon = select(2, ns.filterToggle(strip, theme, {
    x = 0, tex = NEWEST_ICON, tint = gold,
    tip = function() return self._reverse and "Newest first — click for oldest first"
                                           or "Oldest first — click for newest first" end,
    onClick = function()
      local rev = self:ToggleOrder()
      sortIcon:Texture(rev and NEWEST_ICON or OLDEST_ICON)
      if self.onResized then self:onResized() end
    end,
  }))

  local dx = IB + GAP
  ui.FilterDropdown:new{
    parent = strip, position = { TopLeft = {dx, 0} }, width = DW_EXP, menuWidth = 200,
    bordered = true, selected = "all", options = self:ExpansionOptions(),
    onSelect = function(_, key) self:SetExpansion(key) end,
  }
  ui.FilterDropdown:new{
    parent = strip, position = { TopLeft = {dx + DW_EXP + GAP, 0} }, width = DW, menuWidth = 120,
    bordered = true, selected = "all", options = self:CategoryOptions(),
    onSelect = function(_, key) self:SetCategory(key) end,
  }
  strip:Width(dx + DW_EXP + GAP + DW)
  return strip
end

---@class Warbandeer_Collected
---@field WeaponView WeaponView
ns.WeaponView = WeaponView

-- Share the weapon grid with sibling addons (Warbandeer's embedded collected view) via the API
-- global, so both hosts build it from this one place. api.lua loads first, so the table exists.
_G.WarbandeerCollectedApi.WeaponView = WeaponView
