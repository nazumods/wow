---@type ShadowsOfUI_PostOffice
local ns = select(2, ...)

-- QuickAttach: a column of trade-goods category buttons beside the Send-Mail frame.
-- Left-click a category to attach every matching (non-soulbound) stack from your bags
-- to the outgoing letter — one click to mail all your cloth / herbs / ore to an alt.
-- Whole stacks only, so this attaches synchronously in the click handler (no split
-- dance like Forward needs).
local TRADEGOODS = Enum.ItemClass.Tradegoods
local ALL = -1 -- pseudo-subclass: every trade good

-- subclass IDs are the stable Enum.ItemTradegoodsSubclass values (not exposed as an
-- Enum in the API docs); icons are the current profession-category fileIDs / paths.
local CATEGORIES = {
  { sub = 5,  icon = 4620681, label = "Cloth" },
  { sub = 6,  icon = 4620678, label = "Leather" },
  { sub = 7,  icon = 4625105, label = "Metal & Stone" },
  { sub = 8,  icon = 4620671, label = "Cooking" },
  { sub = 9,  icon = 133939,  label = "Herb" },
  { sub = 12, icon = 4620672, label = "Enchanting" },
  { sub = 16, icon = 4620676, label = "Inscription" },
  { sub = 4,  icon = 4620677, label = "Jewelcrafting" },
  { sub = 10, icon = [[Interface\Icons\INV_Elemental_Primal_Air]], label = "Elemental" },
  { sub = 18, icon = [[Interface\Icons\INV_Bijou_Green]],          label = "Optional Reagents" },
  { sub = 11, icon = [[Interface\Icons\INV_Misc_Rune_09]],         label = "Other" },
  { sub = ALL, icon = [[Interface\Icons\Ability_Ensnare]],         label = "All Trade Goods" },
}

local LAST_BAG = (NUM_BAG_SLOTS or 4) + 1 -- backpack(0), four bags(1-4), reagent bag(5)
local BUTTON = 28
local buttons ---@type Button[]?

local function firstFreeSendSlot()
  for i = 1, ATTACHMENTS_MAX_SEND do
    if not HasSendMailItem(i) then return i end
  end
end

-- Attach every matching, mailable stack until the letter's attachment slots fill up.
local function attachCategory(subclass)
  for bag = 0, LAST_BAG do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local send = firstFreeSendSlot()
      if not send then return end -- no room left on the letter
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and not info.isLocked and info.itemID then
        local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(info.itemID)
        if classID == TRADEGOODS and (subclass == ALL or subID == subclass) then
          -- Skip only true soulbound (OnAcquire); warbound trade goods still mail to alts.
          if select(14, C_Item.GetItemInfo(info.itemID)) ~= Enum.ItemBind.OnAcquire then
            C_Container.PickupContainerItem(bag, slot)
            ClickSendMailItemButton(send)
          end
        end
      end
    end
  end
end

--------------------------------------------------------------------------------
-- Buttons: a column anchored off the right edge of the mail frame.
--------------------------------------------------------------------------------
local function makeButton(index, cat)
  local b = CreateFrame("Button", nil, SendMailFrame)
  b:SetSize(BUTTON, BUTTON)
  b:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 2, -((index - 1) * (BUTTON + 4)) - 4)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture(cat.icon)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]])
  b:SetScript("OnClick", function() attachCategory(cat.sub) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(cat.label)
    GameTooltip:AddLine("Attach all of this type from your bags.", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  return b
end

-- SendMailFrame is load-on-demand (Blizzard_MailFrame); build lazily on first open.
local function ensureButtons()
  if buttons then return end
  buttons = {}
  for i, cat in ipairs(CATEGORIES) do buttons[i] = makeButton(i, cat) end
end

local function setShown(shown)
  if not buttons then return end
  for _, b in ipairs(buttons) do b:SetShown(shown) end
end

ns.OnMailShow(function()
  if not SendMailFrame then return end
  ensureButtons()
  setShown(ns.db.quickAttach)
end)

ns.OnSettingChanged("quickAttach", setShown)
