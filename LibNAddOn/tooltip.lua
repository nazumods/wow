---@class LibNAddOn
local ns = select(2, ...)

-- Item-tooltip post-hook helper.
--
-- Every headless tooltip addon in the suite appends lines to item tooltips the same way:
-- register a `TooltipDataProcessor` post-call for `Enum.TooltipDataType.Item`, bail on a
-- forbidden tooltip (Blizzard's secure/inspect tooltips), and bail when there's no data.
-- `OnItemTooltip` wraps that boilerplate so a consumer supplies only its own callback —
-- which keeps any addon-specific gating (e.g. a `data.id` check, shift-to-hide).
--
-- Registration is guarded on `TooltipDataProcessor` existing, so a client without the
-- modern tooltip API simply installs no hook rather than erroring.

---Run `fn(tooltip, data)` as an item-tooltip post-call, after the standard guards
---(non-forbidden tooltip, non-nil data).
---@param self AddOn
---@param fn fun(tooltip: table, data: table)
local function OnItemTooltip(self, fn)
  if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall) then return end
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if not data then return end
    if tooltip.IsForbidden and tooltip:IsForbidden() then return end
    fn(tooltip, data)
  end)
end

---@class AddOn
---@field OnItemTooltip fun(self: AddOn, fn: fun(tooltip: table, data: table)) append to item tooltips via a guarded TooltipDataProcessor post-call

---@class LibNAddOn
---@field linkTooltipHelpers fun(addOn: AddOn) add the tooltip-hook helpers to an addon
function ns.linkTooltipHelpers(addOn)
  addOn.OnItemTooltip = OnItemTooltip
end
