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

-- Whether the tooltip's item is Bind-on-Pickup but not yet bound (a "Binds when
-- picked up" line).  Such an item can't be moved between characters, so the
-- cross-character "Upgrade for:" block is noise — skip it entirely.
local function isBindOnPickup(data)
  if not data.lines then return false end
  for _, line in ipairs(data.lines) do
    if line.leftText == ITEM_BIND_ON_PICKUP then return true end
  end
  return false
end

-- The hovered item's *effective* (context-scaled) item level, read off the
-- displayed "Item Level NNN" line.  This is what GetCurrentItemLevel reports for
-- equipped gear, so the candidate is compared on the same basis; the link's
-- GetDetailedItemLevelInfo gives the unscaled level instead, so an item downscaled
-- in Chromie Time / a scaled zone (true 655 shown as 102) would fake a huge upgrade.
-- ITEM_LEVEL is the localised "Item Level %d" format; turn its %d into a capture.
local ILVL_PATTERN = (ITEM_LEVEL or "Item Level %d"):gsub("%%d", "(%%d+)")
local function effectiveIlvl(data)
  if not data.lines then return nil end
  for _, line in ipairs(data.lines) do
    local n = line.leftText and line.leftText:match(ILVL_PATTERN)
    if n then return tonumber(n) end
  end
  return nil
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

-- Enchantable equipped slots → their inventory slot id (resolved once). The
-- off-hand is included but only counts when it currently holds a weapon (a shield /
-- holdable can't be enchanted), matching enhance.lua's slotTakesEnchant.
local ENCH_INV = {}
do
  local names = {
    Head = "HeadSlot", Shoulder = "ShoulderSlot", Chest = "ChestSlot", Legs = "LegsSlot",
    Feet = "FeetSlot", Finger1 = "Finger0Slot", Finger2 = "Finger1Slot",
    MainHand = "MainHandSlot", OffHand = "SecondaryHandSlot",
  }
  for slot, invName in pairs(names) do
    if ns.EnchantableSlots[slot] or slot == "OffHand" then
      ENCH_INV[slot] = GetInventorySlotInfo(invName)
    end
  end
end
local WEAPON_EQUIPLOC = {
  INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_WEAPONMAINHAND = true,
}
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant
local GetSpellName = (C_Spell and C_Spell.GetSpellName) or _G.GetSpellInfo
local NO_ENCHANT = "|cffff8000Missing enchant|r"

-- The equipped slot `link` sits in if it's one of the player's own currently-equipped
-- enchantable items with no permanent enchant, else nil. A pure equipped-gear reminder
-- — it never matches a loose bag / vendor copy (those aren't in an equipped slot).
local function equippedMissingSlot(link)
  for slot, invSlot in pairs(ENCH_INV) do
    if GetInventoryItemLink("player", invSlot) == link then
      if slot == "OffHand" then
        local equipLoc = GetItemInfoInstant and select(4, GetItemInfoInstant(link))
        if not WEAPON_EQUIPLOC[equipLoc] then return nil end
      end
      if ns.ItemEnchantID(link) == 0 then return slot end
      return nil
    end
  end
  return nil
end

-- Display name for an EnchantSuggestion: ClassCodex carries its own name; a bundled
-- recipe (spell) resolves via GetSpellName; an item id falls back to GetItemInfo.
local GetItemName = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local function suggestionName(s)
  if not s then return nil end
  if s.name then return s.name end
  if s.kind == "spell" and GetSpellName then return GetSpellName(s.id) end
  if s.kind == "item" and s.id and GetItemName then return (GetItemName(s.id)) end
  return nil
end

-- The "Missing enchant" line, with a "— recommend <enchant>" tail when we have a pick
-- for this slot + the player's spec (ClassCodex when installed, else the bundled recipe).
local function missingEnchantLine(slot)
  local s = ns.RecommendedEnchant(ns.api:GetCharacterData(ns.api:GetCurrentCharacter()), slot)
  local name = suggestionName(s)
  if name then
    return NO_ENCHANT .. GRAY_FONT_COLOR:WrapTextInColorCode(" — recommend ") .. name
  end
  return NO_ENCHANT
end

local GetItemNumSockets = C_Item and C_Item.GetItemNumSockets
local GetItemGemID = C_Item and C_Item.GetItemGemID
-- Cyan (vs the orange "Missing enchant") so the two reminders read as different things.
local EMPTY_SOCKET = "|cff4fc3f7Empty socket|r"

-- Empty gem sockets on `link` only when it's one of the player's own equipped items
-- (any slot), so we never nag about loose / vendor gear. Count sockets without a gem via
-- GetItemGemID — NOT the GetItemStats EMPTY_SOCKET_* keys, which the Midnight Gem Manager
-- leaves set on items it has gemmed (the manager applies gems outside the stat block).
local function equippedEmptySockets(link)
  if not GetItemNumSockets then return 0 end
  local equipped = false
  for slot = 1, 17 do
    if GetInventoryItemLink("player", slot) == link then equipped = true; break end
  end
  if not equipped then return 0 end
  local n = 0
  for i = 1, (GetItemNumSockets(link) or 0) do
    if GetItemGemID(link, i) == nil then n = n + 1 end
  end
  return n
end

-- The "Empty socket" line, with a "— recommend <gem>" tail. Uses the **secondary** (fill)
-- gem, not the unique diamond: a single item's socket has no idea whether the one diamond is
-- already placed elsewhere, and a secondary gem is always safe to add.
local function emptySocketLine()
  local _, secondary = ns.RecommendedGems(ns.api:GetCharacterData(ns.api:GetCurrentCharacter()))
  local name = suggestionName(secondary)
  if name then
    return EMPTY_SOCKET .. GRAY_FONT_COLOR:WrapTextInColorCode(" — recommend ") .. name
  end
  return EMPTY_SOCKET
end

-- Embedded item tooltips (quest / world-quest reward previews) parent their inner
-- tooltip back onto the container as `container.Tooltip`.  The standalone
-- GameTooltip / ItemRefTooltip are nobody's `.Tooltip`, so this skips reward
-- blocks (WQ map pins, quest log) while keeping normal item hovers.
local function isEmbedded(tooltip)
  local parent = tooltip.GetParent and tooltip:GetParent()
  return parent and parent.Tooltip == tooltip
end

local function onItemTooltip(tooltip, data)
  if not data then return end
  if tooltip.IsForbidden and tooltip:IsForbidden() then return end
  -- Opt-out hook: a consumer can set `tooltip.SkipUpgradeBlock = true` on its own
  -- GameTooltip frame to suppress the block (e.g. Warbandeer's Detail view, which
  -- shows the suggested upgrade as a side-by-side comparison instead).
  if tooltip.SkipUpgradeBlock then return end
  if isEmbedded(tooltip) then return end
  -- Bind-on-Pickup gear (not yet bound) can't move between characters, so there's
  -- no point recommending it for the warband.
  if isBindOnPickup(data) then return end
  -- Prefer the displayed link (carries bonus IDs → correct scaled ilvl).
  local link
  if TooltipUtil and TooltipUtil.GetDisplayedItem then
    link = select(2, TooltipUtil.GetDisplayedItem(tooltip))
  end
  if not link and data.id then link = "item:" .. data.id end
  if not link then return end
  -- Enchant/gem reminders only once the character is max level — a still-levelling
  -- char churns gear too fast to bother enchanting/gemming (mirrors enhance.lua's gate
  -- on the ns.* surfaces). The cross-character "Upgrade for:" block below is unaffected.
  local meData = ns.api:GetCharacterData(ns.api:GetCurrentCharacter())
  if not ns.BelowMaxLevel(meData) then
    -- Reminder line for your own equipped gear that's missing its permanent enchant,
    -- with the recommended enchant when we have one for the slot.
    local missSlot = equippedMissingSlot(link)
    if missSlot then tooltip:AddLine(missingEnchantLine(missSlot)) end
    -- Reminder for your own equipped gear with an empty gem socket.
    if equippedEmptySockets(link) > 0 then tooltip:AddLine(emptySocketLine()) end
  end
  -- Soulbound items can only ever help their holder (the current character).
  local boundTo = isSoulbound(data) and ns.api:GetCurrentCharacter() or nil
  local list = Upgrade:ItemUpgrades(link, boundTo, effectiveIlvl(data))
  if list then render(tooltip, list) end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItemTooltip)
end

-- /supgrade [name]            — dump the available upgrades for a character
-- /supgrade enchants [name]   — dump enchant resolution (why a slot has no recommendation)
-- Defaults to the logged-in character.  Testing aid, since tooltip text can't be copied.
SLASH_SUI_UPGRADE1 = "/supgrade"
SlashCmdList["SUI_UPGRADE"] = function(msg)
  local arg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")

  -- enchant-resolution dump → copyable window (LibNUI is loaded transitively via
  -- Warbandeer_Characters, even though we don't declare it; fall back to chat if not).
  local sub, rest = arg:match("^(%S+)%s*(.-)$")
  if sub == "enchants" then
    local name = (rest ~= "" and rest) or ns.api:GetCurrentCharacter()
    local charData = ns.api:GetCharacterData(name)
    if not charData then ns.Print(("No data for %s."):format(name)) return end
    local text = ns.DumpEnchants(charData)
    if _G.LibNUI and _G.LibNUI.ShowCopyWindow then
      _G.LibNUI.ShowCopyWindow(("Enchant debug — %s"):format(name), text)
    else
      for line in text:gmatch("[^\n]+") do ns.Print(line) end
    end
    return
  end

  local name = arg
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
