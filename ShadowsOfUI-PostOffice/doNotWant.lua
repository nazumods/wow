---@type ShadowsOfUI_PostOffice
local ns = select(2, ...)

-- DoNotWant: a small icon on each inbox letter showing what it will do on expiry —
-- returned to sender (has a sender) or deleted (no sender, e.g. auction/system mail).
-- Click the icon to do that now. Deletions that would destroy items or coin confirm
-- first. The first consumer of core's shared inbox-row decorator (ns.OnInboxRow).

local MAIL_POPUP = "SHADOWSOFUI_POSTOFFICE_DELETE_MAIL"
local MONEY_POPUP = "SHADOWSOFUI_POSTOFFICE_DELETE_MONEY"

-- The letter a confirm dialog was opened for, carried as that dialog's own StaticPopup
-- payload rather than in module state — see the comment on the dialog tables below.
---@class PostOfficeDeletePending
---@field sig string fingerprint of the letter, captured when the confirm opened
---@field index number inbox index of that letter, captured at click time
---@field money number? coin on that letter, for the money-confirm frame

-- A letter's stable identity for the window a confirm dialog sits open — nothing is taken
-- from it in that span, so sender/subject/money/CoD/attachment-count all hold. It deliberately
-- omits daysLeft (position 7), which ticks down during the confirm window; the trade-off is that
-- two distinct letters (e.g. two "Auction expired" mails for the same item at different counts)
-- can share a fingerprint, so the fingerprint alone can't single out the clicked letter — the
-- captured index disambiguates that in ResolveDeleteIndex.
---@param index number inbox index
---@return string fingerprint
function ns.InboxFingerprint(index)
  local _, _, sender, subject, money, cod, _, hasItem = GetInboxHeaderInfo(index)
  return table.concat({ sender or "", subject or "", money or 0, cod or 0, hasItem or 0 }, "\1")
end

-- Pick which inbox letter a confirmed delete should remove. The index captured at click time is
-- authoritative *while it still holds the clicked letter* (its fingerprint still matches) — this
-- deletes exactly that letter even when another carries an identical fingerprint. Only when mail
-- arriving during the confirm has shifted every index up does the captured index stop matching;
-- then fall back to the first fingerprint match, and delete nothing if the letter is simply gone
-- (never a different, shifted-in letter).
---@param sig string fingerprint captured when the confirm opened
---@param index number? inbox index captured at click time
---@param numItems number current GetInboxNumItems()
---@param fingerprintAt fun(i: number): string fingerprint of the letter at inbox index i
---@return number? index to delete, or nil when the letter is no longer present
function ns.ResolveDeleteIndex(sig, index, numItems, fingerprintAt)
  if index and index <= numItems and fingerprintAt(index) == sig then return index end
  for i = 1, numItems do
    if fingerprintAt(i) == sig then return i end
  end
end

---@param pending PostOfficeDeletePending the letter this dialog was opened for
local function deletePending(_, pending)
  local target = ns.ResolveDeleteIndex(pending.sig, pending.index, GetInboxNumItems(), ns.InboxFingerprint)
  if target then DeleteInboxItem(target) end
end

-- The two confirms are distinct dialogs, so they occupy separate StaticPopup frames and can sit
-- open at once. Each therefore carries its own letter as its StaticPopup payload (Blizzard hands
-- it back to OnAccept/OnShow) — module-level pending state would make whichever dialog is answered
-- act on whatever was clicked most recently, destroying the wrong letter. `cancels` closes the
-- sibling on top of that, so at most one of ours is ever on screen.
StaticPopupDialogs[MAIL_POPUP] = {
  text = DELETE_MAIL_CONFIRMATION,
  button1 = ACCEPT, button2 = CANCEL,
  OnAccept = deletePending,
  cancels = MONEY_POPUP,
  showAlert = 1, timeout = 0, hideOnEscape = 1,
}
StaticPopupDialogs[MONEY_POPUP] = {
  text = DELETE_MONEY_CONFIRMATION,
  button1 = ACCEPT, button2 = CANCEL,
  OnAccept = deletePending,
  OnShow = function(self, pending) MoneyFrame_Update(self.moneyFrame, pending.money) end,
  cancels = MAIL_POPUP,
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
    StaticPopup_Show(MAIL_POPUP, firstItem, nil, { sig = ns.InboxFingerprint(index), index = index })
  elseif money and money > 0 then
    StaticPopup_Show(MONEY_POPUP, nil, nil, { sig = ns.InboxFingerprint(index), index = index, money = money })
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
