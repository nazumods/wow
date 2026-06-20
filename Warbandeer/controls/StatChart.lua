---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Class, Frame, Texture = ns.lua.Class, ui.Frame, ui.Texture
local theme = ns.theme
local max, min = math.max, math.min

-- A compact secondary-stat radar: four vertices — Crit (top-left), Haste
-- (bottom-left), Versatility (bottom-right), Mastery (top-right) — placed along the
-- diagonals at a distance proportional to each rating relative to the largest of the
-- four, joined into a quadrilateral. The shape leans toward whichever stats dominate;
-- a balanced build reads as a small centred diamond. Outline only (no fill) over a
-- faint square guide marking the max extent.
--
-- Re-derived from the *idea* behind Narcissus's radar chart, not its mask-texture
-- implementation: WoW's native frame lines draw the edges directly, so there are no
-- bundled mask/vertex art assets and no rotation maths.

local DOT = "Interface\\AddOns\\Warbandeer\\media\\bar-rounded"

-- vertex order around the perimeter: Crit → Haste → Versatility → Mastery → (Crit)
local KEYS = { "crit", "haste", "versatility", "mastery" }
-- unit direction of each stat's axis (x right, y up)
local DIR = {
  crit        = { -1,  1 },
  haste       = { -1, -1 },
  versatility = {  1, -1 },
  mastery     = {  1,  1 },
}

---@class StatChart: Frame
---@field radius    number  half-extent (px) a fully-overshot vertex reaches from centre (the frame corner)
---@field overshoot number  max fulfilment a vertex plots (1 = on the guide square; reaches `radius` at this value)
---@field thickness number  polygon line thickness
---@field dotSize   number  vertex marker edge
local StatChart = Class(Frame, function(self)
  local c = theme.colors
  local w = self._widget
  -- The guide square marks "target met"; vertices may overshoot it up to `overshoot`×
  -- (which reaches the frame corner `radius`), so the guide sits inset from the edge.
  local gR = self.radius / self.overshoot

  -- faint square guide at the target line (the four diagonal corners)
  local g = c.divider
  local gc = { {-gR, gR}, {-gR, -gR}, {gR, -gR}, {gR, gR} } -- TL, BL, BR, TR
  for i = 1, 4 do
    local line = w:CreateLine()
    line:SetThickness(1)
    line:SetColorTexture(g[1], g[2], g[3], (g[4] or 1) * 0.6)
    local a, b = gc[i], gc[i % 4 + 1]
    line:SetStartPoint("CENTER", w, a[1], a[2])
    line:SetEndPoint("CENTER", w, b[1], b[2])
  end

  -- the four polygon edges + four vertex dots, positioned by :Set
  self._edges, self._dots = {}, {}
  for i = 1, 4 do
    self._edges[i] = w:CreateLine()
    self._edges[i]:SetThickness(self.thickness)
    local dot = Texture:new{
      parent = self, layer = ui.layer.Overlay,
      position = { Size = {self.dotSize, self.dotSize} },
    }
    dot:Texture(DOT)
    dot:SliceMargins(6, 6, 6, 6)
    dot:SliceMode(0)
    self._dots[i] = dot
  end
end, {
  radius = 26,
  overshoot = 1.2,
  thickness = 1.5,
  dotSize = 7,
})
---@class Warbandeer
---@field StatChart StatChart
ns.StatChart = StatChart

-- Plot the four ratings and tint the dots of any stats in `hot` (tier-1 priority)
-- gold. Each vertex's distance is the stat's **fulfilment vs its target** (the guide
-- square = on/over target), so an under-target stat pulls toward the centre and a
-- met/over one reaches the edge — matching the red/blue target cells beside it. When
-- a stat has no target the chart falls back to its rating relative to the largest of
-- the four, so a target-less spec still reads as a balance plot. Zero/absent ratings
-- collapse to the centre; an all-zero set hides the polygon (no scanned stats yet).
---@param crit number?
---@param haste number?
---@param mastery number?
---@param vers number?
---@param hot table<string, boolean>?  stats to highlight gold
---@param targets table<string, number>?  per-stat goal ratings (guide edge = target met); absent → balance vs the largest rating
---@return StatChart
function StatChart:Set(crit, haste, mastery, vers, hot, targets)
  local c = theme.colors
  local w = self._widget
  local R = self.radius
  hot = hot or {}
  local val = { crit = crit or 0, haste = haste or 0, mastery = mastery or 0, versatility = vers or 0 }
  local peak = max(val.crit, val.haste, val.mastery, val.versatility, 1)

  local over = self.overshoot
  local pt = {}
  for _, key in ipairs(KEYS) do
    -- fulfilment vs target — 1.0 lands on the guide square, capped at `overshoot`×
    -- (which reaches the corner) so an over-target stat pokes a little past the guide.
    -- Fall back to the largest rating when this stat has no target.
    local t = targets and targets[key]
    local denom = (t and t > 0) and t or peak
    local r = min(val[key] / denom, over) / over * R
    local d = DIR[key]
    pt[key] = { d[1] * r, d[2] * r }
  end

  for i, key in ipairs(KEYS) do
    local p = pt[key]
    local dot = self._dots[i]
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", self, "CENTER", p[1], p[2])
    local col = hot[key] and c.gold or c.muted
    dot:SetVertexColor(col[1], col[2], col[3], 1)
  end

  local line = c.text
  local any = val.crit + val.haste + val.mastery + val.versatility > 0
  for i = 1, 4 do
    local a, b = pt[KEYS[i]], pt[KEYS[i % 4 + 1]]
    local e = self._edges[i]
    e:SetColorTexture(line[1], line[2], line[3], 0.9)
    e:SetStartPoint("CENTER", w, a[1], a[2])
    e:SetEndPoint("CENTER", w, b[1], b[2])
    e:SetShown(any)
  end
  return self
end
