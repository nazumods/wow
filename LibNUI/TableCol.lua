---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class, BgFrame, Frame, Texture = ns.lua.Class, ui.BgFrame, ui.Frame, ui.Texture

local ARROW_UP, ARROW_DOWN = "Interface/Buttons/Arrow-Up-Up", "Interface/Buttons/Arrow-Down-Up"
local ARROW_SZ = 10   -- matches SortableHeaderRow's arrow footprint

---@class TableCol: BgFrame
---@field header Frame   the header strip (a Frame so it can carry tooltip/click scripts); exposes `.label` / `.texture` / `.button` from its AutoWidget content for compatibility
---@field tooltip string|string[]? text (or list of lines) shown when hovering the header
---@field tooltipMaxWidth number? width cap (px) for the header tooltip (default 240)
---@field sortable boolean?  makes the header clickable + reserves room for a sort arrow
---@field onHeaderClick fun()?  fired when a sortable header is clicked (TableFrame drives the sort state)
---@field _sortArrow Texture?  up/down sort indicator, shown only while this column is the active sort
---@field _sortActiveColor string?  label colour token used while this column is the active sort
local TableCol = Class(BgFrame, function(self)
  local p = self.padding or 0

  -- The header is its own Frame at the top of the col so it can carry mouse
  -- scripts (for tooltips). Putting OnEnter directly on the col frame would
  -- fire across the entire column, because cells without their own onEnter
  -- don't intercept mouse motion. A sortable header is a Button so OnClick works
  -- alongside the tooltip's OnEnter/OnLeave.
  self.header = Frame:new{
    parent = self,
    type = self.sortable and "Button" or "Frame",
    name = self.name and self.name.."Header" or nil,
    position = {
      TopLeft = {0, 0},
      TopRight = {0, 0},
      Height = self.headerHeight,
    },
  }

  local contentPosition
  if self.path or (self.atlas and self.atlasSize == false) then
    -- icons would otherwise stretch to fill the header rect (path has no
    -- atlas-size constraint; atlas with atlasSize=false explicitly disables
    -- native sizing). Pin them to a centered square at the top of the header.
    local size = self.headerHeight - 2 * p
    contentPosition = {
      Top = {self.iconOffsetX or 0, -p},
      Size = {size, size},
    }
  else
    -- Reserve room on the right for the sort arrow so a label can't overlap it.
    local rInset = self.sortable and (p + ARROW_SZ + 2) or p
    contentPosition = {
      TopLeft = {p, -p},
      BottomRight = {-rInset, p},
    }
  end
  local content = ui.AutoWidget:new{
    parent = self.header,
    -- label
    label = self.label,
    font = self.font,
    fontInfo = not self.font and self:Theme().fonts.header or nil,
    color = self.color or "header",
    justifyH = self.justifyH or ui.justify.Center,
    justifyV = ui.justify.Middle,
    -- texture
    atlas = self.atlas,
    atlasSize = self.atlasSize,
    path = self.path,
    coords = self.coords,
    vertexColor = self.vertexColor,
    layer = (self.path or self.atlas) and ns.ui.layer.Artwork,
    position = contentPosition,
  }
  -- surface the inner widget so existing code (TableFrame:Autosize) that does
  -- `col.header.label` keeps working.
  self.header.label = content.label
  self.header.texture = content.texture
  self.header.button = content.button

  -- Sortable header: the Button built above reports clicks to onHeaderClick (TableFrame
  -- owns the sort state); the label rests muted and brightens to the accent when active,
  -- with an up/down arrow — SortableHeaderRow parity.
  if self.sortable then
    self._sortActiveColor = self.color or "header"
    if content.label then content.label:Color("muted") end
    self._sortArrow = Texture:new{
      parent   = self.header,
      layer    = ui.layer.Artwork,
      path     = ARROW_UP,
      position = { Right = {self.header, -1, 0}, Size = {ARROW_SZ, ARROW_SZ}, Hide = true },
    }
    self.header:SetScript("OnClick", function()
      if self.onHeaderClick then self.onHeaderClick() end
    end)
  end

  if self.tooltip then
    local lines = type(self.tooltip) == "table" and self.tooltip or {self.tooltip}
    local maxW = self.tooltipMaxWidth or 240
    self.header:SetScript("OnEnter", function()
      ui.tip:ClearLines()
      ui.tip:MaxWidth(maxW)
      for _,l in ipairs(lines) do ui.tip:AddLine(l) end
      ui.tip:ClearAllPoints()
      -- Top-right of the header: tooltip's BottomLeft sits at the header's
      -- TopRight, so it rises up and extends to the right.
      ui.tip:SetPoint(ui.edge.BottomLeft, self.header, ui.edge.TopRight, 2, 2)
      ui.tip:Show()
    end)
    self.header:SetScript("OnLeave", function()
      ui.tip:Hide()
      ui.tip:MaxWidth(nil)
    end)
  end
end)
ui.TableCol = TableCol

-- Style this header for the current sort state: active => accent label + arrow (up =
-- ascending, down = descending); inactive => muted label, arrow hidden. No-op for a
-- non-sortable column.
---@param active boolean
---@param descending boolean
function TableCol:SetSortState(active, descending)
  if not self._sortArrow then return end
  self.header.label:Color(active and self._sortActiveColor or "muted")
  self._sortArrow:SetShown(active)
  if active then self._sortArrow:Texture(descending and ARROW_DOWN or ARROW_UP) end
end
