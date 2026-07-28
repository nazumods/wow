---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Label, Button, Texture, BorderBox = ui.Frame, ui.Label, ui.Button, ui.Texture, ui.BorderBox
local ceil, max = math.ceil, math.max
local e = ui.edge

-- A row of captioned segments sharing one framed box, at most one of them lit — the horizontal,
-- content-free relative of `RadioGroup` (a vertical stack of checkboxes) and `TabFrame` (which owns
-- the panels it switches between). This one owns nothing: it reports which segment was picked and
-- the caller decides what that means, which is what an "Armor | Weapons" style mode switch needs
-- when the two things it switches are siblings the host already holds.
--
-- **Nothing is lit while `selected` is nil**, and `Select(nil)` returns to that. A mode switch whose
-- current subject belongs to neither mode has a state to show, and lighting a segment that isn't in
-- force would be a lie.
--
-- **Segments size themselves to the widest caption**, so the frame's own width is an outcome rather
-- than a guess — read it back with `Width()` to lay out beside it. A hand-picked width is how the
-- caption "Weapons" spent a long time rendering as "Wea…" in the window this came from.
--
-- The lit rim is a `BorderBox`, so its edges land on whole physical pixels (nazumods/wow#782).
---@class SegmentedOption
---@field key any       the value reported for this segment
---@field label string  the caption

---@class SegmentedToggle: Frame
---@field options SegmentedOption[]              the segments, laid out left to right
---@field selected any?                          initially lit key (nil lights none)
---@field height number                          segment height in px (default 20)
---@field padding number                         horizontal padding around the widest caption (default 24)
---@field activeColor string|number[]            lit rim: theme token or rgba (default "gold", falling back to "header")
---@field inactiveColor string|number[]          unlit rim (default a near-black)
---@field fillColor string|number[]              segment interior (default a near-black, a shade lighter than the rim)
---@field textColor string|number[]              caption colour (default "text")
---@field font table?                            `{path, size}`; defaults to the theme's `caps` slot at 10
---@field onSelect fun(self: SegmentedToggle, key: any)?  fired when a segment is clicked
---@field _rims BorderBox[]                      per-segment rims, index-aligned to `options`
local SegmentedToggle = Class(Frame, function(self)
  local h = self.height
  local caps = self:Theme().fonts.caps
  local font = self.font or (caps and {caps[1], 10}) or nil

  self._rims = {}
  local cells, widest = {}, 0
  for i, opt in ipairs(self.options) do
    -- Width comes later: it isn't known until every caption has been measured.
    local cell = Frame:new{ parent = self, position = { Height = h } }
    Texture:new{ parent = cell, layer = ui.layer.Background, position = { All = true }, color = self.fillColor }
    local key = opt.key
    local btn = Button:new{ parent = cell, position = { All = true },
      OnClick = function() self:_pick(key) end }
    local label = Label:new{ parent = btn, fontInfo = font, justifyH = ui.justify.Center,
      position = { All = true }, text = opt.label, color = self.textColor }
    -- Unbounded, because the label is anchored to a cell with no width yet — the bounded
    -- measurement would report whatever that zero-width rect allows rather than the caption.
    widest = max(widest, label:UnboundedWidth() or 0)
    -- After the button, so the rim draws over its hover glow rather than under it.
    self._rims[i] = BorderBox:new{ parent = cell, position = { All = true }, color = self.inactiveColor }
    cells[i] = cell
  end

  local segW = ceil(widest) + self.padding
  for i, cell in ipairs(cells) do
    cell:ClearAllPoints()
    cell:SetPoint(e.TopLeft, self, e.TopLeft, (i - 1) * segW, 0)
    cell:Width(segW)
  end
  self:Size(segW * #self.options, h)
  self:_apply()
end, {
  options = {},
  height = 20,
  padding = 24,
  activeColor = "gold",
  inactiveColor = {0.05, 0.05, 0.06, 0.92},
  fillColor = {0.09, 0.09, 0.11, 0.95},
  textColor = "text",
})
ui.SegmentedToggle = SegmentedToggle

-- The lit rim's colour: the theme's `gold` accent where it defines one, else its `header` token —
-- which is gold in LibNUI's own dark theme, so this renders correctly under no theme at all.
---@return number[]
function SegmentedToggle:_accent()
  return self:ThemeColor(self.activeColor) or self:ThemeColor("header")
end

-- Reflect the current selection onto the rims — at most one lit, none while `selected` is nil.
function SegmentedToggle:_apply()
  local accent = self:_accent()
  for i, opt in ipairs(self.options) do
    self._rims[i]:Color(self.selected == opt.key and accent or self.inactiveColor)
  end
end

-- A segment was clicked. Fires `onSelect` **every** time, including on the lit segment: what a
-- mode switch drives is normally idempotent, and swallowing the repeat would silently change what
-- the caller sees rather than what this widget draws.
---@param key any
function SegmentedToggle:_pick(key)
  self:Select(key)
  if self.onSelect then self:onSelect(key) end
end

-- Light the segment carrying `key`, or none for nil. Does not fire `onSelect` (mirrors
-- `FilterDropdown:Select`) — it is how a host reflects a mode it changed by some other route.
---@param key any?
---@return SegmentedToggle
function SegmentedToggle:Select(key)
  self.selected = key
  self:_apply()
  return self
end

-- The lit key, or nil when nothing is.
---@return any?
function SegmentedToggle:Selected() return self.selected end
