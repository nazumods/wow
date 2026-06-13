---@type ShadowsOfUI_Upgrade
local ns = select(2, ...)
local Upgrade = ns.UpgradeApi
local floor = math.floor

local LABEL = NORMAL_FONT_COLOR

-- Whether the tooltip's item is soulbound (a "Soulbound" binding line).  Soulbound
-- gear is only useful to whoever it's already bound to; BoE / Warbound-until-
-- equipped items show a different binding line and stay viable for any character.
local function isSoulbound(data)
  if not data.lines then return false end
  for _, line in ipairs(data.lines) do
    if line.leftText == ITEM_SOULBOUND then return true end
  end
  return false
end

-- A character name wrapped in its class colour (ns.Colors keys are PascalCase,
-- matching Character.classKey).
local function colorName(name, classKey)
  local c = ns.Colors[classKey]
  if not c or not c[1] then return name end
  return ("|cff%02x%02x%02x%s|r"):format(floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5), name)
end

-- Trailing "(+N good stats)" annotation for one upgrade entry.
local function suffix(entry)
  local gain = ("+%d"):format(entry.ilvlGain)
  if entry.statTag == "good" then
    return " " .. GREEN_FONT_COLOR:WrapTextInColorCode(gain .. " ilvl, good stats")
  elseif entry.statTag == "off" then
    return " " .. GRAY_FONT_COLOR:WrapTextInColorCode(gain .. " ilvl, off-stats")
  end
  return " " .. GRAY_FONT_COLOR:WrapTextInColorCode(gain .. " ilvl")
end

-- Append the "Upgrade for:" block: one inline line for a single character, else a
-- header plus up to 5 names (then "and N more.").
local function render(tooltip, list)
  local n = #list
  if n == 1 then
    tooltip:AddLine(LABEL:WrapTextInColorCode("Upgrade for:") .. " " .. colorName(list[1].name, list[1].classKey) .. suffix(list[1]))
    return
  end
  tooltip:AddLine(LABEL:WrapTextInColorCode("Upgrade for:"))
  local shown = n > 5 and 4 or n
  for i = 1, shown do
    tooltip:AddLine("  " .. colorName(list[i].name, list[i].classKey) .. suffix(list[i]))
  end
  if n > shown then
    tooltip:AddLine(GRAY_FONT_COLOR:WrapTextInColorCode(("  and %d more."):format(n - shown)))
  end
end

local function onItemTooltip(tooltip, data)
  if not data then return end
  if tooltip.IsForbidden and tooltip:IsForbidden() then return end
  -- Prefer the displayed link (carries bonus IDs → correct scaled ilvl).
  local link
  if TooltipUtil and TooltipUtil.GetDisplayedItem then
    link = select(2, TooltipUtil.GetDisplayedItem(tooltip))
  end
  if not link and data.id then link = "item:" .. data.id end
  if not link then return end
  -- Soulbound items can only ever help their holder (the current character).
  local boundTo = isSoulbound(data) and ns.api:GetCurrentCharacter() or nil
  local list = Upgrade:ItemUpgrades(link, boundTo)
  if list then render(tooltip, list) end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItemTooltip)
end

-- /supgrade [name] — dump the available upgrades for a character (defaults to the
-- logged-in one).  Testing aid, since tooltip text can't be copied.
SLASH_SUI_UPGRADE1 = "/supgrade"
SlashCmdList["SUI_UPGRADE"] = function(msg)
  local name = msg and msg:gsub("^%s+", ""):gsub("%s+$", "")
  if not name or name == "" then name = ns.api:GetCurrentCharacter() end
  local list = Upgrade:CharacterUpgrades(name)
  if #list == 0 then
    ns.Print(("No available upgrades for %s (open their bags/bank + the warband bank first)."):format(name))
    return
  end
  ns.Print(("Available upgrades for %s (%d):"):format(name, #list))
  for _, r in ipairs(list) do
    ns.Print((" - %s  +%d ilvl (%s)%s%s"):format(
      r.slot, r.ilvlGain, r.where,
      r.statTag and (", " .. r.statTag .. " stats") or "",
      r.betterElsewhere and "  [better in warband bank]" or ""))
  end
end
