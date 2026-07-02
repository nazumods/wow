---@type ShadowsOfUI_Collectibles
local ns = select(2, ...)

local function db(key) return ns.db and ns.db[key] end

-- The tint for an item link, or nil for "leave it alone": the known-item colour
-- (with optional desaturation) if owned/learned, else the green collectible tint
-- when enabled and the item is still collectible.
---@return number? r, number? g, number? b, boolean? desaturate
local function tintFor(link)
  if not link then return nil end
  if ns.IsKnown(link) then
    local r, g, b = ns.KnownColor()
    return r, g, b, db("monochrome")
  elseif db("markUncollected") and ns.IsCollectible(link) then
    local c = ns.UncollectedColor
    return c[1], c[2], c[3], false
  end
end

-- Merchant ───────────────────────────────────────────────────────────────────

local function updateMerchant()
  local on = db("merchant")
  for i = 1, MERCHANT_ITEMS_PER_PAGE do
    local itemButton = _G["MerchantItem" .. i .. "ItemButton"]
    local merchantButton = _G["MerchantItem" .. i]
    if itemButton and merchantButton then
      local index = (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE + i
      local link = on and GetMerchantItemLink(index)
      local r, g, b, desat
      if link then r, g, b, desat = tintFor(link) end
      -- Only paint when we have a tint. This hook runs AFTER
      -- MerchantFrame_UpdateMerchantInfo, which repaints every button from
      -- scratch, so leaving untinted buttons alone preserves Blizzard's own cues
      -- (red = unusable, grey = can't afford, heirloom desaturation) instead of
      -- stomping them all to white.
      if r then
        SetItemButtonNameFrameVertexColor(merchantButton, r, g, b)
        SetItemButtonSlotVertexColor(merchantButton, r, g, b)
        SetItemButtonTextureVertexColor(itemButton, 0.9 * r, 0.9 * g, 0.9 * b)
        SetItemButtonNormalTextureVertexColor(itemButton, 0.9 * r, 0.9 * g, 0.9 * b)
        SetItemButtonDesaturated(itemButton, desat)
      end
    end
  end
end

hooksecurefunc("MerchantFrame_UpdateMerchantInfo", updateMerchant)
ns.AddRefresher(function()
  if MerchantFrame and MerchantFrame:IsShown() then updateMerchant() end
end)

-- Auction House browse list ────────────────────────────────────────────────────

EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI", function()
  local scrollBox = AuctionHouseFrame.BrowseResultsFrame.ItemList.ScrollBox

  local function updateAH()
    local on = db("auctionHouse")
    for _, button in ipairs({ scrollBox.ScrollTarget:GetChildren() }) do
      local key = button.rowData and button.rowData.itemKey
      local cell = button.cells and button.cells[2]
      if key and key.itemID and cell and cell.Icon then
        local link
        if on then
          link = key.itemID == 82800
            and ("|Hbattlepet:%d::::::|h[Dummy]|h"):format(key.battlePetSpeciesID)
            or ("item:%d"):format(key.itemID)
        end
        local r, g, b, desat
        if link then r, g, b, desat = tintFor(link) end
        if r then
          button.SelectedHighlight:Show()
          button.SelectedHighlight:SetVertexColor(r, g, b)
          button.SelectedHighlight:SetAlpha(0.2)
        else
          r, g, b, desat = 1, 1, 1, false
          button.SelectedHighlight:SetVertexColor(1, 1, 1)
          button.SelectedHighlight:Hide()  -- else a toggled-off row keeps a white ADD-blend glow until the next scroll
        end
        cell.Icon:SetVertexColor(r, g, b)
        if cell.IconBorder then cell.IconBorder:SetVertexColor(r, g, b) end
        cell.Icon:SetDesaturated(desat)
      end
    end
  end

  hooksecurefunc(scrollBox, "Update", updateAH)
  ns.AddRefresher(function() if AuctionHouseFrame:IsShown() then updateAH() end end)
end)

-- Guild bank: not supported yet. The 12.0 guild bank rework left GuildBankFrame's
-- Columns/Buttons as a hidden data-only structure (their icons report IsShown but
-- IsVisible=false), so tinting them paints nothing. Revisit once the new visible
-- guild-bank frame is identified.

-- Decor owned-state isn't available from the API immediately after login; kicking
-- off a catalog search primes it (fires HOUSING_STORAGE_UPDATED once ready).
function ns:onLogin()
  if C_HousingCatalog and C_HousingCatalog.CreateCatalogSearcher then
    C_HousingCatalog.CreateCatalogSearcher()
  end
end
