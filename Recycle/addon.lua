-- luacheck: globals LibNAddOn Baganator HandleModifiedItemClick GetMouseButtonClicked IsControlKeyDown IsShiftKeyDown IsAltKeyDown PickupMerchantItem
---@class Recycle: AddOn
local ns = LibNAddOn(...)

-- ─── DB migration ─────────────────────────────────────────────────────────────

function ns:MigrateDB()
  local db = ns.db
  if not db.settings then db.settings = {} end
  if db.settings.sellGrey == nil then db.settings.sellGrey = true end
  if db.settings.silent  == nil then db.settings.silent  = false end
  if db.settings.modKey  == nil then db.settings.modKey  = "CTRL" end
  if not db.itemsToSell then db.itemsToSell = {} end
  db.version = 1
end

-- ─── Sell decision ────────────────────────────────────────────────────────────

--- Returns true if the item should be sold at the next vendor visit.
---@param itemID number
---@return boolean
local function shouldSell(itemID)
  if not itemID then return false end
  if ns.db.itemsToSell[itemID] then return true end
  if ns.db.settings.sellGrey then
    local quality = select(3, GetItemInfo(itemID))
    if quality == 0 then return true end
  end
  return false
end

-- ─── Toggle manual mark ───────────────────────────────────────────────────────

--- Flips the manual sell mark for the item at the given bag slot.
---@param bag number
---@param slot number
local function toggle(bag, slot)
  local info = C_Container.GetContainerItemInfo(bag, slot)
  if not info or not info.itemID then return end
  local id = info.itemID
  if ns.db.itemsToSell[id] then
    ns.db.itemsToSell[id] = nil
  else
    ns.db.itemsToSell[id] = true
  end
end

-- ─── Sell at vendor ───────────────────────────────────────────────────────────

local function goldStr(copper)
  return math.floor(copper / 10000) .. "|cFFFFCC33g|r "
    .. math.floor((copper % 10000) / 100) .. "|cFFC9C9C9s|r "
    .. (copper % 100) .. "|cFFCC8890c|r"
end

local BUYBACK_LIMIT = 12

local function sellItems()
  local count, total = 0, 0
  for bag = 0, 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      if count >= BUYBACK_LIMIT then break end
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and shouldSell(info.itemID) then
        local price = select(11, GetItemInfo(info.itemID))
        if price and price > 0 then
          C_Container.PickupContainerItem(bag, slot)
          PickupMerchantItem()
          count = count + 1
          total = total + price * (info.stackCount or 1)
        end
      end
    end
    if count >= BUYBACK_LIMIT then break end
  end
  if count > 0 and not ns.db.settings.silent then
    print("|cffffcc00Recycle:|r Sold " .. count .. " item(s) for " .. goldStr(total) .. ".")
  end
end

-- ─── Visual marks (default WoW bags) ─────────────────────────────────────────

local MARK_TEXTURE = "Interface\\Icons\\INV_Misc_Coin_02"

local function setMark(btn, show)
  if not btn then return end
  if show then
    if not btn._recycleMark then
      local tex = btn:CreateTexture(nil, "OVERLAY")
      tex:SetTexture(MARK_TEXTURE)
      tex:SetSize(16, 16)
      tex:SetPoint("BOTTOMRIGHT", -2, 2)
      tex:SetAlpha(0.9)
      btn._recycleMark = tex
    end
    btn._recycleMark:Show()
  elseif btn._recycleMark then
    btn._recycleMark:Hide()
  end
end

local function refreshDefaultBags()
  local combined = _G["ContainerFrameCombinedBags"]
  if combined and combined:IsShown() then
    for _, btn in ipairs(combined.Items) do
      local slot, bag = btn:GetSlotAndBagID()
      local info = C_Container.GetContainerItemInfo(bag, slot)
      setMark(btn, info and shouldSell(info.itemID))
    end
  else
    local container = _G["ContainerFrameContainer"]
    if container then
      for _, bagFrame in ipairs(container.ContainerFrames) do
        for _, btn in ipairs(bagFrame.Items) do
          local slot, bag = btn:GetSlotAndBagID()
          local info = C_Container.GetContainerItemInfo(bag, slot)
          setMark(btn, info and shouldSell(info.itemID))
        end
      end
    end
  end
end

--- Refreshes sell marks on all visible bag item buttons.
function ns:refreshMarks()
  if Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then
    Baganator.API.RequestItemButtonsRefresh()
  end
  refreshDefaultBags()
end

-- ─── Baganator integration ────────────────────────────────────────────────────

local function setupBaganator()
  if not Baganator or not Baganator.API or not Baganator.API.RegisterJunkPlugin then return end
  Baganator.API.RegisterJunkPlugin("Recycle", "recycle", function(_, _, itemID, _)
    return shouldSell(itemID)
  end)
end

-- ─── Modifier+RightClick hook ─────────────────────────────────────────────────

local function isOurClick()
  local mk = ns.db.settings.modKey
  local down
  if     mk == "CTRL"  then down = IsControlKeyDown()
  elseif mk == "SHIFT" then down = IsShiftKeyDown()
  elseif mk == "ALT"   then down = IsAltKeyDown()
  end
  return down and GetMouseButtonClicked() == "RightButton"
end

local function hookItemClick()
  local orig = HandleModifiedItemClick
  HandleModifiedItemClick = function(link, item)
    orig(link, item)
    if item and isOurClick() then
      local bag, slot = item:GetBagAndSlot()
      if bag then
        toggle(bag, slot)
        ns:refreshMarks()
      end
    end
  end
end

-- ─── Events ──────────────────────────────────────────────────────────────────

function ns.MERCHANT_SHOW()
  sellItems()
end

function ns.BAG_UPDATE()
  ns:delay(500, function() ns:refreshMarks() end)
end

-- ─── Lifecycle ────────────────────────────────────────────────────────────────

function ns:onLogin()
  setupBaganator()
  ns:refreshMarks()
end

function ns:onLoad()
  ns:registerEvent("MERCHANT_SHOW")
  ns:registerEvent("BAG_UPDATE")
  hookItemClick()

  local settings = ns.ui.SettingsFrame:new{ headingText = "Recycle" }
  settings:AddToggleControl("Auto-sell grey (Poor) items", ns.db.settings, "sellGrey").SettingChanged = function(_, _state)
    ns:refreshMarks()
  end
  settings:AddToggleControl("Silent mode (suppress sale summary)", ns.db.settings, "silent")
  settings:RegisterCategory()

  ns:registerCommand("", nil, function()
    Settings.OpenToCategory("Recycle")
  end, "Open settings")

  ns:registerCommand("clear", nil, function()
    ns.db.itemsToSell = {}
    ns:refreshMarks()
    print("|cffffcc00Recycle:|r Sell list cleared.")
  end, "Clear manually-marked items")

  ns:registerCommand("key", nil, function(_, arg)
    local k = arg and arg:upper():match("^(%a+)")
    if k == "CTRL" or k == "SHIFT" or k == "ALT" then
      ns.db.settings.modKey = k
      print("|cffffcc00Recycle:|r Modifier key set to " .. k .. ".")
    else
      print("|cffffcc00Recycle:|r Usage: /recycle key CTRL|SHIFT|ALT  (current: " .. ns.db.settings.modKey .. ")")
    end
  end, "Set modifier key for marking items (CTRL/SHIFT/ALT)")
end
