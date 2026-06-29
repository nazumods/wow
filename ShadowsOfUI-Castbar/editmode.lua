---@type ShadowsOfUI_Castbar
local ns = select(2, ...)
local ui = ns.ui
local Texture = ui.Texture
local rgba = ns.Colors.rgba
local CastBar = ns.CastBar -- loaded before this file; we re-open it to add the selection box

-- Blizzard Edit Mode integration.
--
-- WoW's Edit Mode has no public registration API for third-party frames, so instead of
-- becoming a true Edit Mode "system" the bars piggy-back on it: while Edit Mode is open
-- each bar shows a static, labelled, draggable sample with a hand-rolled selection box;
-- closing Edit Mode returns them to their normal cast-driven behaviour. EnterEditMode/
-- ExitEditMode are hooked once at load. (The drag itself + the click-to-configure popup
-- live in CastBar.lua's `enableDrag` and config.lua.)

-- Edit Mode "selection box" border colours (cyan, like Blizzard's Edit Mode highlight):
-- dim while idle, bright on hover or while this bar owns the open config popup.
local SEL_DIM = rgba(120, 200, 255, 0.45)
local SEL_HOT = rgba(150, 220, 255, 0.95)

-- Build the selection box: four thin border strips framing the bar so it reads as a
-- movable/clickable handle (our stand-in for Blizzard's Selection frame, which has no
-- public API for third-party frames). Hidden until placement mode arms them. Called once
-- from the CastBar constructor.
function CastBar:_buildSelection()
  local O, T = 2, 2 -- outset from the bar, strip thickness
  local TL, TR, BL, BR = ui.edge.TopLeft, ui.edge.TopRight, ui.edge.BottomLeft, ui.edge.BottomRight
  local strips = {
    { TopLeft = {self, TL, -O, O},  TopRight = {self, TR, O, O},  Height = T },      -- top
    { BottomLeft = {self, BL, -O, -O}, BottomRight = {self, BR, O, -O}, Height = T }, -- bottom
    { TopLeft = {self, TL, -O, O},  BottomLeft = {self, BL, -O, -O}, Width = T },     -- left
    { TopRight = {self, TR, O, O},  BottomRight = {self, BR, O, -O}, Width = T },     -- right
  }
  self._sel = {}
  for _, pos in ipairs(strips) do
    local strip = Texture:new{ parent = self, layer = ui.layer.Overlay, color = SEL_DIM, position = pos }
    strip:Hide()
    self._sel[#self._sel + 1] = strip
  end
end

-- Tint the selection box (hot = hovered or selected).
---@param hot boolean?
function CastBar:_selectStyle(hot)
  local c = hot and SEL_HOT or SEL_DIM
  for _, strip in ipairs(self._sel) do strip:Color(c) end
end

-- Mark this bar as the one whose config popup is open (drawn highlighted).
---@param on boolean
function CastBar:SetSelected(on)
  self._selected = on
  self:_selectStyle(on)
end

-- Reset the bar back to a given TOPLEFT offset (config popup's "Reset position").
---@param x number
---@param y number
function CastBar:ResetPosition(x, y)
  self.pos.x, self.pos.y = x, y
  self:applyPosition()
end

-- Flip every bar into (or out of) placement mode.
---@param on boolean
function ns:SetConfigMode(on)
  if not self.bars then return end
  for _, bar in pairs(self.bars) do bar:SetConfig(on) end
  if not on then self:CloseConfig() end -- leaving Edit Mode dismisses the config popup
end

-- Hook Edit Mode's enter/exit. Guarded so a client without EditModeManagerFrame (or a
-- renamed mixin) just leaves the bars in live mode rather than erroring.
function ns:WireEditMode()
  if not (EditModeManagerFrame and EditModeManagerFrame.EnterEditMode) then return end
  hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() ns:SetConfigMode(true) end)
  hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() ns:SetConfigMode(false) end)
  -- Sync if the addon somehow loaded while Edit Mode was already open.
  if EditModeManagerFrame.editModeActive then ns:SetConfigMode(true) end
end
