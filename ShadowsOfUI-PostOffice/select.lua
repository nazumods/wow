---@type ShadowsOfUI_PostOffice
local ns = select(2, ...)

-- Select: a checkbox on each inbox row plus Open / Return buttons, so you can batch
-- open (take all attachments + coin) or return the letters you tick. Owns the inbox
-- row re-layout that makes room for the checkboxes; DoNotWant's icons ride along
-- because they anchor to the (moved) expire-time frame. Batch processing is a throttled
-- state machine — taking mail is async, so we work one action per tick, highest index
-- first (so a letter auto-deleting when emptied never shifts an index we still need).
local ROWS = 7
local checked = {} ---@type table<number, boolean> mail index -> selected
local lastCheck ---@type number? anchor for shift-click range select

local open, returnBtn ---@type Button?, Button?
local checkboxes = {} ---@type CheckButton[]

--------------------------------------------------------------------------------
-- Row layout: indent the native rows to make room for the checkboxes on the left.
-- Applied only while Select is on; reverted to Blizzard's values otherwise.
--------------------------------------------------------------------------------
local layoutApplied = false
local function applyLayout(on)
  if layoutApplied == on or not _G.MailItem1 then return end
  layoutApplied = on
  _G.MailItem1:ClearAllPoints()
  _G.MailItem1:SetPoint("TOPLEFT", InboxFrame, "TOPLEFT", on and 29 or 28, on and -68 or -80)
  for i = 1, ROWS do
    local item, expire = _G["MailItem" .. i], _G["MailItem" .. i .. "ExpireTime"]
    item:SetWidth(on and 280 or 305)
    expire:ClearAllPoints()
    expire:SetPoint("TOPRIGHT", item, "TOPRIGHT", on and 10 or -4, -4)
  end
end

--------------------------------------------------------------------------------
-- Multi-select: plain toggle, shift = range from the last click, ctrl = every
-- letter from the same sender.
--------------------------------------------------------------------------------
local function toggleMail(cb)
  local index = cb:GetID() + (InboxFrame.pageNum - 1) * ROWS
  if lastCheck and IsShiftKeyDown() then
    for i = lastCheck, index, lastCheck <= index and 1 or -1 do checked[i] = true end
    ns.RefreshInbox()
    return
  end
  if IsControlKeyDown() then
    local on = cb:GetChecked() or nil
    local sender = select(3, GetInboxHeaderInfo(index))
    for i = 1, GetInboxNumItems() do
      if select(3, GetInboxHeaderInfo(i)) == sender then checked[i] = on end
    end
    ns.RefreshInbox()
    return
  end
  checked[index] = cb:GetChecked() or nil
  lastCheck = checked[index] and index or nil
end

--------------------------------------------------------------------------------
-- Batch processing (open / return), one action per throttled tick.
--------------------------------------------------------------------------------
local ticker = CreateFrame("Frame") -- raw frame: OnUpdate elapsed is in seconds
ticker:Hide()
ticker:SetScript("OnUpdate", function(self, elapsed)
  self.t = self.t - elapsed
  if self.t <= 0 then self:Hide(); ns._selectStep() end
end)
local function tick(after)
  ticker.t = after or 0.3 -- throttle between mail actions so the server keeps up
  ticker:Show()
end

local mode ---@type "open"|"return"|nil
local queue ---@type number[]?  selected indices, descending
local qi ---@type number?
local startCount ---@type number?  inbox letter count when the current letter began draining

local band = bit.band

-- True if the letter's attachment in `slot` can actually be placed — some bag has a free
-- slot that accepts it: a general bag (bagFamily 0 holds anything) or a specialized bag
-- whose family the item matches (a crafting reagent into the reagent bag when the general
-- bags are full). This is the engine's own bag-fit rule, so it agrees with where
-- TakeInboxItem would route the item. Item-aware on purpose: a blanket "any free slot"
-- count would pass a non-reagent when only the reagent bag is free, and TakeInboxItem
-- couldn't place it — the letter would never empty and _selectStep would re-tick forever.
local function attachmentFits(index, slot)
  local itemID = select(2, GetInboxItem(index, slot))
  local itemFamily = itemID and C_Item.GetItemFamily(itemID) or 0
  for b = 0, (NUM_BAG_SLOTS or 4) + 1 do -- incl. the reagent bag (5), matching forward.lua
    local free, bagFamily = C_Container.GetContainerNumFreeSlots(b)
    if free and free > 0
      and ((bagFamily or 0) == 0 or (itemFamily > 0 and band(bagFamily, itemFamily) ~= 0)) then
      return true
    end
  end
  return false
end

local function finish()
  mode, queue, qi, startCount = nil, nil, nil, nil
  if open then open:SetText("Open"); open:Enable(); open:Show() end
  if returnBtn then returnBtn:SetText("Return"); returnBtn:Enable(); returnBtn:Show() end
  ns.RefreshInbox()
end

function ns._selectStep()
  local index = queue and queue[qi]
  if not index then finish(); return end

  if mode == "return" then
    if InboxItemCanDelete(index) == false then ReturnInboxItem(index) end -- returnable = has a sender
    checked[index] = nil
    qi = qi + 1
    tick()
    return
  end

  -- open mode: take one attachment (highest slot first) or the coin, then re-tick on
  -- the SAME letter; move on only once it holds nothing more. Mail indices are volatile:
  -- when a letter empties it auto-deletes and the inbox re-indexes, sliding the next
  -- letter into this index. Baseline the letter count when a letter begins draining; a
  -- DROP means our letter auto-deleted, so a *different* (unselected) letter now sits at
  -- this index — advance instead of draining it. (New mail only increases the count; that
  -- rare front-insert re-index stays deferred, per CONTEXT's Select notes.)
  if startCount == nil then startCount = GetInboxNumItems() end
  if GetInboxNumItems() < startCount then checked[index] = nil; qi = qi + 1; startCount = nil; tick(); return end
  local money, cod = select(5, GetInboxHeaderInfo(index))
  if cod and cod > 0 then checked[index] = nil; qi = qi + 1; startCount = nil; tick(); return end -- never pay CoD
  local slot
  for a = ATTACHMENTS_MAX_RECEIVE, 1, -1 do
    if GetInboxItem(index, a) then slot = a; break end
  end
  if slot and attachmentFits(index, slot) then
    TakeInboxItem(index, slot)
    tick()
  elseif money and money > 0 then
    TakeInboxMoney(index)
    tick()
  else
    checked[index] = nil
    qi = qi + 1
    startCount = nil
    tick()
  end
end

local function startBatch(m)
  local q = {}
  for index in pairs(checked) do q[#q + 1] = index end
  if #q == 0 then return end
  table.sort(q, function(a, b) return a > b end) -- highest first
  mode, queue, qi, startCount = m, q, 1, nil
  local busy = m == "return" and returnBtn or open
  local hide = m == "return" and open or returnBtn
  busy:SetText("Working…"); busy:Disable()
  hide:Hide()
  ns._selectStep()
end

--------------------------------------------------------------------------------
-- Widgets: Open/Return buttons on the inbox + a checkbox per row.
--------------------------------------------------------------------------------
local function ensureWidgets()
  if not open then
    open = CreateFrame("Button", nil, InboxFrame, "UIPanelButtonTemplate")
    open:SetSize(120, 25)
    open:SetPoint("RIGHT", InboxFrame, "TOP", 0, -42)
    open:SetText("Open")
    open:SetScript("OnClick", function() startBatch("open") end)
    returnBtn = CreateFrame("Button", nil, InboxFrame, "UIPanelButtonTemplate")
    returnBtn:SetSize(120, 25)
    returnBtn:SetPoint("LEFT", InboxFrame, "TOP", 5, -42)
    returnBtn:SetText("Return")
    returnBtn:SetScript("OnClick", function() startBatch("return") end)
  end
  for i = 1, ROWS do
    if not checkboxes[i] then
      local cb = CreateFrame("CheckButton", nil, _G["MailItem" .. i], "InterfaceOptionsCheckButtonTemplate")
      cb:SetID(i)
      cb:SetPoint("RIGHT", _G["MailItem" .. i], "LEFT", 1, -5)
      cb:SetSize(24, 24)
      cb:SetHitRectInsets(0, 0, 0, 0)
      cb:SetScript("OnClick", function(self) toggleMail(self) end)
      cb.num = cb:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
      cb.num:SetPoint("BOTTOM", cb, "TOP")
      checkboxes[i] = cb
    end
  end
end

local function setShown(on)
  if open then open:SetShown(on) end
  if returnBtn then returnBtn:SetShown(on) end
  applyLayout(on)
end

-- Per-row decorator: refresh each checkbox's state + number.
ns.OnInboxRow(function(row)
  local cb = checkboxes[row.i]
  if not cb then return end
  if not ns.db.select or not row.present or mode then -- hidden while batch-processing
    cb:Hide()
    return
  end
  cb:SetChecked(checked[row.index])
  cb.num:SetText(row.index)
  cb:Show()
end)

ns.OnMailShow(function()
  if not InboxFrame then return end
  ensureWidgets()
  setShown(ns.db.select)
end)
ns.OnMailHide(function()
  ticker:Hide() -- abort any in-flight batch; the inbox is gone
  mode, queue, qi, startCount = nil, nil, nil, nil
  wipe(checked)
  lastCheck = nil
end)

ns.OnSettingChanged("select", function(value)
  setShown(value)
  ns.RefreshInbox()
end)
