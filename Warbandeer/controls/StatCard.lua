---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Class, Frame, Label, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.Texture
local theme = ns.theme
local BottomLeft, Right = ui.edge.BottomLeft, ui.edge.Right

-- A single "stat" tile for the summary strip: a small caps caption, a big mono
-- numeral, and an optional muted sub-line. Background is the glass-module surface.

---@class StatCard: Frame
---@field caption     string  small uppercase label shown at the top
---@field amount      string  the headline value (mono numerals)
---@field amountColor number[]? color for the value (defaults to on-surface)
---@field sub         string? optional muted sub-line below the value
---@field subColor     number[]? color for the sub-line text (defaults to muted)
---@field subIcon      string? optional texture path drawn before the sub-line (e.g. a trend arrow)
---@field subIconColor number[]? tint for subIcon (defaults to muted)
---@field captionLabel Label
---@field amountLabel  Label
---@field subIconTex   Texture?
---@field subLabel     Label?
local StatCard = Class(Frame, function(self)
  local c, f = theme.colors, theme.fonts
  local pad = self.pad

  self.captionLabel = Label:new{
    parent = self,
    fontInfo = f.caps,
    color = c.muted,
    text = (self.caption or ""):upper(),
    position = { TopLeft = {pad, -pad} },
  }
  self.amountLabel = Label:new{
    parent = self,
    fontInfo = f.statBig,
    color = self.amountColor or c.text,
    text = self.amount or "",
    position = { TopLeft = {self.captionLabel, BottomLeft, 0, -5} },
  }
  self:Sub(self.sub, self.subIcon, self.subColor, self.subIconColor)
end, {
  background = theme.colors.module,
  pad = 10,
  amount = "",
})
---@class Warbandeer
---@field StatCard StatCard
ns.StatCard = StatCard

---@param text string?
---@param color number[]?
---@return string|StatCard
function StatCard:Amount(text, color)
  if text == nil then return self.amountLabel:Text() end
  self.amountLabel:Text(text)
  if color then self.amountLabel:Color(color) end
  return self
end

-- Set (or clear, with nil text) the muted sub-line and its optional leading glyph. The label and
-- glyph are created on first use and then reused, so a card can gain, change or lose its sub-line
-- as its data refreshes.
---@param text string?  sub-line text; nil hides the sub-line and its glyph
---@param icon string?  texture path drawn before the text (e.g. a trend arrow)
---@param color number[]?  text colour (defaults to muted)
---@param iconColor number[]?  glyph tint (defaults to `color`, then muted)
---@return StatCard
function StatCard:Sub(text, icon, color, iconColor)
  local c = theme.colors
  self.sub, self.subIcon, self.subColor, self.subIconColor = text, icon, color, iconColor
  if self.subIconTex then self.subIconTex:SetShown(text ~= nil and icon ~= nil) end
  if not text then
    if self.subLabel then self.subLabel:Hide() end
    return self
  end
  if icon then
    if not self.subIconTex then
      self.subIconTex = Texture:new{
        parent = self,
        layer = ui.layer.Artwork,
        position = { TopLeft = {self.amountLabel, BottomLeft, 0, -3}, Size = {11, 11} },
      }
    end
    self.subIconTex:Texture(icon)
    self.subIconTex:SetVertexColor(iconColor or color or c.muted)
  end
  if not self.subLabel then
    self.subLabel = Label:new{ parent = self, fontInfo = theme.fonts.subcaps }
  end
  self.subLabel:ClearAllPoints()
  if icon then
    self.subLabel:Left(self.subIconTex, Right, 3, 0)
  else
    self.subLabel:TopLeft(self.amountLabel, BottomLeft, 0, -4)
  end
  self.subLabel:Text(text):Color(color or c.muted)
  self.subLabel:Show()
  return self
end
