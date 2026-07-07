---@type ShadowsOfUI_PostOffice
local ns = select(2, ...)

-- Forward: a "Forward" button on an open letter that re-sends its body text and
-- item attachments to another player. Attachments can't move straight from a letter
-- into a new one, so we shuttle them one at a time: take an attachment into a bag,
-- wait for the bag update, then split exactly the taken amount back out and attach it
-- to the outgoing mail. Repeat until the letter is empty.
--
-- Locating the taken item by (itemID, count) — rather than by which bag slot newly
-- filled — makes this work for stackables too: when the taken stack merges into an
-- existing one we simply split our amount back off. A mail attachment never exceeds
-- the item's max stack, so after taking there is always a slot holding >= that count.
local ATTACH_MAX = ATTACHMENTS_MAX_SEND

local button ---@type Button?
local pending ---@type { id: number, count: number }?  the attachment currently in flight

-- First bag slot holding at least `count` of `itemID`; returns bag, slot, stackCount.
local function locate(itemID, count)
  for b = 0, 4 do
    for s = 1, C_Container.GetContainerNumSlots(b) do
      local info = C_Container.GetContainerItemInfo(b, s)
      if info and info.itemID == itemID and (info.stackCount or 1) >= count then
        return b, s, info.stackCount or 1
      end
    end
  end
end

local function freeBagSlots()
  local n = 0
  for b = 0, 4 do n = n + C_Container.GetContainerNumFreeSlots(b) end
  return n
end

local takeNext -- forward declaration

local function firstFreeSendSlot()
  for i = 1, ATTACH_MAX do
    if not HasSendMailItem(i) then return i end
  end
  return 1
end

local function findEmptyBagSlot()
  for b = 0, 4 do
    for s = 1, C_Container.GetContainerNumSlots(b) do
      if not C_Container.GetContainerItemInfo(b, s) then return b, s end
    end
  end
end

-- Attach a WHOLE cursor stack to the outgoing mail, then continue. Emptying a letter
-- flips the mailbox back to the Inbox tab, so re-assert the Send Mail tab first.
local function depositWholeAndContinue()
  MailFrameTab_OnClick(nil, 2)
  ClickSendMailItemButton(firstFreeSendSlot())
  takeNext()
end

-- Step 3: our exact amount now sits alone in a bag slot. Pick it up whole (synchronous)
-- and attach — the whole-stack path is the one that reliably deposits into mail.
local isolated ---@type { b: number, s: number }?
local function onIsolated()
  local t = isolated
  local info = t and C_Container.GetContainerItemInfo(t.b, t.s)
  if not info then return end -- deposit hasn't committed yet; wait for the next update
  ns:unregisterEvent("BAG_UPDATE_DELAYED", onIsolated)
  isolated = nil
  C_Container.PickupContainerItem(t.b, t.s)
  depositWholeAndContinue()
end

-- Step 2: SplitContainerItem is async and a split held on the cursor never fires a bag
-- update — CURSOR_CHANGED is the signal that the split actually landed on the cursor.
-- Park it in the reserved empty slot to commit it as a real stack.
local parking ---@type { b: number, s: number }?
local function onCursorChanged()
  if not parking or not CursorHasItem() then return end
  ns:unregisterEvent("CURSOR_CHANGED", onCursorChanged)
  local t = parking
  parking = nil
  isolated = { b = t.b, s = t.s }
  ns:registerEvent("BAG_UPDATE_DELAYED", onIsolated)
  C_Container.PickupContainerItem(t.b, t.s) -- cursor → empty slot (deposit)
end

local function onBagUpdate()
  ns:unregisterEvent("BAG_UPDATE_DELAYED", onBagUpdate)
  local p = pending
  pending = nil
  if not p then takeNext(); return end
  local b, s, stack = locate(p.id, p.count)
  if not b then takeNext(); return end
  if stack == p.count then
    -- Already a whole slot of exactly our amount: pick up and attach.
    C_Container.PickupContainerItem(b, s)
    depositWholeAndContinue()
  else
    -- Merged into a bigger stack: isolate our amount via an empty bag slot —
    -- split (async) → CURSOR_CHANGED → park in the empty slot → BAG_UPDATE_DELAYED →
    -- pick up the isolated stack whole → attach.
    local eb, es = findEmptyBagSlot()
    if not eb then takeNext(); return end -- no room to isolate (bag-space gated upstream)
    parking = { b = eb, s = es }
    ns:registerEvent("CURSOR_CHANGED", onCursorChanged)
    C_Container.SplitContainerItem(b, s, p.count)
  end
end

-- Take the next remaining attachment; onBagUpdate splits + attaches it, then recurses.
function takeNext()
  local mailID = InboxFrame.openMailID
  for i = 1, ATTACH_MAX do
    local _, itemID, _, count = GetInboxItem(mailID, i)
    if itemID then
      pending = { id = itemID, count = count or 1 }
      ns:registerEvent("BAG_UPDATE_DELAYED", onBagUpdate)
      TakeInboxItem(mailID, i)
      return
    end
  end
end

local function doForward()
  if not ns.db.forward then return end
  local mailID = InboxFrame.openMailID
  if not mailID then return end
  MailFrameTab_OnClick(nil, 2) -- switch to the Send Mail tab
  SendMailNameEditBox:SetText("")
  local subject = OpenMailSubject:GetText() or ""
  if subject:sub(1, 4) ~= "FW: " then subject = "FW: " .. subject end
  SendMailSubjectEditBox:SetText(subject)
  local body = GetInboxText(mailID)
  if body then SendMailBodyEditBox:SetText(body) end
  SendMailNameEditBox:SetFocus()
  takeNext()
end

-- Refresh the button for the open letter. Money/COD can't be forwarded, and the
-- attachments must fit in bags (worst case one free slot each), so disable otherwise.
local function refresh()
  if not button then return end
  if not ns.db.forward then button:Hide(); return end
  button:Show()
  local mailID = InboxFrame.openMailID
  if not mailID then button:Disable(); return end
  button:Enable()
  local money, cod, _, itemCount = select(5, GetInboxHeaderInfo(mailID))
  itemCount = itemCount or 0
  if (money and money > 0) or (cod and cod > 0) or freeBagSlots() < itemCount then
    button:Disable()
  end
end

-- OpenMailFrame only exists after Blizzard_MailFrame loads (first mailbox open).
local function ensureButton()
  if button then return end
  button = CreateFrame("Button", nil, OpenMailFrame, "UIPanelButtonTemplate")
  button:SetSize(82, 22)
  button:SetPoint("RIGHT", OpenMailReplyButton, "LEFT", 0, 0)
  button:SetText("Forward")
  button:SetScript("OnClick", doForward)
end

ns.OnMailShow(function()
  if OpenMailFrame then ensureButton() end
end)
ns.OnOpenMailUpdate(refresh)
