local ui       = LibNUI
local Frame    = LibNUI.Frame
local Label    = LibNUI.Label
local Texture  = LibNUI.Texture
local e        = LibNUI.edge
local window   = LibNUITest.window
local toggling = LibNUITest.toggling

-- Hairline pixel snapping (#782). A UI unit is not a pixel:
--
--   physicalPixelsPerUnit = effectiveScale / (768 / physicalScreenHeight)
--
-- which is 1 at exactly one uiScale per resolution (768/height) and a fraction either side.
-- Below 1, a Width(1) edge does not cover a whole pixel and the renderer resolves it to a
-- pixel or to nothing depending where it falls — so an edge drawn in UI units is a coin
-- toss on hardware we don't control.
--
-- Two rows of small boxes, same geometry, drawn two ways: the top row hand-rolls four
-- 1-unit edge textures the way the suite used to, the bottom row is `ui.BorderBox` at
-- thickness 1. On the red backing a dropped edge reads as an open ⊐ — which is the whole
-- reason this is the shape being drawn.
--
-- **It deliberately is NOT a comb of adjacent 1-unit lines.** That was the first cut and it
-- proved nothing: at 1-unit pitch a line spans [i, i+1] and the next spans [i+1, i+2], so
-- the rendered spans are exactly contiguous and the union is solid at any scale. Lines were
-- collapsing to zero width and being absorbed by their neighbours with no gap left behind.
-- A shape with corners has no neighbour to hide the loss.
--
-- The readout tracks UI_SCALE_CHANGED/DISPLAY_SIZE_CHANGED rather than being sampled once,
-- because both move the conversion and a windowed client moves the second one constantly.
-- That doubles as the test for the re-snap: change scale with this open and the bottom row
-- must stay intact while the top row takes on a new pattern of broken boxes.
--
-- At the pixel-perfect uiScale for a display the readout reads 1.0000 and NEITHER row can
-- break — unsnapped code looks perfect there too, so that reading proves nothing. The lower
-- the figure, the more of the top row breaks: shrinking the client window drives it down.

local BOX, PITCH, COUNT = 12, 14, 10
local PAD, LINE, GAP = 14, 20, 14
local TITLE_H, ROW_W = 40, 140
local GOLD = {1, 0.82, 0, 1}
local BACKING = {0.85, 0.10, 0.10, 1}

-- A row of `COUNT` boxes on a red backing. `snap` picks the only thing that differs: four
-- hand-rolled 1-unit edges, or the same four edges through BorderBox's snapped setters.
---@param host table
---@param y number
---@param snap boolean
local function boxRow(host, y, snap)
  local strip = Frame:new{ parent = host,
    position = { TopLeft = {PAD, y}, Width = ROW_W, Height = BOX } }
  Texture:new{ parent = strip, layer = ui.layer.Background, color = BACKING,
    position = { All = true } }
  for i = 0, COUNT - 1 do
    local x = i * PITCH
    if snap then
      ui.BorderBox:new{ parent = strip, color = GOLD, thickness = 1,
        position = { TopLeft = {x, 0}, Size = {BOX, BOX} } }
    else
      local b = Frame:new{ parent = strip, position = { TopLeft = {x, 0}, Size = {BOX, BOX} } }
      local function edge()
        return Texture:new{ parent = b, color = GOLD, layer = ui.layer.Overlay, position = {} }
      end
      local top, bottom, left, right = edge(), edge(), edge(), edge()
      top:SetPoint(e.TopLeft, b, e.TopLeft);           top:SetPoint(e.TopRight, b, e.TopRight);           top:Height(1)
      bottom:SetPoint(e.BottomLeft, b, e.BottomLeft);  bottom:SetPoint(e.BottomRight, b, e.BottomRight);  bottom:Height(1)
      left:SetPoint(e.TopLeft, b, e.TopLeft);          left:SetPoint(e.BottomLeft, b, e.BottomLeft);      left:Width(1)
      right:SetPoint(e.TopRight, b, e.TopRight);       right:SetPoint(e.BottomRight, b, e.BottomRight);   right:Width(1)
    end
  end
end

---@return TitleFrame
local function makeHairlines()
  -- Laid out down a cursor rather than against fixed offsets, and every caption is width-
  -- bounded: an unbounded `wordWrap = false` Label anchored only at TopLeft runs straight
  -- out through the side of the window, which is how the first cut escaped its frame.
  local width = ROW_W + PAD * 2 + 40
  local f = window("Hairlines", width, TITLE_H + LINE * 5 + BOX * 2 + GAP * 3 + PAD)
  local y = -TITLE_H

  ---@param text string
  ---@return Label
  local function caption(text)
    local l = Label:new{ parent = f, text = text, wordWrap = false,
      position = { TopLeft = {PAD, y}, Width = width - PAD * 2 } }
    y = y - LINE
    return l
  end

  local screen, perUnitLabel, edgeLabel = caption(""), caption(""), caption("")
  y = y - GAP
  local rawLabel = caption("")
  boxRow(f, y, false)
  y = y - BOX - GAP
  caption("BorderBox t=1")
  boxRow(f, y, true)

  -- A snapped edge kept purely to read its width back. What the library BELIEVES a 1px
  -- hairline is, live, in the same units the renderer will use — the one number that
  -- distinguishes "the maths is wrong" from "the re-snap left a stale value behind".
  local probe = Texture:new{ parent = f, layer = ui.layer.Overlay, color = GOLD,
    position = { TopLeft = {0, 0}, Height = 1, Hide = true } }
  probe:PixelWidth(1)

  -- Live, not sampled once. A fraction p of a pixel per unit loses (1 - p) of all positions,
  -- and each box puts two vertical and two horizontal edges on the board.
  local function refresh()
    local scale = UIParent:GetEffectiveScale()
    local w, h = GetPhysicalScreenSize()
    local perUnit = scale / (768 / h)
    local edges = COUNT * 4
    screen:Text(format("%dx%d @ %.5f", w, h, scale))
    perUnitLabel:Text(format("1 unit = %.4f px", perUnit))
    -- Must read 1.000px (or a whole number). Anything fractional here means a snapped
    -- length went stale, not that the conversion is wrong.
    edgeLabel:Text(format("edge %.4fu = %.3fpx", probe:Width(), probe:Width() * perUnit))
    rawLabel:Text(format("raw: ~%d of %d at risk",
      math.max(0, floor(edges * (1 - perUnit) + 0.5)), edges))
  end
  refresh()

  -- Polled, NOT driven off UI_SCALE_CHANGED. The library's own re-snap defers a frame off
  -- that event (the scale is not settled when it fires), so a readout on the same event
  -- races it and reports the pre-re-snap value whether or not the re-snap then works —
  -- which is exactly the false negative this line is here to avoid.
  local since = 0
  local ticker = Frame:new{ parent = f, onUpdate = function(_, elapsed)
    since = since + elapsed
    if since < 200 then return end
    since = 0
    refresh()
  end }
  ticker:startUpdates()

  return f
end

table.insert(LibNUITest.tests, {
  key  = "hairlines",
  name = "Hairlines: pixel snapping",
  desc = "Hand-rolled 1px boxes over BorderBox ones on red; the top row breaks, the bottom holds (#782)",
  run  = toggling(makeHairlines),
})
