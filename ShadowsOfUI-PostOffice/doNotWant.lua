---@type ShadowsOfUI_PostOffice
local ns = select(2, ...)

-- DoNotWant: a small icon on each inbox letter showing what it will do on expiry —
-- returned to sender (has a sender) or deleted (no sender, e.g. auction/system mail).
-- Click the icon to do that now. Deletions that would destroy items or coin confirm
-- first. The first consumer of core's shared inbox-row decorator (ns.OnInboxRow).

local pending ---@type number?     mail index awaiting a delete-confirm accept
local pendingMoney ---@type number? coin on that letter, for the money-confirm frame

local function deletePending()
  if pending then DeleteInboxItem(pending); pending = nil end
end

StaticPopupDialogs["SHADOWSOFUI_POSTOFFICE_DELETE_MAIL"] = {
  text = DELETE_MAIL_CONFIRMATION,
  button1 = ACCEPT, button2 = CANCEL,
  OnAccept = deletePending,
  showAlert = 1, timeout = 0, hideOnEscape = 1,
}
StaticPopupDialogs["SHADOWSOFUI_POSTOFFICE_DELETE_MONEY"] = {
  text = DELETE_MONEY_CONFIRMATION,
  button1 = ACCEPT, button2 = CANCEL,
  OnAccept = deletePending,
  OnShow = function(self) MoneyFrame_Update(self.moneyFrame, pendingMoney or 0) end,
  hasMoneyFrame = 1, showAlert = 1, timeout = 0, hideOnEscape = 1,
}

local function onClick(self)
  local index = self.index
  if not index then return end
  if not InboxItemCanDelete(index) then
    ReturnInboxItem(index) -- returnable (has a sender) → send it back
    return
  end
  local money = select(5, GetInboxHeaderInfo(index))
  local firstItem
  for i = 1, ATTACHMENTS_MAX_RECEIVE do
    local name = GetInboxItem(index, i)
    if name then firstItem = name; break end
  end
  if firstItem then
    pending = index
    StaticPopup_Show("SHADOWSOFUI_POSTOFFICE_DELETE_MAIL", firstItem)
  elseif money and money > 0 then
    pending, pendingMoney = index, money
    StaticPopup_Show("SHADOWSOFUI_POSTOFFICE_DELETE_MONEY")
  else
    DeleteInboxItem(index) -- empty letter, nothing to lose
  end
end

-- One icon per row, created lazily on the row's expire-time frame (so it follows
-- whatever inbox-row layout is active — e.g. when Select indents the rows).
local icons = {}
local function ensureIcon(row)
  local b = icons[row.i]
  if b then return b end
  b = CreateFrame("Button", nil, row.expire)
  b:SetPoint("TOPRIGHT", row.expire, "BOTTOMRIGHT", -5, -1)
  b:SetSize(16, 16)
  b.tex = b:CreateTexture(nil, "BACKGROUND")
  b.tex:SetAllPoints()
  b.tex:SetTexCoord(1, 0, 0, 1) -- mirror so the return arrow points the right way
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.tooltip or "")
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  icons[row.i] = b
  return b
end

ns.OnInboxRow(function(row)
  local b = icons[row.i]
  if not ns.db.doNotWant or not row.present then
    if b then b:Hide() end
    return
  end
  b = ensureIcon(row)
  local canDelete = InboxItemCanDelete(row.index)
  b.index = row.index
  b.tex:SetTexture(canDelete and [[Interface\RaidFrame\ReadyCheck-NotReady]] or [[Interface\ChatFrame\ChatFrameExpandArrow]])
  b.tooltip = canDelete and DELETE or MAIL_RETURN
  b:Show()
end)

ns.OnSettingChanged("doNotWant", ns.RefreshInbox)
