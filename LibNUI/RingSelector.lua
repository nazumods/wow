---@type LibNUI_AddOn
local ns = select(2, ...)
local ui = ns.ui
local Class, Frame, Texture, Label = ns.lua.Class, ui.Frame, ui.Texture, ui.Label

local GetCursorPosition = GetCursorPosition
local atan2, cos, sin, pi, abs, unpack =
  math.atan2, math.cos, math.sin, math.pi, math.abs, unpack

-- Smallest absolute angle between two headings (radians), in [0, pi].
local function angleDelta(a, b)
  local d = abs(a - b) % (2 * pi)
  return d > pi and (2 * pi - d) or d
end

-- Radial (OPie-style) selector: lays the given items out as glyphs evenly around a
-- center, clockwise from the top, and highlights the slice the cursor points
-- *toward* (you aim a direction, you don't have to hover the icon). Inside the
-- center dead-zone nothing is selected. Pure insecure UI — the caller drives the
-- lifecycle (show it, then `Commit()` on key-release to fire `onSelect`).

---@class RingItem
---@field name     string          identifier passed to onSelect
---@field path     string|number?  icon texture path / fileID
---@field atlas    string?         icon atlas (alternative to path)
---@field rotation number?         glyph rotation in radians
---@field title    string?         label shown in the center while this slice is aimed at

---@class RingSelector: Frame
---@field items     RingItem[]              slices, laid out clockwise from the top
---@field radius    number                  distance from center to each glyph
---@field iconSize  number                  glyph size
---@field deadZone  number                  center radius (px) that selects nothing
---@field restColor number[]                glyph tint at rest
---@field hiColor   number[]                glyph tint when the cursor aims at it
---@field onSelect  fun(name: string)?      fired by Commit() with the aimed slice
---@field titleLabel Label                  center label showing the aimed slice's title
---@field _slices   table[]                 { item, icon, angle } per slice
---@field _hovered  table?                  the slice the cursor currently aims at
local RingSelector = Class(Frame, function(self)
  local R, ICON = self.radius, self.iconSize
  self:Size(2 * R + ICON, 2 * R + ICON)

  -- center title, shown while a slice is aimed at
  self.titleLabel = Label:new{
    parent = self,
    justifyH = ui.justify.Center,
    color = self.hiColor,
    position = { Center = {} },
  }

  self._slices = {}
  local n = #self.items
  for i, item in ipairs(self.items) do
    -- first slice at the top (pi/2 in screen coords), going clockwise
    local angle = pi / 2 - (i - 1) * (2 * pi / n)
    local atlasSize
    if item.atlas then atlasSize = false end  -- so the explicit Size applies
    local icon = Texture:new{
      parent    = self,
      layer     = ui.layer.Artwork,
      path      = item.path,
      atlas     = item.atlas,
      atlasSize = atlasSize,
      rotation  = item.rotation,
      position  = { Center = {R * cos(angle), R * sin(angle)}, Size = {ICON, ICON} },
    }
    icon:SetVertexColor(unpack(self.restColor))
    self._slices[i] = { item = item, icon = icon, angle = angle }
  end

  -- track the cursor every frame and re-highlight the aimed slice
  self:SetScript("OnUpdate", function() self:_track() end)
  -- clicking the ring commits the aimed slice too — handy for the visual test; the
  -- keybind path instead calls Commit() directly on key release.
  self._widget:EnableMouse(true)
  self:SetScript("OnMouseUp", function() self:Commit() end)
end, {
  radius = 72,
  iconSize = 30,
  deadZone = 26,
  restColor = {0.62, 0.62, 0.66, 1},
  hiColor = {1, 0.82, 0, 1},
})
ui.RingSelector = RingSelector

-- Re-evaluate which slice the cursor aims at and update the highlight.
function RingSelector:_track()
  if #self._slices == 0 then return end
  local cx, cy = GetCursorPosition()
  local s = self._widget:GetEffectiveScale()
  cx, cy = cx / s, cy / s
  local fx, fy = self._widget:GetCenter()
  if not fx then return end
  local dx, dy = cx - fx, cy - fy
  local aimed
  if (dx * dx + dy * dy) >= self.deadZone * self.deadZone then
    local ang = atan2(dy, dx)
    local bestD
    for _, sl in ipairs(self._slices) do
      local d = angleDelta(ang, sl.angle)
      if not bestD or d < bestD then bestD, aimed = d, sl end
    end
  end
  self:_highlight(aimed)
end

-- Tint the aimed slice with hiColor (others restColor) and show its title; no-op
-- when the aimed slice hasn't changed since the last frame.
---@param slice table?
function RingSelector:_highlight(slice)
  if slice == self._hovered then return end
  self._hovered = slice
  for _, sl in ipairs(self._slices) do
    sl.icon:SetVertexColor(unpack(sl == slice and self.hiColor or self.restColor))
  end
  self.titleLabel:Text(slice and slice.item.title or "")
end

-- Anchor the ring's center to the current cursor position (so a "hold" pops the
-- ring up under the cursor). UIParent space, scale-corrected.
---@return RingSelector
function RingSelector:CenterOnCursor()
  local x, y = GetCursorPosition()
  local s = UIParent:GetEffectiveScale()
  self._widget:ClearAllPoints()
  self._widget:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
  return self
end

-- The name of the slice the cursor currently aims at, or nil in the dead zone.
---@return string?
function RingSelector:Selected()
  return self._hovered and self._hovered.item.name or nil
end

-- Fire onSelect for the aimed slice (if any) and return its name. Called on key
-- release by the keybind path, or on click in the standalone test.
---@return string?
function RingSelector:Commit()
  local name = self:Selected()
  if name and self.onSelect then self.onSelect(name) end
  return name
end
