---@type ShadowsOfUI_HousingVendor
local ns = select(2, ...)

local CleanOverlay = ns.CleanOverlay
local ApplyOverlay = ns.ApplyOverlay

-- Merchant "Buy" tab: decor is bought, not bought-back, so only the Buy tab is decorated.
local function updateMerchant()
  for i = 1, MERCHANT_ITEMS_PER_PAGE do
    local itemButton = _G["MerchantItem" .. i .. "ItemButton"]
    if itemButton then
      CleanOverlay(itemButton)
      local index = (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE + i
      local link = GetMerchantItemLink(index)
      local d = link and ns.DecorEntryFor(link)
      if d then ApplyOverlay(itemButton, d) end
    end
  end
end

-- The Buyback tab reuses the very same MerchantItemNItemButton frames (see Blizzard's
-- MerchantFrame_UpdateBuybackInfo), so a decor overlay left from the Buy tab would ride a
-- bought-back row. Strip every indicator whenever that tab repaints.
local function clearMerchantOverlays()
  for i = 1, MERCHANT_ITEMS_PER_PAGE do
    local itemButton = _G["MerchantItem" .. i .. "ItemButton"]
    if itemButton then CleanOverlay(itemButton) end
  end
end

-- These run after Blizzard repaints every button from scratch: UpdateMerchantInfo on the
-- Buy tab, UpdateBuybackInfo on the Buyback tab.
hooksecurefunc("MerchantFrame_UpdateMerchantInfo", updateMerchant)
hooksecurefunc("MerchantFrame_UpdateBuybackInfo", clearMerchantOverlays)
ns.AddRefresher(function()
  -- Buy tab only: the reused item buttons may currently be showing the Buyback tab, where
  -- Buy overlays don't belong (and MerchantFrame_UpdateBuybackInfo already stripped them).
  if MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1 then
    updateMerchant()
  end
end)
