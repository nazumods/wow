---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame = ui.Frame

---@class ScrollFrame: Frame
local ScrollFrame = Class(Frame, function(self)
end, {
  type = "ScrollFrame",
  template = "UIPanelScrollFrameTemplate",
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
  return self
end

-- Recompute the scroll range after the child's height changed (e.g. rows were added
-- or removed) — WoW caches the range and only refreshes it on UpdateScrollChildRect,
-- then re-clamp the current offset into the new range so the view can't stay scrolled
-- into the empty space left below a shrunk child.
--
-- UpdateScrollChildRect measures the child's *rendered* rect, which doesn't reflect a
-- SetHeight made earlier in the same frame until the next layout pass. Recomputing only
-- now would measure the stale (pre-resize) height and leave the range too large, so we
-- recompute again on the next frame once the child's new size has been laid out — that
-- deferred pass is the one that actually lands when a filter shrank the child.
---@return ScrollFrame
function ScrollFrame:Refresh()
  local widget = self._widget
  local function recompute()
    widget:UpdateScrollChildRect()
    self:VerticalScroll(self:VerticalScroll())   -- VerticalScroll clamps to the new range
  end
  recompute()                  -- synchronous case (child already laid out)
  C_Timer.After(0, recompute)  -- deferred case (child resized this frame)
  return self
end
