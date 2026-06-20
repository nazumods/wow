---@type Warbandeer
local ns = select(2, ...)
local theme = ns.theme
local CreateFrame, UIParent = CreateFrame, UIParent

-- Shared item tooltip for gear rows/cells across views (Detail, Gear). Uses a
-- private GameTooltip frame rather than the shared one: it renders the stored item
-- link directly (works for any character's gear without the item being cached) and
-- keeps WoW's automatic item-comparison off.
--
-- A second private tooltip (`compareTip`) is shown beside the main one when a
-- `compareLink` is passed — Detail uses this to lay the suggested-upgrade item
-- next to the equipped one, so both are visible at once. `noUpgradeBlock` sets the
-- `SkipUpgradeBlock` opt-out (read by ShadowsOfUI-Upgrade's tooltip post-call) so
-- the "Upgrade for:" line is suppressed on these private tooltips.
---@class Warbandeer
---@field ShowItemTooltip fun(frame: table, link: string, compareLink?: string, noUpgradeBlock?: boolean)
---@field HideItemTooltip fun()                             hide it
---@field ShowEnchantTooltip fun(frame: table, suggestion: table)  recommended-enchant detail

-- Dark, near-black border for these item tooltips (the theme's tan `border` token
-- reads too bright here) — matches the look of a darkened-UI tooltip.
local BORDER = { 0.10, 0.10, 0.12, 1 }

-- Reskin the frame to match the suite's custom tooltips (CleanFrame): a flat black
-- surface with a dark border, in place of the default ornate backdrop. Modern
-- GameTooltipTemplate frames no longer inherit BackdropTemplate, so the look is set
-- on the frame's NineSlice. The tooltip re-applies its default backdrop (and an
-- item-quality border) when content is set, so this is re-run after each
-- SetHyperlink rather than only at creation.
local function styleTooltip(gt)
  gt.NineSlice:SetCenterColor(0, 0, 0, 0.94)  -- near-opaque so item text stays legible
  gt.NineSlice:SetBorderColor(BORDER[1], BORDER[2], BORDER[3], 1)
end

local itemTip
local function getItemTip()
  if itemTip then return itemTip end
  itemTip = CreateFrame("GameTooltip", "WarbandeerItemTooltip", UIParent, "GameTooltipTemplate")
  styleTooltip(itemTip)
  return itemTip
end

-- A small "Equipped" tab integrated into the top-left of the equipped item's
-- tooltip (mirroring WoW's comparison tooltips), shown only while a suggested
-- upgrade sits beside it so the player can tell the two apart. It shares the
-- tooltip's fill + dark border and overlaps the top edge so the two read as one
-- piece. Lazily built on the owning tip.
local function getEquippedTab(gt)
  if gt._equippedTab then return gt._equippedTab end
  local tab = CreateFrame("Frame", nil, gt, "BackdropTemplate")
  tab:SetFrameStrata("TOOLTIP")
  tab:SetFrameLevel(gt:GetFrameLevel() + 2)
  tab:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
  })
  tab:SetBackdropColor(0, 0, 0, 0.94)
  tab:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 1)
  local g = theme.colors.green
  tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  tab.text:SetText("Equipped")
  tab.text:SetTextColor(g[1], g[2], g[3])
  tab.text:SetPoint("CENTER", 0, 1)
  tab:SetSize(tab.text:GetStringWidth() + 16, tab.text:GetStringHeight() + 8)
  -- Overlap the tooltip's top border by 2px so the tab merges into the body.
  tab:SetPoint("BOTTOMLEFT", gt, "TOPLEFT", 8, -2)
  gt._equippedTab = tab
  return tab
end

-- The comparison tooltip (the suggested-upgrade item shown beside the equipped one).
-- Always opts out of the "Upgrade for:" block — it *is* the suggested upgrade, so
-- the line would be redundant.
local compareTip
local function getCompareTip()
  if compareTip then return compareTip end
  compareTip = CreateFrame("GameTooltip", "WarbandeerItemCompareTooltip", UIParent, "GameTooltipTemplate")
  compareTip.SkipUpgradeBlock = true
  styleTooltip(compareTip)
  return compareTip
end

-- Anchor below the hovered frame on the configured side, render `link`, and re-skin
-- (SetHyperlink resets the backdrop + stamps a quality border). `frame` may be a
-- LibNUI widget or a raw frame. When `compareLink` is given, the suggested-upgrade
-- item is shown on the *anchored* tooltip (closest to the row/cursor, like the item
-- you're considering in a normal comparison) and the currently-equipped item in a
-- second tooltip that extends outward beside it, carrying the "Equipped" tab.
---@param frame table          LibNUI widget or raw frame to anchor against
---@param link string          equipped item hyperlink
---@param compareLink string?  suggested-upgrade item hyperlink (shows a comparison tooltip)
---@param noUpgradeBlock boolean?  suppress ShadowsOfUI-Upgrade's "Upgrade for:" line
function ns.ShowItemTooltip(frame, link, compareLink, noUpgradeBlock)
  local right = ns.TooltipSide() == 2
  local gt = getItemTip()
  gt.SkipUpgradeBlock = noUpgradeBlock or nil
  gt:SetOwner(frame._widget or frame, right and "ANCHOR_RIGHT" or "ANCHOR_LEFT")

  if not compareLink then
    gt:SetHyperlink(link)
    gt:Show()
    styleTooltip(gt)
    if compareTip then compareTip:Hide() end
    if gt._equippedTab then gt._equippedTab:Hide() end
    return
  end

  -- gt (anchored, closest to the row) shows the suggested upgrade; the equipped item
  -- goes on ct, extending outward away from the row (right on the right side, left on
  -- the left side) so the suggested item stays nearest the cursor.
  gt:SetHyperlink(compareLink)
  gt:Show()
  styleTooltip(gt)

  local ct = getCompareTip()
  ct:SetOwner(gt, "ANCHOR_NONE")
  ct:ClearAllPoints()
  if right then
    ct:SetPoint("TOPLEFT", gt, "TOPRIGHT", 4, 0)
  else
    ct:SetPoint("TOPRIGHT", gt, "TOPLEFT", -4, 0)
  end
  ct:SetHyperlink(link)
  ct:Show()
  styleTooltip(ct)

  if gt._equippedTab then gt._equippedTab:Hide() end
  getEquippedTab(ct):Show()
end

local GetSpellName = (C_Spell and C_Spell.GetSpellName) or _G.GetSpellInfo
local GetItemName = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetSpellDescription = (C_Spell and C_Spell.GetSpellDescription) or _G.GetSpellDescription
local GetItemSpell = (C_Item and C_Item.GetItemSpell) or _G.GetItemSpell

-- Resolve an EnchantSuggestion to (name, effect-description). The description is the line
-- that says what the enchant *grants* — for a spell id (bundled enchanting recipe) it's the
-- spell's own description; for an item id (ClassCodex scroll) it's the item's use-spell
-- description (`GetItemSpell` → the enchant the scroll applies). Either may be nil/empty when
-- the spell/item data isn't cached yet (the name still shows; the body fills on next hover).
---@param suggestion table  EnchantSuggestion { kind, id, name? }
---@return string? name, string? description
local function enchantText(suggestion)
  local name, desc = suggestion.name, nil
  if suggestion.kind == "spell" and suggestion.id then
    name = name or GetSpellName(suggestion.id)
    desc = GetSpellDescription and GetSpellDescription(suggestion.id)
  elseif suggestion.kind == "item" and suggestion.id then
    name = name or (GetItemName(suggestion.id))
    local _, spellID = GetItemSpell(suggestion.id)
    desc = spellID and GetSpellDescription and GetSpellDescription(spellID)
  end
  return name, desc
end

-- Hover detail for a recommended enchant (the "Missing enchant → …" note in the Detail gear
-- list): a focused tooltip on the shared private item frame — the enchant's name plus a
-- wrapped description of what it grants (not the scroll/recipe's full item tooltip, which
-- carries reagents/sell price the player doesn't need here). `suggestion` is
-- ShadowsOfUI-Upgrade's EnchantSuggestion. Reuses `itemTip`, so ns.HideItemTooltip hides it.
---@param frame table       LibNUI widget or raw frame to anchor against
---@param suggestion table  EnchantSuggestion { kind, id, name? }
function ns.ShowEnchantTooltip(frame, suggestion)
  local right = ns.TooltipSide() == 2
  local gt = getItemTip()
  gt.SkipUpgradeBlock = true
  gt:SetOwner(frame._widget or frame, right and "ANCHOR_RIGHT" or "ANCHOR_LEFT")
  gt:ClearLines()
  local name, desc = enchantText(suggestion)
  gt:AddLine(name or "Recommended enchant", 1, 0.82, 0)   -- gold header, like a spell name
  if desc and desc ~= "" then
    local g = theme.colors.green
    gt:AddLine(desc, g[1], g[2], g[3], true)              -- green effect text, wrapped
  end
  gt:Show()
  styleTooltip(gt)
end

-- Hover detail for a recommended gem (Detail's "Empty socket → …" note). A gem has no
-- use-spell — its effect is the stat line on its own (short) item tooltip — so this shows
-- that directly. `suggestion` is ShadowsOfUI-Upgrade's EnchantSuggestion `{kind="item", id,
-- name?}`. Reuses `itemTip`, so ns.HideItemTooltip hides it.
---@param frame table       LibNUI widget or raw frame to anchor against
---@param suggestion table  EnchantSuggestion { kind="item", id, name? }
function ns.ShowGemTooltip(frame, suggestion)
  local right = ns.TooltipSide() == 2
  local gt = getItemTip()
  gt.SkipUpgradeBlock = true
  gt:SetOwner(frame._widget or frame, right and "ANCHOR_RIGHT" or "ANCHOR_LEFT")
  if suggestion.id then
    gt:SetItemByID(suggestion.id)
  else
    gt:ClearLines()
    gt:AddLine(suggestion.name or "Recommended gem", 1, 0.82, 0)
  end
  gt:Show()
  styleTooltip(gt)
end

function ns.HideItemTooltip()
  if itemTip then
    itemTip:Hide()
    if itemTip._equippedTab then itemTip._equippedTab:Hide() end
  end
  if compareTip then
    compareTip:Hide()
    if compareTip._equippedTab then compareTip._equippedTab:Hide() end
  end
end
