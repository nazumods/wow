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
