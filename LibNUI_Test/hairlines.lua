local ui       = LibNUI
local Frame    = LibNUI.Frame
local Label    = LibNUI.Label
local Texture  = LibNUI.Texture
local window   = LibNUITest.window
local toggling = LibNUITest.toggling

-- Hairline pixel snapping (#782). A 1-unit line is a whole physical pixel at exactly one
-- uiScale and a fraction of one everywhere else, and the renderer drops it wherever that
-- fraction fails to cover a pixel. The fraction sits close enough to 1 that the misses are
-- not scattered — they land on a fixed stripe every ~34 units across the screen — which is
-- what makes a dropped border edge look like a broken widget rather than like rounding.
--
-- So: two combs of 140 lines at 1-unit pitch, identical but for Width vs PixelWidth. The
-- raw comb shows dark seams where the stripe falls; the snapped comb is solid. The row of
-- BorderBoxes underneath samples six different phases with the real widget.
--
-- Scale-dependent, so a clean pass at one setting proves nothing: check it at a
-- deliberately awkward uiScale as well as the default. The readout at the top prints the
-- numbers the outcome follows from.

local N, PITCH, STRIP_H = 140, 1, 20
local PAD, GAP = 12, 8
local GOLD = {1, 0.82, 0, 1}

-- One comb of N vertical lines. `snap` picks the only thing that differs between the two.
---@param host table
---@param y number
---@param snap boolean
local function comb(host, y, snap)
  local strip = Frame:new{ parent = host,
    position = { TopLeft = {PAD, y}, Width = N * PITCH, Height = STRIP_H } }
  for i = 0, N - 1 do
    local line = Texture:new{ parent = strip, layer = ui.layer.Overlay, color = GOLD,
      position = { TopLeft = {i * PITCH, 0}, Height = STRIP_H } }
    if snap then line:PixelWidth(1) else line:Width(1) end
  end
end

---@return TitleFrame
local function makeHairlines()
  local f = window("Hairlines", N + PAD * 2, 190)

  local scale = UIParent:GetEffectiveScale()
  local w, h = GetPhysicalScreenSize()
  local perUnit = scale / (768 / h)
  local y = -44

  Label:new{ parent = f, color = "muted",
    position = { TopLeft = {PAD, y}, Right = {-PAD, 0} },
    text = format("%dx%d @ %.4f - 1 unit = %.3f px", w, h, scale, perUnit) }
  y = y - 18

  Label:new{ parent = f, position = { TopLeft = {PAD, y} }, text = "Width(1) - raw UI units" }
  y = y - 16
  comb(f, y, false)
  y = y - STRIP_H - GAP

  Label:new{ parent = f, position = { TopLeft = {PAD, y} }, text = "PixelWidth(1) - snapped" }
  y = y - 16
  comb(f, y, true)
  y = y - STRIP_H - GAP

  Label:new{ parent = f, position = { TopLeft = {PAD, y} }, text = "BorderBox thickness 1" }
  y = y - 18
  -- 23 units apart, so the six boxes sit at six different points in the stripe's period.
  for i = 0, 5 do
    ui.BorderBox:new{ parent = f, color = GOLD,
      position = { TopLeft = {PAD + i * 23, y}, Size = {20, 20} } }
  end

  return f
end

table.insert(LibNUITest.tests, {
  key  = "hairlines",
  name = "Hairlines: pixel snapping",
  desc = "Raw vs snapped 1px lines; the raw comb seams where the sub-pixel stripe falls (#782)",
  run  = toggling(makeHairlines),
})
