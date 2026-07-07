---@type ShadowsOfUI_PostOffice
local ns = select(2, ...)

-- Express: modifier-click shortcuts at the mailbox.
--   • Ctrl-click an inbox letter  → return it to sender (if returnable).
--   • Alt-click a bag item        → attach it to the open letter (optionally send).
-- Shift-click-to-loot is left to the native handler (Blizzard auto-loots on the
-- MAILAUTOLOOTTOGGLE modifier now), so we only add what isn't already there.
local HINT = "|cffeda55f%s|r %s" -- gold-highlighted key + description

--------------------------------------------------------------------------------
-- Inbox: ctrl-click to return
--
-- The inbox row's OnClick routes a MAILAUTOLOOTTOGGLE (shift) click to the native
-- auto-loot path and everything else to InboxFrame_OnClick. We wrap that global so
-- a plain ctrl-click returns the letter instead of opening it. Mail frames are not
-- protected, so replacing the handler is taint-safe.
--------------------------------------------------------------------------------
local origInboxOnClick

local function inboxOnClick(button, index)
  if ns.db.express and IsControlKeyDown() and not IsShiftKeyDown() and not IsAltKeyDown() then
    local wasReturned, _, canReply = select(10, GetInboxHeaderInfo(index))
    if not wasReturned and canReply then
      ReturnInboxItem(index)
      button:SetChecked(false)
      InboxFrame.openMailID = 0
      InboxFrame_Update()
      return
    end
  end
  return origInboxOnClick(button, index)
end

--------------------------------------------------------------------------------
-- Bags: alt-click to attach to the open letter
--
-- HandleModifiedItemClick fires for every modified bag-item click with the item's
-- link + location. Alt isn't a native modified-click action, so a posthook lets us
-- attach the item to a visible Send-Mail letter (and optionally fire it off).
--------------------------------------------------------------------------------
local function onBagItemClick(_, itemLocation)
  if not ns.db.express or itemLocation == nil then return end -- itemLocation nil = not a bag click
  if not (SendMailFrame and SendMailFrame:IsVisible()) or CursorHasItem() then return end
  if not IsAltKeyDown() or GetMouseButtonClicked() ~= "LeftButton" then return end
  local bag, slot = itemLocation.bagID, itemLocation.slotIndex
  if not bag then return end
  C_Container.PickupContainerItem(bag, slot)
  ClickSendMailItemButton()
  if ns.db.expressAutoSend and SendMailNameEditBox:GetText() ~= "" then
    SendMailFrame_SendMail()
  end
end

--------------------------------------------------------------------------------
-- Tooltip hints
--------------------------------------------------------------------------------
local function onInboxItemEnter(this)
  if not ns.db.express or not this.index then return end
  local wasReturned, _, canReply = select(10, GetInboxHeaderInfo(this.index))
  if not wasReturned and canReply then
    GameTooltip:AddLine(HINT:format("Ctrl-Click", "to return it to sender."))
    GameTooltip:Show()
  end
end

-- Fires for any item tooltip; the guards keep the hint to items you can actually
-- alt-click onto a letter you're composing.
ns:OnItemTooltip(function(tooltip)
  if not ns.db.express then return end
  if not (SendMailFrame and SendMailFrame:IsVisible()) or CursorHasItem() then return end
  local recipient = SendMailNameEditBox:GetText()
  if recipient ~= "" then
    tooltip:AddLine(HINT:format("Alt-Click", ("to send to %s."):format(recipient)))
  end
end)

--------------------------------------------------------------------------------
-- Install the mail-frame hooks lazily: those globals only exist once
-- Blizzard_MailFrame has loaded (first mailbox open).
--------------------------------------------------------------------------------
local installed = false
ns.OnMailShow(function()
  if installed or not InboxFrame_OnClick then return end
  installed = true
  origInboxOnClick = InboxFrame_OnClick
  InboxFrame_OnClick = inboxOnClick
  hooksecurefunc("InboxFrameItem_OnEnter", onInboxItemEnter)
  hooksecurefunc("HandleModifiedItemClick", onBagItemClick)
end)
