---@type ShadowsOfUI_WarbandInventory
local ns = select(2, ...)
---@type WarbandeerAPI
local API = ns.api

local concat = table.concat
local LABEL = NORMAL_FONT_COLOR
local MUTED = GRAY_FONT_COLOR
local COUNT = WHITE_FONT_COLOR
local TOTAL = HIGHLIGHT_FONT_COLOR

-- Per-character lines shown before the rest collapse into a "/swinv" hint line.
local MAX_CHARS = 16

local function abbr(n)
  return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)
end

-- Inline source breakdown for a character entry, e.g. "(Bags: 3, Bank: 2)" —
-- only the non-zero locations, in bags-then-bank order. Always non-empty (a
-- character only appears in the report when its total is > 0).
---@param e ItemCountEntry
local function sources(e)
  local parts = {}
  if e.bags > 0 then parts[#parts + 1] = "Bags: " .. abbr(e.bags) end
  if e.bank > 0 then parts[#parts + 1] = "Bank: " .. abbr(e.bank) end
  if e.mail > 0 then parts[#parts + 1] = "Mail: " .. abbr(e.mail) end
  return "(" .. concat(parts, ", ") .. ")"
end

-- Class-coloured character name, with " (Realm)" appended when the character is on a
-- different realm than the current one (the API sets `realm` only in that case).
---@param e ItemCountEntry
local function charLabel(e)
  local name = e.realm and (e.name .. " (" .. e.realm .. ")") or e.name
  return ns.ColorName(name, e.classKey)
end

-- Append the "Warband stock" block: a header with the grand total, one
-- right-aligned class-coloured line per character (bags + personal bank), then
-- the shared warband bank and any guild banks.
---@param report ItemCountReport
---@param itemID integer
local function render(tooltip, report, itemID)
  tooltip:AddLine(LABEL:WrapTextInColorCode("Warband stock"))

  local chars = report.characters
  local shown = #chars
  local capped = false
  if shown > MAX_CHARS then
    shown = MAX_CHARS - 1 -- leave room for the "and N more" line
    capped = true
  end
  for i = 1, shown do
    local e = chars[i]
    tooltip:AddDoubleLine(
      "  " .. charLabel(e),
      COUNT:WrapTextInColorCode(abbr(e.total)) .. "  " .. MUTED:WrapTextInColorCode(sources(e)))
  end
  if capped then
    tooltip:AddLine(MUTED:WrapTextInColorCode(
      ("  +%d more — /swinv %d for the full list"):format(#chars - shown, itemID)))
  end

  if report.warband > 0 then
    tooltip:AddDoubleLine(
      MUTED:WrapTextInColorCode("  Warband bank"),
      COUNT:WrapTextInColorCode(abbr(report.warband)))
  end
  for _, g in ipairs(report.guilds) do
    tooltip:AddDoubleLine(
      MUTED:WrapTextInColorCode("  " .. g.name),
      COUNT:WrapTextInColorCode(abbr(g.count)))
  end

  -- Grand total across every source, at the very bottom (Altoholic's "Total owned").
  tooltip:AddDoubleLine(
    LABEL:WrapTextInColorCode("Total owned"),
    TOTAL:WrapTextInColorCode(abbr(report.total)))
end

local function onItemTooltip(tooltip, data)
  if not data or not data.id then return end
  if tooltip.IsForbidden and tooltip:IsForbidden() then return end
  -- Holding Shift hides the block. Shift also triggers a tooltip refresh (it
  -- toggles item comparison), so the block disappears the instant it's pressed.
  if IsShiftKeyDown() then return end
  local report = API:GetItemCounts(data.id)
  if not report then return end
  render(tooltip, report, data.id)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItemTooltip)
end

-- /swinv <itemID | item link> — print the warband-stock breakdown for an item
-- (testing aid + a "find item" lookup, since tooltip text can't be copied).
SLASH_SUI_WINV1 = "/swinv"
SlashCmdList["SUI_WINV"] = function(msg)
  local itemID = tonumber(msg and msg:match("item:(%d+)")) or tonumber(msg and msg:match("%d+"))
  if not itemID then ns.Print("Usage: /swinv <itemID or item link>") return end
  local name = GetItemInfo(itemID) or itemID
  local report = API:GetItemCounts(itemID)
  if not report then
    ns.Print("No copies of", name, "tracked yet (log alts in / open bags + banks to populate).")
    return
  end
  ns.Print(("%s — %d total across the warband:"):format(tostring(name), report.total))
  for _, e in ipairs(report.characters) do
    local who = e.realm and (e.name .. " (" .. e.realm .. ")") or e.name
    ns.Print(("  %s: %d (bags %d, bank %d, mail %d)"):format(who, e.total, e.bags, e.bank, e.mail))
  end
  if report.warband > 0 then ns.Print(("  Warband bank: %d"):format(report.warband)) end
  for _, g in ipairs(report.guilds) do ns.Print(("  %s: %d"):format(g.name, g.count)) end
end
