---@type ShadowsOfUI_HousingVendor
local ns = select(2, ...)

local function db(key) return ns.db and ns.db[key] end

local NUMBER_FONT = "Fonts\\ARIALN.TTF"
local STAR_ATLAS = "auctionhouse-icon-favorite"           -- gold star (AH/profession favourite)
local CHECK_TEX = "Interface\\RaidFrame\\ReadyCheck-Ready" -- green check

-- Overlay layer for a merchant item button: a frame one level above the icon with
-- three indicators, each in a corner clear of Blizzard's own stack-count number
-- (which sits bottom-right). Built lazily and reused across page/tab changes.
local function ensureOverlay(button)
  if button.shvOverlay then return button.shvOverlay end
  local o = CreateFrame("Frame", nil, button)
  o:SetAllPoints()
  o:SetFrameLevel(button:GetFrameLevel() + 1)

  local count = o:CreateFontString(nil, "OVERLAY")
  count:SetFont(NUMBER_FONT, 12, "OUTLINE")
  count:SetPoint("BOTTOMLEFT", 4, 4)
  o.count = count

  -- Star (unowned + bonus) and check (owned) are mutually exclusive, so they share
  -- the top-left corner. Top-right is left free for other addons' unowned markers.
  local star = o:CreateTexture(nil, "OVERLAY")
  star:SetAtlas(STAR_ATLAS)
  star:SetSize(14, 14)
  star:SetPoint("TOPLEFT", 1, -1)
  o.star = star

  local check = o:CreateTexture(nil, "OVERLAY")
  check:SetTexture(CHECK_TEX)
  check:SetSize(14, 14)
  check:SetPoint("TOPLEFT", 1, -1)
  o.check = check

  button.shvOverlay = o
  return o
end

local function cleanButton(button)
  local o = button.shvOverlay
  if o then o.count:Hide(); o.star:Hide(); o.check:Hide() end
end

-- Paint a button's overlay from normalized decor info, honouring the per-indicator
-- toggles. Callers cleanButton() first, so a disabled indicator leaves nothing.
local function applyOverlay(button, d)
  local o = ensureOverlay(button)
  if db("countBadge") and d.owned then
    o.count:SetText(d.stored)
    -- Owned but nothing on hand (all placed): dim the 0 so it reads as "none to place".
    if d.stored > 0 then o.count:SetTextColor(1, 1, 1) else o.count:SetTextColor(0.6, 0.6, 0.6) end
    o.count:Show()
  end
  if db("ownedCheck") and d.owned then o.check:Show() end
  if db("bonusBadge") and d.bonusAvailable then o.star:Show() end
end

local function updateMerchant()
  for i = 1, MERCHANT_ITEMS_PER_PAGE do
    local itemButton = _G["MerchantItem" .. i .. "ItemButton"]
    if itemButton then
      cleanButton(itemButton)
      local index = (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE + i
      local link = GetMerchantItemLink(index)
      local d = link and ns.DecorEntryFor(link)
      if d then applyOverlay(itemButton, d) end
    end
  end
end

-- Runs after MerchantFrame_UpdateMerchantInfo repaints every button from scratch.
hooksecurefunc("MerchantFrame_UpdateMerchantInfo", updateMerchant)
ns.AddRefresher(function()
  if MerchantFrame and MerchantFrame:IsShown() then updateMerchant() end
end)

-- Buying/placing/redeeming decor changes the owned counts: drop the cache so the
-- next paint re-queries the catalog, then repaint the open merchant.
ns:registerEvent("HOUSING_STORAGE_UPDATED", function()
  ns.WipeDecorCache()
  if MerchantFrame and MerchantFrame:IsShown() then updateMerchant() end
end)
