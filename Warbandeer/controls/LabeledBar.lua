local _, ns = ...
local ui = ns.ui
local Class, Frame, Label, StatusBar, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.StatusBar, ui.Texture
local theme = ns.theme
local unpack = unpack
local BottomRight = ui.edge.BottomRight

-- Blend a colour toward white for the hover tint. Returns r,g,b,a (alpha preserved).
local HOVER_LIGHTEN = 0.3
local function lighten(color)
  local r, g, b, a = color[1], color[2], color[3], color[4] or 1
  return r + (1 - r) * HOVER_LIGHTEN,
         g + (1 - g) * HOVER_LIGHTEN,
         b + (1 - b) * HOVER_LIGHTEN, a
end

-- A labelled progress row: name on the left, value on the right, and a thin
-- progress bar beneath. Used for reputations (and reusable for professions).
-- The fill is a manually-sized texture over a track (ExpBar pattern, avoids
-- StatusBar:SetValue quirks); both fill and track use a tintable bar texture so
-- the bar reads with some depth rather than as a flat block of color.

---@class LabeledBar: Frame
---@field label      string   left-hand name
---@field value      string   right-hand value text
---@field pct        number   fill fraction (0..1)
---@field width      number   row/bar width
---@field barHeight  number   bar thickness
---@field sliceMargin number  nine-slice corner radius (px) of the bar texture (pair with barHeight = 2*margin for pill ends)
---@field nameColor  number[]? color for the name (defaults to on-surface)
---@field valueColor number[]? color for the value (defaults to muted)
---@field barColor   number[]? fill tint (defaults to gold)
---@field trackColor number[]? track tint (defaults to neutral; paragon passes faction-dark)
---@field barAtlas     string? fill atlas (preferred over barTexture; pass false to use the file path)
---@field trackAtlas   string? track atlas (preferred over trackTexture; pass false to use the file path)
---@field barTexture   string? fill texture path (used when barAtlas is unset/false)
---@field trackTexture string? track texture path (used when trackAtlas is unset/false)
---@field hoverValue string?  alternate value text shown while the row is hovered
---@field hoverColor number[]? color for the hovered value (defaults to muted)
---@field onClick    fun(self: LabeledBar, button: string)?  optional click action; enables mouse clicks
---@field highlight  Texture   row hover highlight (behind the text; the bar lightens its own colours)
---@field nameLabel  Label
---@field valueLabel Label
---@field bar        StatusBar
local LabeledBar = Class(Frame, function(self)
  local c, f = theme.colors, theme.fonts

  -- Rounded hover backing that wraps the whole row (text + bar) with a clear margin
  -- on every side, so the bar reads as part of the highlight rather than sitting
  -- below a band around just the label. White rounded texture, tinted in on hover.
  self.highlight = Texture:new{
    parent = self,
    layer = ui.layer.Background,
    position = { TopLeft = {-5, 5}, BottomRight = {self, BottomRight, 5, -5} },
  }
  self.highlight:Texture(self.barTexture)
  self.highlight:SliceMargins(6, 6, 6, 6)
  self.highlight:SliceMode(0)
  self.highlight:SetVertexColor(1, 1, 1, 0)

  self.nameLabel = Label:new{
    parent = self,
    fontInfo = f.body,
    color = self.nameColor or c.text,
    text = self.label,
    position = { TopLeft = {0, 0} },
  }
  self.valueLabel = Label:new{
    parent = self,
    fontInfo = f.stat,
    color = self.valueColor or c.muted,
    text = self.value,
    justifyH = ui.justify.Right,
    position = { TopRight = {0, 0} },
  }
  -- Name-row height computed from the font (a FontString reports GetHeight() == 0
  -- until it's been laid out a frame later, which would leave the frame too short
  -- to cover — or receive mouse over — the bar).
  local nameH = (f.body[2] or 13) + 6
  self.bar = StatusBar:new{
    parent = self,
    backdrop = {},
    fill = {},
    position = {
      TopLeft = {0, -nameH},
      Width = self.width,
      Height = self.barHeight,
    },
  }
  -- flat color via a tintable rounded texture, nine-sliced so the ends round at
  -- any width (slice margin == corner radius). An atlas may be supplied instead.
  local m = self.sliceMargin
  if self.trackAtlas then
    self.bar.backdrop:Atlas(self.trackAtlas, false)
  else
    self.bar.backdrop:Texture(self.trackTexture)
    self.bar.backdrop:SliceMargins(m, m, m, m)
    self.bar.backdrop:SliceMode(0)
  end
  self.bar.backdrop:SetVertexColor(unpack(self.trackColor or c.track))
  if self.barAtlas then
    self.bar.fill:Atlas(self.barAtlas, false)
  else
    self.bar.fill:Texture(self.barTexture)
    self.bar.fill:SliceMargins(m, m, m, m)
    self.bar.fill:SliceMode(0)
  end
  self.bar.fill:SetVertexColor(unpack(self.barColor or c.gold))
  self.bar.fill:Width(self.width * math.max(0, math.min(1, self.pct)))

  -- brighten on hover; swap the value for an alternate (e.g. raw paragon numbers).
  -- The bar is a child frame that occludes the Background `highlight`, and an
  -- overlay wash barely registers on the already-opaque bar — so instead lighten
  -- the bar's own fill+track colours, which reads clearly and keeps the whole row
  -- looking hovered as one piece.
  self._widget:SetMouseMotionEnabled(true)
  self:SetScript("OnEnter", function()
    self.highlight:SetVertexColor(1, 1, 1, c.hover[4])
    self.bar.fill:SetVertexColor(lighten(self.barColor or c.gold))
    self.bar.backdrop:SetVertexColor(lighten(self.trackColor or c.track))
    if self.hoverValue then self.valueLabel:Text(self.hoverValue):Color(self.hoverColor or c.muted) end
  end)
  self:SetScript("OnLeave", function()
    self.highlight:SetVertexColor(1, 1, 1, 0)
    self.bar.fill:SetVertexColor(unpack(self.barColor or c.gold))
    self.bar.backdrop:SetVertexColor(unpack(self.trackColor or c.track))
    if self.hoverValue then self.valueLabel:Text(self.value):Color(self.valueColor or c.muted) end
  end)

  -- optional click action (e.g. open the relevant profession window)
  if self.onClick then
    self._widget:SetMouseClickEnabled(true)
    self:SetScript("OnMouseUp", function(_, button) self.onClick(self, button) end)
  end

  self:Width(self.width)
  self:Height(nameH + self.barHeight)
end, {
  width = 200,
  barHeight = 8,
  pct = 0,
  value = "",
  sliceMargin = 4,
  barTexture = "Interface\\AddOns\\Warbandeer\\media\\bar-rounded",
  trackTexture = "Interface\\AddOns\\Warbandeer\\media\\bar-rounded",
})
ns.LabeledBar = LabeledBar

---@param pct number fill fraction (0..1)
---@return LabeledBar
function LabeledBar:Fill(pct)
  self.bar.fill:Width(self.width * math.max(0, math.min(1, pct)))
  return self
end

---@param text string left-hand name
---@return LabeledBar
function LabeledBar:Label(text)
  self.nameLabel:Text(text)
  return self
end

-- Set the right-hand value text. Updates the stored `value` so the hover/leave
-- swap (when `hoverValue` is set) restores the new text rather than the old one.
---@param text string
---@param color number[]?
---@return LabeledBar
function LabeledBar:Value(text, color)
  self.value = text
  self.valueLabel:Text(text)
  if color then self.valueLabel:Color(color) end
  return self
end

---@param color number[] fill tint
---@return LabeledBar
function LabeledBar:BarColor(color)
  self.barColor = color
  self.bar.fill:SetVertexColor(unpack(color))
  return self
end
