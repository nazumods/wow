---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class, max = ns.lua.Class, math.max
local Frame, ScrollFrame, Label = ui.Frame, ui.ScrollFrame, ui.Label

-- A pooled, variable-height, mixed-row-type list — the complement to TableFrame's fixed
-- grid. Owns a scrolling viewport (themed auto-hiding scrollbar) and a pool of row frames
-- per "type"; SetItems(items) stacks one row per item top-to-bottom, reusing rows across
-- rebuilds and hiding the surplus. Each row anchors left+right to the content child, so
-- rows reflow width on resize. It is NOT windowed — it builds a frame per item (fine for
-- the dozens-to-hundreds a panel shows), not only the on-screen ones.
--
-- Single-type lists pass `createRow`/`updateRow`; mixed-type lists (e.g. Accordion) pass a
-- `rowTypes` map plus `typeOf(item)`. A row builder parents its row to `list:Content()`;
-- `update` populates the reused row for an item and returns its height.
---@class VirtualList: Frame
---@field spacing number     vertical gap between rows in px (default 2)
---@field padding number     inset around the stacked rows in px (default 4)
---@field rowHeight number   fallback row height when an update returns nil (default 20)
---@field scrollbar boolean  themed scrollbar on the viewport (default true)
---@field emptyText string?  muted placeholder shown centred when SetItems gets an empty list
---@field _empty Label?      the lazy empty-state label
---@field items any[]?       initial items
---@field createRow fun(list: VirtualList): Frame  single-type: build one blank pooled row
---@field updateRow fun(list: VirtualList, row: Frame, item: any, index: integer): number?  populate; return height
---@field rowTypes table<string, {create: fun(list: VirtualList): Frame, update: fun(list: VirtualList, row: Frame, item: any, index: integer): number?}>?  multi-type variant
---@field typeOf fun(item: any, index: integer): string  which rowType an item uses (default: item.type)
---@field scroll ScrollFrame
---@field _child Frame
---@field _typeOf fun(item: any, index: integer): string
---@field _pools table<string, Frame[]>
---@field _items any[]
---@field _rowAt Frame[]      item index → the live pooled row showing it (for :Row)
---@field _topAt number[]     item index → its row's top offset in the content child (for :ScrollToItem)
---@field _hAt number[]       item index → its row's height (for :ScrollToItem)
local VirtualList = Class(Frame, function(self)
  self.scroll = ScrollFrame:new{
    parent    = self,
    scrollbar = self.scrollbar,
    position  = { All = true },
  }
  self._child = Frame:new{ parent = self.scroll, position = { Size = {1, 1} } }
  self.scroll:Child(self._child)

  -- Normalise the single-type convenience form into the rowTypes map.
  if self.createRow then
    self.rowTypes = { default = { create = self.createRow, update = self.updateRow } }
    self._typeOf = function() return "default" end
  else
    self._typeOf = self.typeOf or function(item) return item.type end
  end

  self._pools = {}
  for name in pairs(self.rowTypes) do self._pools[name] = {} end
  self._items = {}
  self._rowAt, self._topAt, self._hAt = {}, {}, {}

  -- Rows anchor left+right to the child, so a width change reflows them; only the child
  -- width needs updating on resize (the scroll range is driven by content height).
  self.scroll._widget:SetScript("OnSizeChanged", function() self:_syncWidth() end)

  if self.items then self:SetItems(self.items) end
end, {
  type      = "Frame",
  spacing   = 2,
  padding   = 4,
  rowHeight = 20,
  scrollbar = true,
})
ui.VirtualList = VirtualList

-- The content child that rows parent to. Row builders anchor into this frame.
---@return Frame
function VirtualList:Content() return self._child end

-- Fit the content child to the viewport width (minus the scrollbar gutter), so rows
-- span the visible width and never trigger horizontal scroll.
function VirtualList:_syncWidth()
  local w = (self.scroll:Width() or 0)
  if self.scrollbar then w = w - (self.scroll.scrollbarWidth or 16) end
  self._child:Width(max(1, w))
end

-- (Re)render: acquire/reuse one row per item, stack them, hide the surplus, size the
-- content child, and refresh the scroll range.
---@param items any[]
---@return VirtualList
function VirtualList:SetItems(items)
  self._items = items or {}
  self:_layout()
  return self
end

-- Re-run the layout with the current items (e.g. after a row's height changed).
---@return VirtualList
function VirtualList:Refresh()
  self:_layout()
  return self
end

-- The live pooled row frame currently displaying item `index` (nil when out of range).
-- Lets a consumer decorate the on-screen row for a *selectable* list — e.g. toggle a
-- selection overlay on it. Single-type pools map slot⇒item-index 1:1, so this is exact.
---@param index integer
---@return Frame?
function VirtualList:Row(index)
  if not index or index < 1 or index > #self._items then return nil end
  return self._rowAt[index]
end

-- Scroll item `index` minimally into view: only when its row sits above or below the
-- current viewport (mirrors a plain list's arrow-key scroll-into-view). No-op when the
-- viewport height isn't resolved yet, so a pre-layout call can't mis-scroll.
---@param index integer
---@return VirtualList
function VirtualList:ScrollToItem(index)
  if not index or index < 1 or index > #self._items then return self end
  local top, h = self._topAt[index], self._hAt[index]
  local viewH = self.scroll._widget:GetHeight()
  if viewH <= 0 then viewH = self._widget:GetHeight() end
  local cur = self.scroll:VerticalScroll()
  if top < cur then
    self.scroll:VerticalScroll(top)
  elseif viewH > 0 and top + h > cur + viewH then
    self.scroll:VerticalScroll(top + h - viewH)
  end
  return self
end

function VirtualList:_layout()
  self:_syncWidth()

  local used = {}
  for name in pairs(self.rowTypes) do used[name] = 0 end

  local pad, spacing = self.padding, self.spacing
  local yCur = pad

  for i, item in ipairs(self._items) do
    local t    = self._typeOf(item, i)
    local def  = self.rowTypes[t]
    local pool = self._pools[t]
    used[t] = used[t] + 1
    local row = pool[used[t]]
    if not row then
      row = def.create(self)
      pool[used[t]] = row
    end
    local h = def.update(self, row, item, i) or self.rowHeight
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self._child, "TOPLEFT", pad, -yCur)
    row:SetPoint("RIGHT",   self._child, "RIGHT",  -pad, 0)
    row:Height(h)
    row:Show()
    self._rowAt[i], self._topAt[i], self._hAt[i] = row, yCur, h
    yCur = yCur + h + spacing
  end

  -- Hide the rows each pool didn't use this pass.
  for name, pool in pairs(self._pools) do
    for j = used[name] + 1, #pool do pool[j]:Hide() end
  end

  -- empty state: a muted centred placeholder instead of a blank viewport
  if self.emptyText then
    if #self._items == 0 and not self._empty then
      self._empty = Label:new{
        parent   = self,
        text     = self.emptyText,
        color    = "muted",
        position = { Center = {} },
      }
    end
    if self._empty then self._empty:SetShown(#self._items == 0) end
  end

  local contentH = (#self._items > 0) and (yCur - spacing + pad) or (pad * 2)
  self._child:Height(max(1, contentH))
  self.scroll:Refresh()
end
