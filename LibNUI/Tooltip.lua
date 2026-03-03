local _, ns = ...
local max = math.max
local ui = ns.ui

local insert = table.insert
local Class, CleanFrame, Frame, Label = ns.lua.Class, ui.CleanFrame, ui.Frame, ui.Label

---@class Tooltip: CleanFrame
local Tooltip = Class(CleanFrame, function(self)
  self:Hide()
  self._lineCount = 0
  self._w = 0
  self._h = 0

  local lines = self.lines
  self.lines = {}
  for i, line in ipairs(lines) do
    local l = Frame:new{
      parent = self,
      position = {
        TopLeft = i == 1 and {self.inset, -self.inset} or {self.lines[i-1], ui.edge.BottomLeft},
        Right = {},
        Height = 20,
      },
      background = line.background,
    }
    l.label = Label:new{
      parent = l,
      text = line.text,
      position = { All = true },
      justifyH = ui.edge.Left,
    }
    if line.color then l.label:Color(line.color) end
    if line.onClick then l:SetScript("OnMouseUp", function() line.onClick(l) end) end
    if line.onEnter then l:SetScript("OnEnter", function() line.onEnter(l) end) end
    if line.onLeave then l:SetScript("OnLeave", function() line.onLeave(l) end) end
    insert(self.lines, l)
    self._lineCount = i
    self._w = max(self._w, l.label._widget:GetUnboundedStringWidth())
    self._h = self._h + l:Height()
  end
  self:Height(self._h + 2 * self.inset)
  self:Width(self._w + 2 * self.inset)
end, {
  strata = "DIALOG",
  background = {0, 0, 0, 0.7},
  inset = 3,
  lines = {},
})
ui.Tooltip = Tooltip

-- Grabs the next line frame from the pool, creating one if the pool is exhausted.
-- Repositions pooled frames to maintain correct stacking order after ClearLines().
---@return Frame
function Tooltip:_acquireLine()
  self._lineCount = self._lineCount + 1
  local i = self._lineCount
  local prev = self.lines[i - 1]
  local l = self.lines[i]
  if not l then
    l = Frame:new{
      parent = self,
      position = {
        TopLeft = prev and {prev, ui.edge.BottomLeft} or {self.inset, -self.inset},
        Right = {},
        Height = 20,
      },
    }
    l.label = Label:new{
      parent = l,
      position = { All = true },
      justifyH = ui.edge.Left,
    }
    insert(self.lines, l)
  else
    -- Reanchor the pooled frame; its anchors were cleared by ClearLines() implicitly
    -- via hide, so we must re-establish them before use.
    l._widget:ClearAllPoints()
    if prev then
      l._widget:SetPoint("TOPLEFT", prev._widget, "BOTTOMLEFT")
    else
      l._widget:SetPoint("TOPLEFT", self._widget, "TOPLEFT", self.inset, -self.inset)
    end
    l._widget:SetPoint("RIGHT", self._widget, "RIGHT")
    l._widget:Show()
  end
  return l
end

-- Remove all lines and collapse the tooltip to its minimum size.
-- The underlying frames are pooled and reused by the next AddLine() sequence.
function Tooltip:ClearLines()
  for i = 1, self._lineCount do
    self.lines[i]._widget:Hide()
  end
  self._lineCount = 0
  self._w = 0
  self._h = 0
  self:Height(2 * self.inset)
  self:Width(2 * self.inset)
end

-- Append a text line. Resets the label color to white when no color is supplied,
-- which matters on pool reuse where a previous color may linger.
---@param text string
---@param r number|table|nil red channel (0–1), a color table, or a WoW ColorMixin
---@param g number? green channel (0–1)
---@param b number? blue channel (0–1)
---@param a number? alpha channel (0–1, default 1)
function Tooltip:AddLine(text, r, g, b, a)
  if not text then return end
  local l = self:_acquireLine()
  l.label:Text(text)
  if r then
    l.label:Color(r, g, b, a)
  else
    l.label:Color(1, 1, 1, 1)
  end
  local lineW = l.label._widget:GetUnboundedStringWidth()
  if lineW > self._w then
    self._w = lineW
    self:Width(self._w + 2 * self.inset)
  end
  self._h = self._h + l:Height()
  self:Height(self._h + 2 * self.inset)
end

-- Position the tooltip relative to a frame using GameTooltip-style anchor constants.
-- Must be called before Show(). Clears any previous anchor.
---@param frame table|Frame the frame to anchor against
---@param anchor string "ANCHOR_BOTTOMRIGHT"|"ANCHOR_BOTTOMLEFT"|"ANCHOR_TOPRIGHT"|"ANCHOR_TOPLEFT"|"ANCHOR_RIGHT"|"ANCHOR_LEFT"
---@param dx number? x offset in pixels (default 0)
---@param dy number? y offset in pixels (default 0)
function Tooltip:AnchorTo(frame, anchor, dx, dy)
  self._widget:ClearAllPoints()
  local f = (type(frame) == "table" and frame._widget) or frame
  dx, dy = dx or 0, dy or 0
  if anchor == "ANCHOR_BOTTOMRIGHT" then
    self._widget:SetPoint("TOPLEFT", f, "BOTTOMRIGHT", dx, dy)
  elseif anchor == "ANCHOR_BOTTOMLEFT" then
    self._widget:SetPoint("TOPRIGHT", f, "BOTTOMLEFT", dx, dy)
  elseif anchor == "ANCHOR_TOPRIGHT" then
    self._widget:SetPoint("BOTTOMLEFT", f, "TOPRIGHT", dx, dy)
  elseif anchor == "ANCHOR_TOPLEFT" then
    self._widget:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", dx, dy)
  elseif anchor == "ANCHOR_RIGHT" then
    self._widget:SetPoint("LEFT", f, "RIGHT", dx, dy)
  elseif anchor == "ANCHOR_LEFT" then
    self._widget:SetPoint("RIGHT", f, "LEFT", dx, dy)
  else
    self._widget:SetPoint("TOPLEFT", f, "BOTTOMRIGHT", dx, dy)
  end
end

-- Show realm and active specialization for a character, positioned via a LibNUI
-- position table so callers can use any anchor layout they need.
---@param toon table WarbandeerApi character object
---@param position table LibNUI position table (e.g. { TopLeft = {frame, "BOTTOM", 20, -10} })
function Tooltip:ShowForCharacter(toon, position)
  self:ClearLines()
  if toon.realm then self:AddLine(toon.realm) end
  if toon.specializationActive then self:AddLine(toon.specializationActive) end
  self._widget:ClearAllPoints()
  self:Position(position)
  self:Show()
end

-- Shared singleton tooltip. Replace bare GameTooltip usage in addon views with ui.tip:
--   ui.tip:AnchorTo(frame, "ANCHOR_BOTTOMRIGHT", -10, 10)
--   ui.tip:ClearLines()
--   ui.tip:AddLine(text)
--   ui.tip:Show()  /  ui.tip:Hide()
ui.tip = Tooltip:new{}

-- Convenience wrappers for name-cell hover in table views. The position table is a
-- standard LibNUI position table so each view can choose its own anchor layout.
---@param toon table WarbandeerApi character object
---@param frame table LibNUI frame the tooltip should anchor near (captured in position)
---@param position table LibNUI position table
function ui.ShowCharacterTooltip(toon, frame, position) -- luacheck: ignore frame
  ui.tip:ShowForCharacter(toon, position)
end

function ui.HideCharacterTooltip()
  ui.tip:Hide()
end
