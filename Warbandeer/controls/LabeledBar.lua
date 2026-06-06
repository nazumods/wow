local _, ns = ...
local ui = ns.ui
local Class, Frame, Label, StatusBar, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.StatusBar, ui.Texture
local theme = ns.theme
local unpack = unpack
local BottomLeft, BottomRight = ui.edge.BottomLeft, ui.edge.BottomRight

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
---@field highlight  Texture   row hover highlight
---@field nameLabel  Label
---@field valueLabel Label
---@field bar        StatusBar
local LabeledBar = Class(Frame, function(self)
  local c, f = theme.colors, theme.fonts

  self.highlight = Texture:new{
    parent = self,
    layer = ui.layer.Background,
    color = {0, 0, 0, 0},
    position = { TopLeft = {-3, 3}, BottomRight = {self, BottomRight, 3, -3} },
  }

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
  self.bar = StatusBar:new{
    parent = self,
    backdrop = {},
    fill = {},
    position = {
      TopLeft = {self.nameLabel, BottomLeft, 0, -3},
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

  -- brighten on hover; swap the value for an alternate (e.g. raw paragon numbers)
  self._widget:SetMouseMotionEnabled(true)
  self:SetScript("OnEnter", function()
    self.highlight:Color(theme.colors.hover)
    if self.hoverValue then self.valueLabel:Text(self.hoverValue):Color(self.hoverColor or c.muted) end
  end)
  self:SetScript("OnLeave", function()
    self.highlight:Color(0, 0, 0, 0)
    if self.hoverValue then self.valueLabel:Text(self.value):Color(self.valueColor or c.muted) end
  end)

  self:Width(self.width)
  self:Height(self.nameLabel:Height() + 3 + self.barHeight)
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
