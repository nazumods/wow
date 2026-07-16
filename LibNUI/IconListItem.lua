---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture
local GameTooltip = GameTooltip

-- Where the hover `tooltip` opens relative to the row, keyed "<tipCorner>/<rowCorner>" in corner
-- shorthand LL / LR / UL / UR (Lower|Upper × Left|Right). SetPoint pins the tip's corner onto the
-- row's corner, so the tip extends toward its own opposite corner; the small offset nudges it clear
-- of the edge. Pick by which way the tip should open: the default flies up-and-right ("LL/UR"), which
-- a right-docked list (e.g. Warbandeer's PetsPanel, pinned to the window's right edge) wants to avoid
-- — such a list keeps the tip within its own width ("LR/LR") or opens it leftward ("LR/LL"/"LR/UL").
local TIP_ANCHORS = {
  ["LL/UR"] = { ui.edge.BottomLeft,  ui.edge.TopRight,     2,  2 },  -- opens up + right (default)
  ["LR/UL"] = { ui.edge.BottomRight, ui.edge.TopLeft,     -2,  2 },  -- opens up + left
  ["UL/LR"] = { ui.edge.TopLeft,     ui.edge.BottomRight,  2, -2 },  -- opens down + right
  ["UR/LL"] = { ui.edge.TopRight,    ui.edge.BottomLeft,  -2, -2 },  -- opens down + left
  ["LR/LL"] = { ui.edge.BottomRight, ui.edge.BottomLeft,  -2,  0 },  -- beside, to the left  (bottoms level)
  ["LL/LR"] = { ui.edge.BottomLeft,  ui.edge.BottomRight,  2,  0 },  -- beside, to the right (bottoms level)
  ["LR/LR"] = { ui.edge.BottomRight, ui.edge.BottomRight, -2,  2 },  -- above, right edges aligned
  ["LL/LL"] = { ui.edge.BottomLeft,  ui.edge.BottomLeft,   2,  2 },  -- above, left edges aligned
}

-- A media list row: an icon (or a coloured bullet when there's no icon), a title line
-- with an optional muted "kind" suffix, and a wrapped subtitle beneath — the whole row
-- hoverable for a tooltip (`itemID` → the real item tooltip; else `tooltip` lines via
-- ui.tip, opened on the `tooltipAnchor` side). Sized for reward/inventory-style lists;
-- pairs naturally with VirtualList (build in createRow, re-point with the setters in
-- updateRow). Anchor with a width (Left+Right) so the subtitle has room to wrap.
---@class IconListItem: Frame
---@field icon string|number?   icon path/fileID; nil renders a bullet instead
---@field title string?          first-line text
---@field kind string?           muted suffix appended to the title ("Name  •  Kind")
---@field subtitle string?       wrapped second line
---@field titleColor string|table  title colour (default "text")
---@field subtitleColor string|table  subtitle colour (default "muted")
---@field iconSize number        icon square size (default 20)
---@field height number          row height (default 32) — intrinsic, survives any `position`; a VirtualList updateRow's returned height overrides it
---@field itemID number?         hover shows this item's real tooltip
---@field tooltip string|string[]?  hover tooltip lines when there's no itemID
---@field tooltipAnchor string   which way the `tooltip` opens; a TIP_ANCHORS key (default "LL/UR" — up-and-right)
---@field titleLabel Label
---@field subtitleLabel Label
---@field _icon Texture
local IconListItem = Class(Frame, function(self)
  self:Height(self.height)   -- intrinsic (a caller's position table would replace a position default)
  self._icon = Texture:new{
    parent = self, layer = ui.layer.Artwork,
    coords = {0.08, 0.92, 0.08, 0.92},
    position = { TopLeft = {self, ui.edge.TopLeft, 0, -1}, Size = {self.iconSize, self.iconSize} },
  }

  local textLeft = self.iconSize + 6
  self.titleLabel = Label:new{
    parent = self, color = self.titleColor, justifyH = ui.justify.Left, wordWrap = false,
    position = {
      TopLeft  = {self, ui.edge.TopLeft, textLeft, -1},
      TopRight = {self, ui.edge.TopRight, 0, -1},
    },
  }
  self.subtitleLabel = Label:new{
    parent = self, color = self.subtitleColor, justifyH = ui.justify.Left,
    font = ui.fonts.GameFontHighlightSmall,
    position = {
      TopLeft  = {self.titleLabel, ui.edge.BottomLeft, 0, -2},
      TopRight = {self, ui.edge.TopRight, 0, 0},
    },
  }

  self:Set{ icon = self.icon, title = self.title, kind = self.kind,
            subtitle = self.subtitle, itemID = self.itemID, tooltip = self.tooltip }

  self._widget:EnableMouse(true)
  self._widget:SetScript("OnEnter", function()
    if self.itemID then
      GameTooltip:SetOwner(self._widget, "ANCHOR_RIGHT")
      GameTooltip:SetItemByID(self.itemID)
      GameTooltip:Show()
    elseif self.tooltip then
      local lines = type(self.tooltip) == "table" and self.tooltip or {self.tooltip}
      ui.tip:ClearLines()
      for _, l in ipairs(lines) do ui.tip:AddLine(l) end
      ui.tip:ClearAllPoints()
      local a = TIP_ANCHORS[self.tooltipAnchor] or TIP_ANCHORS["LL/UR"]
      ui.tip:SetPoint(a[1], self._widget, a[2], a[3], a[4])
      ui.tip:Show()
    end
  end)
  self._widget:SetScript("OnLeave", function()
    GameTooltip:Hide()
    ui.tip:Hide()
  end)
end, {
  type          = "Frame",
  titleColor    = "text",
  subtitleColor = "muted",
  iconSize      = 20,
  height        = 32,
  tooltipAnchor = "LL/UR",
})
ui.IconListItem = IconListItem

-- Re-point the whole row at new content (the updateRow path for pooled reuse). Absent
-- keys clear that part: no icon → bullet glyph, no kind → bare title, no subtitle →
-- empty second line. itemID/tooltip swap what hover shows.
---@param data { icon: (string|number)?, title: string?, kind: string?, subtitle: string?, itemID: number?, tooltip: (string|string[])? }
---@return IconListItem
function IconListItem:Set(data)
  self.icon, self.itemID, self.tooltip = data.icon, data.itemID, data.tooltip
  if data.icon then
    self._icon:Texture(data.icon)
    self._icon:Alpha(1)
  else
    -- no icon: hide the texture and let the bullet in the title carry the row
    self._icon:Alpha(0)
  end
  local title = data.title or ""
  if not data.icon then title = "•  " .. title end
  if data.kind then title = title .. "  •  " .. data.kind end
  self.titleLabel:Text(title)
  self.subtitleLabel:Text(data.subtitle or "")
  return self
end
