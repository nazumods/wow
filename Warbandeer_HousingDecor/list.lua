---@type Warbandeer_HousingDecor
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Label, Texture, ScrollFrame = ui.Frame, ui.Label, ui.Texture, ui.ScrollFrame
local ITEM_QUALITY_COLORS, IsShiftKeyDown = ITEM_QUALITY_COLORS, IsShiftKeyDown
local max, min, floor, ceil = math.max, math.min, math.floor, math.ceil

-- A windowed decor list: one row per entry, but only the rows in view (+ a small buffer)
-- are ever built and are recycled as you scroll — the housing catalog runs to ~1800
-- entries, far too many to give a live frame each (LibNUI's VirtualList builds all of
-- them). The scroll child is sized to the full list height so the scrollbar spans
-- everything; a pool of ~two-dozen rows is repositioned/repopulated on every scroll.
--
-- Each row is a Button (so it gets hover + click), carrying a quality-ringed icon (with a
-- gold star when a first-acquisition House XP bonus is still claimable), the quality-
-- colored name, a right-aligned owned count, and a right-edge wanted star. Shift-click
-- toggles wanted; hover raises the shared GameTooltip InfoTip.

local ROW_H = 28
local ICON = 22
local BUFFER = 4                                    -- rows kept live above/below the viewport
local BONUS_ATLAS = "auctionhouse-icon-favorite"    -- gold star, same as HousingVendor's bonus badge
local QMARK = 134400                                -- INV_Misc_QuestionMark, icon fallback
local OWNED_COLOR = { 0.36, 0.80, 0.47, 1 }         -- green owned-count text
local BORDER_MUTED = { 0.28, 0.28, 0.30, 1 }        -- icon ring for un-qualitied decor

-- A quality's rgb as a plain {r,g,b,1} table (Label/Texture Color inputs), or nil.
---@param q number?  ItemQuality
---@return number[]?
local function qualityColor(q)
  local c = q and ITEM_QUALITY_COLORS[q]
  if not c then return nil end
  return { c.r, c.g, c.b, 1 }
end

-- Whether an id-list (entry.categoryIDs / subcategoryIDs) contains a specific id.
---@param list number[]?
---@param id number
---@return boolean
local function hasId(list, id)
  if not list then return false end
  for _, v in ipairs(list) do if v == id then return true end end
  return false
end

-- Build one pooled row. It is a Button with mouse motion enabled so OnEnter/OnLeave fire
-- (a child button would capture clicks but not hover). The window positions/sizes the row
-- itself; children anchor to its edges.
---@param list HousingDecorList
---@return Frame
local function createRow(list)
  local row = Frame:new{ type = "Button", parent = list._content }
  row._widget:SetMouseMotionEnabled(true)
  row._widget:SetMouseClickEnabled(true)

  row._hl = Texture:new{
    parent = row, layer = ui.layer.Background, color = { 1, 1, 1, 0 },
    position = { All = true },
  }
  -- Icon: a thin quality-colored ring (outer) around a dark backing, with the icon on
  -- top. Decor icons carry their own transparency, so a filled quality square would bleed
  -- through as a solid block — the dark backing fills those gaps, leaving a 1px ring.
  row._iconBorder = Texture:new{
    parent = row, layer = ui.layer.Background, color = BORDER_MUTED,
    position = { Left = { row, ui.edge.Left, 4, 0 }, Size = { ICON + 2, ICON + 2 } },
  }
  row._iconBg = Texture:new{
    parent = row, layer = ui.layer.Border, color = { 0.04, 0.04, 0.05, 1 },
    position = {
      TopLeft = { row._iconBorder, ui.edge.TopLeft, 1, -1 },
      BottomRight = { row._iconBorder, ui.edge.BottomRight, -1, 1 },
    },
  }
  row._icon = Texture:new{
    parent = row, layer = ui.layer.Artwork,
    position = {
      TopLeft = { row._iconBg, ui.edge.TopLeft },
      BottomRight = { row._iconBg, ui.edge.BottomRight },
    },
  }
  row._bonus = Texture:new{
    parent = row, layer = ui.layer.Overlay, atlas = BONUS_ATLAS,
    position = { TopLeft = { row._iconBorder, ui.edge.TopLeft, -3, 3 }, Size = { 12, 12 }, Hide = true },
  }
  row._star = Texture:new{
    parent = row, layer = ui.layer.Overlay, atlas = ns.WantedIcon,
    position = { Right = { row, ui.edge.Right, -6, 0 }, Size = { 16, 16 }, Hide = true },
  }
  row._owned = Label:new{
    parent = row, justifyH = ui.justify.Right, wordWrap = false, color = OWNED_COLOR,
    position = { Right = { row, ui.edge.Right, -26, 0 } },
  }
  row._name = Label:new{
    parent = row, justifyH = ui.justify.Left, wordWrap = false, color = "text",
    position = {
      Left = { row._iconBorder, ui.edge.Right, 8, 0 },
      Right = { row._owned, ui.edge.Left, -6, 0 },
    },
  }

  row._widget:SetScript("OnEnter", function() list:_onRowEnter(row) end)
  row._widget:SetScript("OnLeave", function() list:_onRowLeave(row) end)
  row._widget:SetScript("OnMouseUp", function() list:_onRowClick(row) end)
  return row
end

-- Populate a pooled row for one entry.
---@param row Frame
---@param item HousingDecorEntry
local function updateRow(row, item)
  row._item = item

  -- Atlas sets its own texcoords; a file icon needs the standard border crop re-applied
  -- (a pooled row may have shown an atlas last, which left atlas coords behind).
  if item.iconAtlas then
    row._icon:Atlas(item.iconAtlas)
  else
    row._icon:Texture(item.iconTexture or QMARK)
    row._icon:Coords(0.08, 0.92, 0.08, 0.92)
  end

  local qc = qualityColor(item.quality)
  if qc then row._iconBorder:Color(qc[1], qc[2], qc[3], 1)
  else row._iconBorder:Color(BORDER_MUTED[1], BORDER_MUTED[2], BORDER_MUTED[3], 1) end

  row._name:Text(item.name)
  row._name:Color(qc or "text")
  row._hl:Color(1, 1, 1, 0)   -- reset the hover tint when a pooled row is reassigned

  row._bonus:SetShown(item.bonusAvailable)
  row._owned:Text(item.owned and item.total > 0 and tostring(item.total) or "")
  row._star:SetShown(ns:IsWanted(item.recordID))
end

---The shared decor list — the standalone window and Warbandeer's embedded decor view both
---render this one class (single source of truth). `embedded` is a marker for the host.
---Filter state lives here; the filter chrome is built by `BuildFilterStrip` (filters.lua).
---@class HousingDecorList: Frame
---@field embedded boolean?        rendered inside a host view (vs the standalone window)
---@field scroll ScrollFrame       the scrolling viewport
---@field _content Frame           full-height scroll child (sized to #_shown * ROW_H)
---@field _rows Frame[]            the recycled row pool
---@field _empty Label             filtered-empty placeholder
---@field _category number|string  category filter — a categoryID, or "all"
---@field _subcategory number|string  subcategory filter — a subcategoryID, or "all"
---@field _uncollected boolean     show only decor you don't own
---@field _wantedOnly boolean      show only decor flagged wanted
---@field _search string           lowercased name-substring filter ("" = off)
---@field _shown HousingDecorEntry[]  the currently-filtered entries — VisibleCounts reads this
---@field onFilterChanged fun(self: HousingDecorList)?  fired after any filter change (recompute the host counter)
---@field _syncWantedBtn fun()?    set by BuildFilterStrip to keep the WANTED toggle's highlight in sync
local HousingDecorList = Class(Frame, function(self)
  self._rows = {}
  self._shown = {}

  self.scroll = ScrollFrame:new{ parent = self, scrollbar = true, position = { All = true } }
  self._content = Frame:new{ parent = self.scroll, position = { Size = { 1, 1 } } }
  self.scroll:Child(self._content)

  -- A zero-size, invisible bottom spacer keeps the scroll child's *content extent* at the
  -- full list height even though only the windowed rows are live children — WoW derives
  -- the scroll range from that extent, so without it you couldn't scroll past the pool.
  self._spacer = Texture:new{
    parent = self._content, layer = ui.layer.Background, color = { 0, 0, 0, 0 },
    position = { TopLeft = { self._content, ui.edge.TopLeft }, Size = { 1, 1 } },
  }

  self._empty = Label:new{
    parent = self, color = "muted", justifyH = ui.justify.Center,
    position = { Center = {}, Hide = true }, text = "No decor matches these filters.",
  }

  -- Re-window on every scroll and on resize (the visible row count depends on the height).
  self.scroll._widget:HookScript("OnVerticalScroll", function() self:_window() end)
  self.scroll._widget:HookScript("OnSizeChanged", function() self:_syncWidth(); self:_window() end)

  self:Render()
end, {
  type = "Frame",
  embedded = false,
  _category = "all",
  _subcategory = "all",
  _uncollected = false,
  _wantedOnly = false,
  _search = "",
})

-- Height (px) of the filter strip (BuildFilterStrip); hosts offset the list below it.
HousingDecorList.STRIP_H = 22

-- Fit the scroll child to the viewport width (minus the scrollbar gutter) so rows span it.
function HousingDecorList:_syncWidth()
  local w = (self.scroll:Width() or 0) - (self.scroll.scrollbarWidth or 16)
  self._content:Width(max(1, w))
end

-- Recycle the row pool onto the entries currently in view (+ a buffer), positioning each
-- at its absolute offset in the full-height scroll child.
function HousingDecorList:_window()
  local items = self._shown
  local n = #items
  if n == 0 then
    for _, row in ipairs(self._rows) do row:Hide() end
    return
  end

  local viewH = self.scroll:Height() or 0
  if viewH <= 0 then viewH = self:Height() or 0 end
  local offset = self.scroll:VerticalScroll() or 0
  local first = max(1, floor(offset / ROW_H) + 1 - BUFFER)
  local last = min(n, first + ceil(viewH / ROW_H) + BUFFER * 2 - 1)

  local p = 0
  for idx = first, last do
    p = p + 1
    local row = self._rows[p]
    if not row then row = createRow(self); self._rows[p] = row end
    updateRow(row, items[idx])
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self._content, "TOPLEFT", 0, -(idx - 1) * ROW_H)
    row:SetPoint("RIGHT", self._content, "RIGHT", 0, 0)
    row:Height(ROW_H)
    row:Show()
  end
  for i = p + 1, #self._rows do self._rows[i]:Hide() end
end

---Filter + sort the live snapshot into the rows to show (alphabetical by name).
---@return HousingDecorEntry[]
function HousingDecorList:GetItems()
  local out = {}
  local cat, sub = self._category, self._subcategory
  local uncollectedOnly, wantedOnly, search = self._uncollected, self._wantedOnly, self._search
  for _, e in ipairs(ns._entries) do
    local ok = true
    if cat ~= "all" and not hasId(e.categoryIDs, cat) then ok = false end
    if ok and sub ~= "all" and not hasId(e.subcategoryIDs, sub) then ok = false end
    if ok and uncollectedOnly and e.owned then ok = false end
    if ok and wantedOnly and not ns:IsWanted(e.recordID) then ok = false end
    if ok and search ~= "" and not e.name:lower():find(search, 1, true) then ok = false end
    if ok then out[#out + 1] = e end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

---Re-run the filter, resize the scroll child to the full list, re-window, and let the
---host recompute its counter.
function HousingDecorList:Render()
  self._shown = self:GetItems()
  local n = #self._shown
  self._content:Height(max(1, n * ROW_H))
  self._spacer:ClearAllPoints()
  self._spacer:SetPoint("TOPLEFT", self._content, "TOPLEFT", 0, -max(0, n * ROW_H - 1))
  self:_syncWidth()
  self.scroll:Refresh()          -- re-clamp the offset into the new range
  self:_window()
  self._empty:SetShown(n == 0)
  if self.onFilterChanged then self:onFilterChanged() end
end

-- Hosts refresh via Render(); keep an alias so either name works.
HousingDecorList.Refresh = HousingDecorList.Render

---Shown / owned counts for the current filter (drives the header "X / Y collected").
---@return number shown, number collected
function HousingDecorList:VisibleCounts()
  local shown, collected = 0, 0
  for _, e in ipairs(self._shown or {}) do
    shown = shown + 1
    if e.owned then collected = collected + 1 end
  end
  return shown, collected
end

-- ─── Row interaction ─────────────────────────────────────────────────────────

function HousingDecorList:_onRowEnter(row)
  row._hl:Color(1, 1, 1, 0.06)
  ns.ShowInfoTip(row._item, row)
end

function HousingDecorList:_onRowLeave(row)
  row._hl:Color(1, 1, 1, 0)
  ns.HideInfoTip()
end

-- Shift-click flags/unflags the row's decor as wanted. ToggleWanted fires
-- NotifyRatingsChanged, and each host's OnRatingsChanged listener re-renders its list
-- (updating the stars and the wanted-only filter) and header tally — so a toggle here also
-- refreshes a second list open elsewhere. A plain click is a no-op (hover shows the detail).
function HousingDecorList:_onRowClick(row)
  if not IsShiftKeyDown() then return end
  ns:ToggleWanted(row._item.recordID)
  ns.RefreshInfoTip()
end

---@class Warbandeer_HousingDecor
---@field List HousingDecorList
ns.List = HousingDecorList

-- Share the list class with sibling addons (Warbandeer's embedded decor view) via the API
-- global, so it's maintained in this one place. api.lua loads first, so the table already
-- exists; consumers build it with `embedded = true`.
_G.WarbandeerHousingDecorApi.List = HousingDecorList
