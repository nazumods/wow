---@type ShadowsOfUI_ProfCommissions
local ns = select(2, ...)

---@class ShadowsOfUI_ProfCommissions
---@field PopulateRewardIcons fun(cell: table, rowData: table)

local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
local QUALITY_COLORS = ITEM_QUALITY_COLORS

-- On the crafter's "Crafting Orders" browse list, Patron (NPC) orders carry bonus item/currency
-- rewards on top of the gold commission. Blizzard renders these as a single generic treasure-chest
-- icon in the Commission cell (ProfessionsCrafterTableCellCommissionMixin) whose contents only show
-- on hover. We replace that chest with the actual reward icons in the same spot — each still hoverable
-- for the full item/currency tooltip, so you can see *what* the reward is at a glance without opening
-- every order.

-- Point the tooltip at whatever this icon represents (an item link or a currency).
local function iconOnEnter(icon)
  GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
  if icon.itemLink then
    GameTooltip:SetHyperlink(icon.itemLink)
  elseif icon.currencyType then
    GameTooltip:SetCurrencyByID(icon.currencyType)
  end
  local row = icon:GetParent() and icon:GetParent():GetParent()
  if row and row.HighlightTexture then row.HighlightTexture:Show() end
  GameTooltip:Show()
end

local function iconOnLeave(icon)
  GameTooltip:Hide()
  local row = icon:GetParent() and icon:GetParent():GetParent()
  if row and row.HighlightTexture then row.HighlightTexture:Hide() end
end

-- Lazily grow a per-cell pool of reward-icon buttons, so recycled rows reuse their buttons.
---@param cell table  the commission table cell
---@param index integer
local function acquireIcon(cell, index)
  local pool = cell.soiRewardIcons
  local icon = pool[index]
  if icon then return icon end

  icon = CreateFrame("Button", nil, cell)

  icon.tex = icon:CreateTexture(nil, "ARTWORK")
  icon.tex:SetAllPoints()
  icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the default icon border

  -- Quality-tinted frame around the icon (item rewards only). WhiteIconFrame is a hollow border
  -- texture, so vertex-colouring it rims the icon without painting over it.
  icon.border = icon:CreateTexture(nil, "OVERLAY")
  icon.border:SetTexture("Interface\\Common\\WhiteIconFrame")
  icon.border:SetPoint("TOPLEFT", -1, 1)
  icon.border:SetPoint("BOTTOMRIGHT", 1, -1)

  icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  icon.count:SetPoint("BOTTOMRIGHT", 1, 0)

  icon:SetScript("OnEnter", iconOnEnter)
  icon:SetScript("OnLeave", iconOnLeave)

  pool[index] = icon
  return icon
end

-- Fill one reward icon from a reward entry: { itemLink, count } or { currencyType, count }.
local function fillIcon(icon, reward)
  local size = ns.tuning.iconSize
  icon:SetSize(size, size) -- re-applied each populate so /sprofcomm size retunes live
  icon.itemLink, icon.currencyType = nil, nil
  local texture, quality

  if reward.itemLink then
    icon.itemLink = reward.itemLink
    local _, _, _, _, tex = GetItemInfoInstant(reward.itemLink)
    texture = tex
    quality = C_Item.GetItemQualityByID(reward.itemLink)
  elseif reward.currencyType then
    icon.currencyType = reward.currencyType
    local info = GetCurrencyInfo(reward.currencyType)
    texture = info and info.iconFileID
    quality = info and info.quality
  end

  icon.tex:SetTexture(texture or 134400) -- INV_Misc_QuestionMark fallback

  -- Quality border is item-rewards-only (per README/CONTEXT); currency rewards can
  -- also report a quality but must not get the border.
  local color = reward.itemLink and quality and quality > Enum.ItemQuality.Common and QUALITY_COLORS[quality]
  if color then
    icon.border:SetVertexColor(color.r, color.g, color.b)
    icon.border:Show()
  else
    icon.border:Hide()
  end

  local count = reward.count or 0
  if count > 1 then
    icon.count:SetText(AbbreviateNumbers(count))  -- currency counts can be 3-4 digits; keep it inside the 18px icon
    icon.count:Show()
  else
    icon.count:Hide()
  end
end

-- Post-hook on the commission cell's Populate: hide Blizzard's chest and lay our reward icons out
-- to the left of the money display (where the chest sat), reward 1 leftmost.
---@param cell table
---@param rowData table
function ns.PopulateRewardIcons(cell, rowData)
  cell.RewardIcon:Hide() -- always suppress the native chest; we render its contents instead

  cell.soiRewardIcons = cell.soiRewardIcons or {}
  local pool = cell.soiRewardIcons

  local order = rowData and rowData.option
  local rewards = order and order.npcOrderRewards
  local count = rewards and #rewards or 0

  -- Anchor the rightmost reward at a FIXED x (the money's right edge minus the reserved money
  -- zone) and walk leftward, so reward 1 ends up on the left. Pinning to the money's right edge
  -- (not its ragged left edge, which shifts with the amount's digit count) keeps the reward
  -- column aligned across rows.
  local prev
  for i = count, 1, -1 do
    local icon = acquireIcon(cell, i)
    fillIcon(icon, rewards[i])
    icon:ClearAllPoints()
    if i == count then
      icon:SetPoint("RIGHT", cell.TipMoneyDisplayFrame, "RIGHT", -ns.tuning.moneyReserve, 0)
    else
      icon:SetPoint("RIGHT", prev, "LEFT", -ns.tuning.iconGap, 0)
    end
    icon:Show()
    prev = icon
  end
  for i = count + 1, #pool do pool[i]:Hide() end
end
