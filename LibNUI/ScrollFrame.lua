---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Slider = ui.Frame, ui.Slider

---@class ScrollFrame: Frame
---@field scrollbar Slider|boolean?  when the `scrollbar` option is set, the themed scrollbar widget; the option itself otherwise
---@field scrollbarWidth number  themed scrollbar width in px (default 16)
---@field wheelStep number  pixels scrolled per mousewheel notch (default 30)
---@field _syncing boolean?  guard so scrollbar<->offset writes don't feed back on each other
local ScrollFrame = Class(Frame, function(self)
  if self.scrollbar then self:_buildScrollbar() end
end, {
  type = "ScrollFrame",
  template = "UIPanelScrollFrameTemplate",
  scrollbar = false,
  scrollbarWidth = 16,
  wheelStep = 30,
})
ui.ScrollFrame = ScrollFrame

-- Getter/setter for the scroll child. Accepts a LibNUI widget or a raw WoW frame.
---@param child Frame|table?
---@return table|ScrollFrame  the raw scroll child frame when getting; self when setting
function ScrollFrame:Child(child)
  if not child then
    return self._widget:GetScrollChild()
  end
  self._widget:SetScrollChild(child._widget or child)
  return self
end

-- Getter/setter for the vertical scroll offset (pixels from the top). When setting,
-- the value is clamped to the current scroll range, so callers can pass an
-- out-of-bounds target (e.g. "scroll this row into view") without overscrolling.
---@param offset number?
---@return number|ScrollFrame  the current offset when getting; self when setting
function ScrollFrame:VerticalScroll(offset)
  if offset == nil then return self._widget:GetVerticalScroll() end
  local range = self._widget:GetVerticalScrollRange()
  if offset < 0 then offset = 0 elseif offset > range then offset = range end
  self._widget:SetVerticalScroll(offset)
  -- keep the themed thumb in step with the offset (guarded: the thumb's own
  -- OnChange calls back into VerticalScroll)
  if type(self.scrollbar) == "table" then
    self._syncing = true
    self.scrollbar:Value(offset)
    self._syncing = false
  end
  return self
end

-- Recompute the scroll range after the child's content extent changed (e.g. rows were
-- shown/hidden) — a ScrollFrame only refreshes its range on UpdateScrollChildRect — then
-- re-clamp the current offset into the new range so the view can't stay scrolled into the
-- empty space left below shrunk content. Note the child's *content extent* drives the
-- range, not its set height: a caller that shrinks the child must also hide the frames it
-- left behind (see TableFrame:ResizeRows), or this recompute still sees the old extent.
---@return ScrollFrame
function ScrollFrame:Refresh()
  self._widget:UpdateScrollChildRect()
  self:VerticalScroll(self:VerticalScroll())   -- VerticalScroll clamps to the new range
  self:_syncScrollbar()
  return self
end

-- Build the opt-in themed scrollbar (`scrollbar = true`): hide the Blizzard template's
-- ScrollBar and overlay a LibNUI Slider on the inner right edge, driving the offset from
-- the thumb + mousewheel and hiding itself when the content fits. This is the only path
-- that overrides the template's wheel/range scripts, so default consumers keep the stock
-- Blizzard scrollbar untouched.
function ScrollFrame:_buildScrollbar()
  local blizzbar = self._widget.ScrollBar
  if blizzbar then blizzbar:Hide() end

  self.scrollbar = Slider:new{
    parent = self,
    orientation = "VERTICAL",
    thickness = self.scrollbarWidth,   -- fill the gutter so the track reads as a scrollbar
    position = {
      TopRight    = {self, ui.edge.TopRight, -1, -1},
      BottomRight = {self, ui.edge.BottomRight, -1, 1},
      Width       = self.scrollbarWidth,
    },
    OnChange = function(_, value)
      if self._syncing then return end
      self:VerticalScroll(value)
    end,
  }

  self._widget:EnableMouseWheel(true)
  self._widget:SetScript("OnMouseWheel", function(_, delta)
    self:VerticalScroll(self:VerticalScroll() - delta * self.wheelStep)
  end)
  self._widget:SetScript("OnScrollRangeChanged", function() self:_syncScrollbar() end)
  self:_syncScrollbar()
end

-- Fit the themed scrollbar to the live scroll range, sync its thumb to the current
-- offset, and hide it entirely when the content fits (range 0). No-op when the themed
-- scrollbar wasn't built.
function ScrollFrame:_syncScrollbar()
  local sb = self.scrollbar
  if type(sb) ~= "table" then return end
  local range = self._widget:GetVerticalScrollRange()
  if range <= 0 then
    sb:Hide()
    return
  end
  sb:Show()
  sb:MinMax(0, range)
  self._syncing = true
  sb:Value(self._widget:GetVerticalScroll())
  self._syncing = false
end

-- Scroll the minimum distance that brings a band of the content into view, and no further: a band
-- already visible doesn't move the view at all. `top` is measured from the top of the scroll CHILD
-- (not the viewport), which is the coordinate space a list already has for its rows — element i
-- starts at `(i - 1) * rowHeight`.
--
-- Deliberately minimum-distance rather than centring: arrowing down a list one step at a time
-- should nudge the view by one row, not jump the target to the middle of the viewport each press.
--
-- Both grids in the Collected suite had a copy of this, and a third copy lived in a consuming addon
-- as a version-skew fallback. Callers still clamp nothing themselves — `VerticalScroll` clamps to
-- the live range, so a band past the end of the content settles at the bottom rather than
-- overscrolling.
---@param top number  the band's offset from the top of the scroll child, in px
---@param height number  the band's height in px
---@return ScrollFrame
function ScrollFrame:EnsureVisible(top, height)
  local cur, view = self:VerticalScroll(), self:Height()
  if top < cur then
    self:VerticalScroll(top)                    -- above the viewport: bring its top to the top
  elseif top + height > cur + view then
    self:VerticalScroll(top + height - view)    -- below it: bring its bottom to the bottom
  end
  return self
end

-- Whether the content currently overflows the viewport (the view can scroll / the themed
-- scrollbar is showing). This is the single truth behind both scroll affordances — the
-- scrollbar's own show/hide (`_syncScrollbar`) reads the same range — so a consumer that
-- reserves a scrollbar gutter can gate it on this and stay in lockstep with the bar.
---@return boolean
function ScrollFrame:Scrolls()
  return self._widget:GetVerticalScrollRange() > 0
end
