local _, ns = ...
local ui = ns.ui
local Class, Frame, Label = ns.lua.Class, ui.Frame, ui.Label
local theme = ns.theme
local BottomLeft = ui.edge.BottomLeft

-- A single "stat" tile for the summary strip: a small caps caption, a big mono
-- numeral, and an optional muted sub-line. Background is the glass-module surface.

---@class StatCard: Frame
---@field caption     string  small uppercase label shown at the top
---@field amount      string  the headline value (mono numerals)
---@field amountColor number[]? color for the value (defaults to on-surface)
---@field sub         string? optional muted sub-line below the value
---@field captionLabel Label
---@field amountLabel  Label
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
    self.subLabel = Label:new{
      parent = self,
      fontInfo = f.subcaps,
      color = c.muted,
      text = self.sub,
      position = { TopLeft = {self.amountLabel, BottomLeft, 0, -4} },
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
