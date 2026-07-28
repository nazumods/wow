---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui

local Class, unpack = ns.lua.Class, unpack

---@class WoWRegion: table

---@class Region: Class
---@field _widget table backing WoW UI widget
---@field theme Theme? active theme; inherited from the parent widget when not given
---@field OnBeforeShow function
local Region = Class(nil, function(self)
  -- inherit the theme down the widget tree: passing `theme` once on a top-level
  -- window styles every child widget created with `parent = <that widget>`
  if not self.theme and type(self.parent) == "table" then
    self.theme = self.parent.theme
  end
  self._widget = self:CreateWidget()
  if self.position then self:Position(self.position) end
  if self.alpha then self:Alpha(self.alpha) end
end)
ui.Region = Region

-- The active theme (own, inherited, or the default dark theme).
---@return Theme
function Region:Theme()
  return self.theme or ui.themes.dark
end

-- Resolve a color option: a token name string looks up the active theme's
-- colors; anything else (rgba table, ColorMixin, nil) passes through.
---@param c string|table|nil
---@return table|nil
function Region:ThemeColor(c)
  if type(c) == "string" then return self:Theme().colors[c] end
  return c
end

-- Register a repaint against this widget's active theme: `fn(self, theme)` runs now and
-- again after every `theme:Apply(overrides)`, so token-derived styling follows runtime
-- theme swaps. Registration is permanent — call once at construction (a pooled/reused
-- widget registers when built, not per refresh), or entries pile up. Widgets without a
-- custom theme register on the shared dark theme: a `ui.themes.dark:Apply` repaints them
-- across every LibNUI-based addon.
---@param fn fun(self: Region, theme: Theme)
---@return Region
function Region:Themed(fn)
  local theme = self:Theme()
  local themed = theme._themed
  themed[#themed + 1] = function() fn(self, theme) end
  fn(self, theme)
  return self
end

---@param parent Region|table  new parent (LibNUI widget or raw WoW frame)
function Region:Parent(parent)
  self._widget:SetParent(parent._widget or parent)
end

-- Apply a position table: each key names a method on self, each value its args
-- (unpacked if a table, passed directly if scalar, skipped if false).
---@param position table
function Region:Position(position)
  for k,v in pairs(position) do
    if self[k] then
      if type(v) == "table" then
        self[k](self, unpack(v))
      elseif v ~= false then
        self[k](self, v)
      end
    end
  end
end

---@return string?
function Region:GetName() return self._widget:GetName() end

---@param point string  anchor point on this region (ui.edge constant)
---@param target Region|table|number?  anchor target (defaults to the parent); may be the x offset in the 3-arg form
---@param edge string|number?  anchor point on the target; may be the y offset in the 3-arg form
---@param x number?  x offset in pixels
---@param y number?  y offset in pixels
function Region:SetPoint(point, target, edge, x, y)
  if type(target) == "table" and target._widget then target = target._widget end
  -- must be called with explicit arguments, passing nil confuses it
  if x == nil and y == nil then
    if target == nil and edge == nil then
      self._widget:SetPoint(point)
    else
      self._widget:SetPoint(point, target, edge)
    end
  else
    self._widget:SetPoint(point, target, edge, x, y)
  end
end

-- Anchor to the parent's four corners. The target is passed EXPLICITLY rather than relying on
-- `SetAllPoints()`'s implicit-parent form: regions anchored this way — and only those — have been
-- seen to draw nothing at first paint after a login, across both Textures and FontStrings, while
-- siblings carrying an explicit `Size` or a single-corner anchor render fine (nazumods/wow#718).
-- Read from the widget, not `self.parent`, which `Region:Parent` doesn't keep in sync when a widget
-- is re-parented (e.g. `ScrollFrame:Child`) — `GetParent()` is the same target the no-arg form
-- documents itself as using, so this is the identical anchor, just stated outright.
function Region:All() self._widget:SetAllPoints(self._widget:GetParent()) end
function Region:ClearAllPoints() self._widget:ClearAllPoints() end
-- Edge anchor shorthands: forward to SetPoint with the matching ui.edge point.
---@param ... any  SetPoint args after the point: target?, edge?, x?, y?
function Region:Center(...) self:SetPoint(ui.edge.Center, ...) end
---@param ... any  SetPoint args after the point: target?, edge?, x?, y?
function Region:Top(...) self:SetPoint(ui.edge.Top, ...) end
---@param ... any  SetPoint args after the point: target?, edge?, x?, y?
function Region:TopLeft(...) self:SetPoint(ui.edge.TopLeft, ...) end
---@param ... any  SetPoint args after the point: target?, edge?, x?, y?
function Region:TopRight(...) self:SetPoint(ui.edge.TopRight, ...) end
---@param ... any  SetPoint args after the point: target?, edge?, x?, y?
function Region:Bottom(...) self:SetPoint(ui.edge.Bottom, ...) end
---@param ... any  SetPoint args after the point: target?, edge?, x?, y?
function Region:BottomLeft(...) self:SetPoint(ui.edge.BottomLeft, ...) end
---@param ... any  SetPoint args after the point: target?, edge?, x?, y?
function Region:BottomRight(...) self:SetPoint(ui.edge.BottomRight, ...) end
---@param ... any  SetPoint args after the point: target?, edge?, x?, y?
function Region:Left(...) self:SetPoint(ui.edge.Left, ...) end
---@param ... any  SetPoint args after the point: target?, edge?, x?, y?
function Region:Right(...) self:SetPoint(ui.edge.Right, ...) end

---@param x number?  width; omit both args to get
---@param y number?  height
---@return number? width  when getting
---@return number? height  when getting
function Region:Size(x, y) return x == nil and self._widget:GetSize() or self._widget:SetSize(x, y) end

---@param w number?
---@return number?  the width when getting
function Region:Width(w) return w == nil and self._widget:GetWidth() or self._widget:SetWidth(w) end
---@param h number?
---@return number?  the height when getting
function Region:Height(h) return h == nil and self._widget:GetHeight() or self._widget:SetHeight(h) end

-- Layout is in UI units, which equal physical pixels at exactly one `uiScale` and are a
-- fraction of one everywhere else. A 1-unit hairline is then a fraction of a pixel — 0.97
-- of one at the scale nazumods/wow#782 was reported at — and the renderer resolves that to
-- either a whole pixel or nothing at all, depending on where the line happens to land.
--
-- Because the fraction is so close to 1, the sub-pixel phase drifts only ~0.03px per unit
-- of travel, so the misses are not scattered: they fall on a fixed stripe every ~34 units
-- across the screen. Every widget sitting on one loses the same edge, every time, which is
-- why this reads as "that widget's left edge never draws" rather than as rounding noise.
--
-- Rounding a length out to whole pixels removes the fraction and with it the stripe. Sizes
-- are enough — a run of exactly N whole pixels covers N pixels wherever it starts — so the
-- anchor offsets need no snapping of their own.

-- Regions carrying a snapped length, keyed to the length they asked for so it can be
-- recomputed when the conversion changes under them.
--
-- **Deliberately NOT weak-keyed.** A WoW widget is never destroyed, so a region's backing
-- widget goes on rendering whether or not anything still references the Lua wrapper — and
-- plenty of widgets are built and never stored (`ui.BorderBox:new{...}` as a statement is
-- the common shape). Under weak keys the collector quietly evicts exactly those, so they
-- stop being re-snapped while still on screen, and a scale change leaves a scattered mix of
-- correct and stale edges that moves around with GC timing rather than with geometry.
local snapped = {}

---@param self Region
---@param key string  "w" | "h" | "inset"
---@param units number
local function Remember(self, key, units)
  local rec = snapped[self]
  if not rec then rec = {}; snapped[self] = rec end
  rec[key] = units
end

-- Convert a length in UI units to the nearest whole number of physical pixels — never
-- fewer than one — and return it in UI units again. Pass the same number you would pass to
-- `Width`/`Height`: the result is that length rounded to the nearest whole pixel, not a
-- pixel count, so a border keeps its apparent weight at every resolution instead of
-- thinning to a hair on a high-DPI display. Only the floor rounds *out*, and only ever to
-- one — which is the guarantee a hairline needs and the one it never had.
---@param units number  length in UI units
---@return number  the same length, at the nearest whole number of physical pixels
function Region:Pixels(units)
  return PixelUtil.GetNearestPixelSize(units, self._widget:GetEffectiveScale(), 1)
end

-- `Width`/`Height` snapped to whole physical pixels. Use these for anything thin
-- enough to vanish — border edges, dividers, rules — and plain `Width`/`Height` for
-- everything else, which is far too large for the rounding to reach.
---@param units number
function Region:PixelWidth(units) Remember(self, "w", units); self._widget:SetWidth(self:Pixels(units)) end
---@param units number
function Region:PixelHeight(units) Remember(self, "h", units); self._widget:SetHeight(self:Pixels(units)) end

---@param self Region
---@param units number
local function ApplyInset(self, units)
  local u = self:Pixels(units)
  self:SetPoint(ui.edge.TopLeft, u, -u)
  self:SetPoint(ui.edge.BottomRight, -u, u)
end

-- Anchor to the parent's rect, inset on all four sides by a snapped length. This is the
-- framed-box idiom — a filled region over a slightly larger one, the difference showing as
-- a rim — whose rim is exposed to exactly the same rounding as a hairline texture, with
-- the inset offset standing in for the width.
---@param units number  inset in UI units
function Region:Inset(units)
  Remember(self, "inset", units)
  ApplyInset(self, units)
end

-- Both events move the UI-unit-to-pixel conversion, so every snapped length has to be
-- recomputed against the new one — a size snapped at the old scale is back to being a
-- fraction of a pixel at the new one. Re-applied through the raw setters rather than the
-- Pixel* methods, so nothing writes to `snapped` while this is walking it.
local function ReSnap()
  for region, rec in pairs(snapped) do
    if rec.w then region._widget:SetWidth(region:Pixels(rec.w)) end
    if rec.h then region._widget:SetHeight(region:Pixels(rec.h)) end
    if rec.inset then ApplyInset(region, rec.inset) end
  end
end

-- Deferred a frame, NOT run inline. Both events announce a change rather than follow it:
-- `GetEffectiveScale()` and `GetPhysicalScreenSize()` are not guaranteed to be reporting the
-- new values by the time the handler runs, and re-deriving against the old ones is worse
-- than not re-deriving at all — it converts correctly snapped lengths into fractional ones.
-- A frame later both are settled.
local function ReSnapSoon() RunNextFrame(ReSnap) end
ns:registerEvent("UI_SCALE_CHANGED", ReSnapSoon)
ns:registerEvent("DISPLAY_SIZE_CHANGED", ReSnapSoon)

function Region:Show()
  if self.OnBeforeShow then self:OnBeforeShow() end
  self._widget:Show()
end
function Region:Hide() self._widget:Hide() end
---@param b boolean
function Region:SetShown(b) if b then self:Show() else self:Hide() end end
-- IsShown (own shown flag), not IsVisible (false under any hidden ancestor): a
-- shown widget under a hidden parent must still toggle to hidden, not re-show.
function Region:Toggle() self:SetShown(not self._widget:IsShown()) end

---@param a number?  alpha (0–1)
---@return number?  the alpha when getting
function Region:Alpha(a) return a == nil and self._widget:GetAlpha() or self._widget:SetAlpha(a) end

-- Whether the cursor is currently within the region's hit rect.
---@return boolean
function Region:IsMouseOver() return self._widget:IsMouseOver() end
