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

function Region:All() self._widget:SetAllPoints() end
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
