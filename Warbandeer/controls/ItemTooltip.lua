---@type Warbandeer
local ns = select(2, ...)
local theme = ns.theme
local CreateFrame, UIParent = CreateFrame, UIParent

-- Shared item tooltip for gear rows/cells across views (Detail, Gear). Uses a
-- private GameTooltip frame rather than the shared one: it renders the stored item
-- link directly (works for any character's gear without the item being cached) and
-- keeps the automatic item-comparison off — these are already-equipped items, so a
-- comparison would be noise.
---@class Warbandeer
---@field ShowItemTooltip fun(frame: table, link: string)  anchor + show the item tooltip
---@field HideItemTooltip fun()                             hide it

-- Reskin the frame to match the suite's custom tooltips (CleanFrame): a flat black
-- surface with a subtle theme-coloured border, in place of the default ornate
-- backdrop. Modern GameTooltipTemplate frames no longer inherit BackdropTemplate,
-- so the look is set on the frame's NineSlice. The tooltip re-applies its default
-- backdrop (and an item-quality border) when content is set, so this is re-run
-- after each SetHyperlink rather than only at creation.
local function styleTooltip(gt)
  local b = theme.colors.border
  gt.NineSlice:SetCenterColor(0, 0, 0, 0.7)
  gt.NineSlice:SetBorderColor(b[1], b[2], b[3], b[4])
end

local itemTip
local function getItemTip()
  if itemTip then return itemTip end
  itemTip = CreateFrame("GameTooltip", "WarbandeerItemTooltip", UIParent, "GameTooltipTemplate")
  styleTooltip(itemTip)
  return itemTip
end

-- Anchor below the hovered frame on the configured side, render `link`, and re-skin
-- (SetHyperlink resets the backdrop + stamps a quality border). `frame` may be a
-- LibNUI widget or a raw frame.
---@param frame table  LibNUI widget or raw frame to anchor against
---@param link string  item hyperlink
function ns.ShowItemTooltip(frame, link)
  local gt = getItemTip()
  gt:SetOwner(frame._widget or frame, ns.TooltipSide() == 2 and "ANCHOR_RIGHT" or "ANCHOR_LEFT")
  gt:SetHyperlink(link)
  gt:Show()
  styleTooltip(gt)
end

function ns.HideItemTooltip()
  if itemTip then itemTip:Hide() end
end
