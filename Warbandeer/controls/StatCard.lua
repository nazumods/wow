local _, ns = ...
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
  if self.sub then
    -- optional leading trend glyph (e.g. an up/down arrow for weekly change)
    if self.subIcon then
      self.subIconTex = Texture:new{
        parent = self,
        layer = ui.layer.Artwork,
        path = self.subIcon,
        position = { TopLeft = {self.amountLabel, BottomLeft, 0, -3}, Size = {11, 11} },
      }
      self.subIconTex:SetVertexColor(self.subIconColor or c.muted)
    end
    self.subLabel = Label:new{
      parent = self,
      fontInfo = f.subcaps,
      color = self.subColor or c.muted,
      text = self.sub,
      position = self.subIcon
        and { Left = {self.subIconTex, Right, 3, 0} }
        or  { TopLeft = {self.amountLabel, BottomLeft, 0, -4} },
    }
  end
end, {
  background = theme.colors.module,
  pad = 10,
  amount = "",
})
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
