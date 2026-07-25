---@type ShadowsOfUI_ProfCommissions
local ns = select(2, ...)

---@class ShadowsOfUI_ProfCommissions
---@field PopulateRewardIcons fun(cell: table, rowData: table)
---@field DumpRewards fun()

local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetItemQualityByID = C_Item.GetItemQualityByID
local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
local QUALITY_COLORS = ITEM_QUALITY_COLORS

local GLOW_COLOR = { r = 1, g = 0.82, b = 0 } -- WoW gold
local GLOW_PAD = 4 -- px the glow spreads past the icon on each side

-- On the crafter's "Crafting Orders" browse list, Patron (NPC) orders carry bonus item/currency
-- rewards on top of the gold commission. Blizzard renders these as a single generic treasure-chest
-- icon in the Commission cell (ProfessionsCrafterTableCellCommissionMixin) whose contents only show
-- on hover. We replace that chest with the actual reward icons in the same spot — each still hoverable
-- for the full item/currency tooltip, so you can see *what* the reward is at a glance without opening
-- every order.

-- Every distinct reward the list has drawn this session, keyed by link/currency id, so
-- /sprofcomm rewards can report how each one's quality resolved.
local seen = {}

-- Rarity is decided purely by quality, for items and currency alike: GetCurrencyInfo reports a real
-- item-quality value (it's what Blizzard's own reward tooltip colours currency names with), so one
-- threshold covers both kinds. Epic is the floor because every Patron order pays the profession's
-- Moxie currency at Rare — glowing on Rare would glow every row and mean nothing.
local function isRare(quality)
  return quality ~= nil and quality >= ns.tuning.glowQuality
end

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

  -- Gold "rare reward" glow: Blizzard's own new-item glow art, spreading GLOW_PAD past the icon on
  -- every side. It sits on BACKGROUND, *behind* the icon: bags-glow-white is a filled square, not a
  -- ring, so drawn on top it washes an 18px icon into an unreadable gold block — behind, the opaque
  -- icon masks the middle and only the soft falloff shows, which is the halo we actually want.
  -- Starts hidden so an ordinary reward can never leak a first paint before its quality resolves.
  icon.glow = icon:CreateTexture(nil, "BACKGROUND")
  icon.glow:SetAtlas("bags-glow-white")
  icon.glow:SetBlendMode("ADD")
  icon.glow:SetVertexColor(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b)
  icon.glow:SetPoint("TOPLEFT", -GLOW_PAD, GLOW_PAD)
  icon.glow:SetPoint("BOTTOMRIGHT", GLOW_PAD, -GLOW_PAD)
  icon.glow:Hide()

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

-- Paint everything an icon derives from its quality. The border stays item-rewards-only (currency
-- rewards report a quality too, but must not get one); the glow applies to both kinds.
local function applyQuality(icon, quality, isItem)
  local color = isItem and quality and quality > Enum.ItemQuality.Common and QUALITY_COLORS[quality]
  if color then
    icon.border:SetVertexColor(color.r, color.g, color.b)
    icon.border:Show()
  else
    icon.border:Hide()
  end

  icon.glow:SetShown(isRare(quality))
end

-- Item quality is cache-backed, so a reward item this client has never seen resolves to nil and
-- would silently render with neither border nor glow. Ask the server for it and re-decorate when it
-- lands, re-checking the link first: rows recycle their icons while the request is in flight.
local function requestQuality(icon, itemLink)
  Item:CreateFromItemLink(itemLink):ContinueOnItemLoad(function()
    if icon.itemLink ~= itemLink then return end
    applyQuality(icon, GetItemQualityByID(itemLink), true)
  end)
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
    quality = GetItemQualityByID(reward.itemLink)
    if quality == nil then requestQuality(icon, reward.itemLink) end
  elseif reward.currencyType then
    icon.currencyType = reward.currencyType
    local info = GetCurrencyInfo(reward.currencyType)
    texture = info and info.iconFileID
    quality = info and info.quality
  end

  icon.tex:SetTexture(texture or 134400) -- INV_Misc_QuestionMark fallback
  applyQuality(icon, quality, reward.itemLink ~= nil)

  local key = reward.itemLink or reward.currencyType
  if key then seen[key] = reward end

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

-- /sprofcomm rewards — how every reward drawn this session resolved. Quality is what the glow keys
-- off, so this is the check for whether the criteria actually catches the rare rewards on a live
-- order (and for spotting one whose quality never resolved).
function ns.DumpRewards()
  local rows = {}
  for _, reward in pairs(seen) do
    local kind, label, quality
    if reward.itemLink then
      kind = "item"
      label = C_Item.GetItemInfo(reward.itemLink) or reward.itemLink
      quality = GetItemQualityByID(reward.itemLink)
    else
      kind = "currency"
      local info = GetCurrencyInfo(reward.currencyType)
      label = info and info.name or ("#" .. reward.currencyType)
      quality = info and info.quality
    end
    rows[#rows + 1] = ("  [%s] %s - quality %s%s"):format(
      kind, label, quality or "unresolved", isRare(quality) and "  <-- glows" or "")
  end

  if #rows == 0 then
    ns.Print("No rewards drawn yet - open the Crafting Orders list on a Patron tab first.")
    return
  end
  table.sort(rows)
  ns.Print(("%d reward(s) seen this session; glow threshold is quality %d+."):format(
    #rows, ns.tuning.glowQuality))
  for _, row in ipairs(rows) do ns.Print(row) end
end
