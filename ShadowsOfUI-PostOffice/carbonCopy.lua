---@type ShadowsOfUI_PostOffice
local ns = select(2, ...)

-- CarbonCopy: a small button on an open letter that copies its text — and, for
-- auction-house invoices, the sale/purchase breakdown — into LibNUI's shared copy
-- window (WoW has no clipboard API, so a selectable window is how you "copy").
local FADE_TEXTURE = 135994

local button ---@type Button?

-- Auction invoice detail lines (sold/bought breakdown), or nil for a plain letter.
local function invoiceLines(mailID)
  local kind, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo(mailID)
  if not playerName then return end
  local won = bid == buyout and BUYOUT or HIGH_BIDDER
  if kind == "buyer" then
    return {
      ITEM_PURCHASED_COLON .. " " .. itemName .. " (" .. won .. ")",
      SOLD_BY_COLON .. " " .. playerName,
      AMOUNT_PAID_COLON .. " " .. ns.PlainCoins(bid),
    }
  elseif kind == "seller" then
    return {
      ITEM_SOLD_COLON .. " " .. itemName,
      PURCHASED_BY_COLON .. " " .. playerName .. " (" .. won .. ")",
      SALE_PRICE_COLON .. " " .. ns.PlainCoins(bid),
      DEPOSIT_COLON .. " " .. ns.PlainCoins(deposit),
      AUCTION_HOUSE_CUT_COLON .. " " .. ns.PlainCoins(consignment),
      AMOUNT_RECEIVED_COLON .. " " .. ns.PlainCoins(bid + deposit - consignment),
    }
  end
end

local function copyMail()
  local mailID = InboxFrame.openMailID
  if not mailID then return end
  local _, _, sender, subject = GetInboxHeaderInfo(mailID)
  -- isInvoice is the 5th return of GetInboxText (Blizzard MailFrame.lua) — note
  -- Postal's CarbonCopy reads it from the 4th, which is a latent bug there.
  local body, _, _, _, isInvoice = GetInboxText(mailID)
  local lines = {
    FROM .. " " .. (sender or UNKNOWN),
    MAIL_SUBJECT_LABEL .. " " .. (subject or ""),
    "",
    body or "",
  }
  if isInvoice then
    local inv = invoiceLines(mailID)
    if inv then
      lines[#lines + 1] = ""
      for _, l in ipairs(inv) do lines[#lines + 1] = l end
    end
  end
  ns.ui.ShowCopyWindow((subject ~= "" and subject) or "Mail", table.concat(lines, "\n"))
end

-- Small button that grows on hover; created lazily on OpenMailScrollFrame.
local function ensureButton()
  if button then return end
  button = CreateFrame("Button", nil, OpenMailScrollFrame)
  button:SetPoint("TOPRIGHT", OpenMailScrollFrame, "TOPRIGHT", 0, 0)
  button:SetSize(10, 10)
  button:SetNormalTexture(FADE_TEXTURE)
  button:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]])
  button:SetScript("OnClick", copyMail)
  button:SetScript("OnEnter", function(self)
    self:SetSize(28, 28)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Copy this letter")
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function(self)
    self:SetSize(10, 10)
    GameTooltip:Hide()
  end)
end

-- Show the button only when there's something to copy (body text or an invoice).
local function refresh()
  local mailID = InboxFrame.openMailID
  if not ns.db.carbonCopy or not mailID then
    if button then button:Hide() end
    return
  end
  local body, _, _, _, isInvoice = GetInboxText(mailID)
  if isInvoice or (body and #body > 0) then
    ensureButton()
    button:Show()
  elseif button then
    button:Hide()
  end
end

ns.OnOpenMailUpdate(refresh)
