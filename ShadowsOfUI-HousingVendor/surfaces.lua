---@type ShadowsOfUI_HousingVendor
local ns = select(2, ...)

local CleanOverlay = ns.CleanOverlay
local ApplyOverlay = ns.ApplyOverlay

-- Merchant "Buy" tab. Only MerchantFrame_UpdateMerchantInfo is hooked; the Buyback
-- tab isn't decorated (decor is bought, not bought-back).
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

-- Runs after MerchantFrame_UpdateMerchantInfo repaints every button from scratch.
hooksecurefunc("MerchantFrame_UpdateMerchantInfo", updateMerchant)
ns.AddRefresher(function()
  if MerchantFrame and MerchantFrame:IsShown() then updateMerchant() end
end)
