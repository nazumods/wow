---@class Recycle: AddOn
local ns = LibNAddOn(...)
local GetItemInfo = C_Item.GetItemInfo

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

-- Manual marks come in two shapes (#1009):
--   * `db.itemsToSell[itemID] = true`      every copy of the item: stackables, and every mark made
--                                          before per-copy marks existed (kept as-is, so an old
--                                          mark reads exactly as it always did);
--   * `db.copiesToSell[copyKey] = true`    ONE copy of an equippable item. Normal / Heroic / Mythic
--                                          drops and most world gear share an itemID and differ only
--                                          in the bonus ids and item context inside the link.
-- `copiesToSell` is created lazily (a MigrateDB seed would not rerun on an existing DB).

--- Identity of one copy of an item, from its hyperlink: `itemID:context:bonusID:...`. The enchant,
--- gems, the linking player's level and spec are deliberately left out so the same copy keeps the same
--- key across gemming, re-linking and levelling.
---@param link string?
---@return string?
local function copyKey(link)
  local body = link and link:match("item:([%-%d:]*)")
  if not body then return nil end
  local f = {}
  for v in (body .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
  -- 1 itemID, 2 enchant, 3-6 gems, 7 suffix, 8 unique, 9 linkLevel, 10 spec, 11 modifiers,
  -- 12 context, 13 numBonusIDs, 14.. bonus ids
  local parts = { f[1] or "", f[12] or "" }
  for i = 1, tonumber(f[13]) or 0 do parts[#parts + 1] = f[13 + i] or "" end
  return table.concat(parts, ":")
end

--- Weapons and armor are marked per copy; everything else (trade goods, consumables) per item.
---@param itemID number
---@return boolean
local function isEquippable(itemID)
  local classID = select(6, C_Item.GetItemInfoInstant(itemID))
  return classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor
end

--- Returns true if the item should be sold at the next vendor visit.
--- `quality` is the container-info quality when the caller has it (avoids a
--- `GetItemInfo` cache miss on a cold login); falls back to `GetItemInfo`.
--- `link` is the item's hyperlink (container info's `hyperlink`), needed to honour a per-copy mark.
---@param itemID number
---@param quality number? container-info quality, if known
---@param link string? the item's hyperlink, if known
---@return boolean
local function shouldSell(itemID, quality, link)
  if not itemID then return false end
  if ns.db.itemsToSell[itemID] then return true end
  local copies = ns.db.copiesToSell
  if copies and link and next(copies) then
    local key = copyKey(link)
    if key and copies[key] then return true end
  end
  if ns.db.settings.sellGrey then
    if quality == nil then quality = select(3, GetItemInfo(itemID)) end
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
    -- An all-copies mark (a stackable, or one made before per-copy marks): clearing it is what the
    -- bag mark on this item was showing.
    ns.db.itemsToSell[id] = nil
  elseif isEquippable(id) then
    -- No usable key means no way to tell this copy from the others, and falling back to the
    -- all-copies mark would arm every copy of the item: mark nothing and say so.
    local key = copyKey(info.hyperlink)
    if not key then
      print("|cffffcc00Recycle:|r Couldn't read this item's link, so it was not marked. Try again in a moment.")
      return
    end
    ns.db.copiesToSell = ns.db.copiesToSell or {}
    ns.db.copiesToSell[key] = (not ns.db.copiesToSell[key]) or nil
  else
    ns.db.itemsToSell[id] = true
  end
end

-- Exposed for the specs (Recycle/spec).
ns.ShouldSell = shouldSell
ns.ToggleMark = toggle

-- ─── Sell at vendor ───────────────────────────────────────────────────────────

local function goldStr(copper)
  return math.floor(copper / 10000) .. "|cFFFFCC33g|r "
    .. math.floor((copper % 10000) / 100) .. "|cFFC9C9C9s|r "
    .. (copper % 100) .. "|cFFCC8890c|r"
end

local BUYBACK_LIMIT = 12
local RETRY_BUDGET = 3
local retriesLeft = RETRY_BUDGET
-- Sales counter for the current merchant visit. It persists across retry passes
-- and is reset only on MERCHANT_SHOW, so the cap spans passes: without this, each
-- cold-cache retry restarted its own count and could sell far more than 12 items
-- per visit, pushing older sales out of the 12-slot buyback window (unrecoverable).
local soldThisVisit = 0

local function sellItems()
  local sold, total = 0, 0
  local deferred = false
  -- Per-copy marks expire with their copy: count the copies of each marked key that are still in the
  -- bags after this pass, and drop a key with none left (sold, destroyed, or its bonus ids changed on an
  -- upgrade), so a later identical drop isn't sold on a stale mark.
  local copies = ns.db.copiesToSell
  local left = (copies and next(copies)) and {} or nil
  local complete = true
  for bag = 0, 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      if soldThisVisit >= BUYBACK_LIMIT then complete = false; break end
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local key = left and info and copyKey(info.hyperlink)
      if key and copies[key] then left[key] = (left[key] or 0) + 1 end
      if info and shouldSell(info.itemID, info.quality, info.hyperlink) then
        local price = select(11, GetItemInfo(info.itemID))
        if price == nil then
          -- Price not cached yet (cold login); ask for the data and retry later.
          C_Item.RequestLoadItemDataByID(info.itemID)
          deferred = true
        elseif price > 0 then
          C_Container.PickupContainerItem(bag, slot)
          PickupMerchantItem()
          if key and copies[key] then left[key] = left[key] - 1 end
          soldThisVisit = soldThisVisit + 1
          sold = sold + 1
          total = total + price * (info.stackCount or 1)
        end
      end
    end
    if soldThisVisit >= BUYBACK_LIMIT then complete = false; break end
  end
  -- Only on a full walk of the bags: a pass cut short by the buyback cap hasn't seen every copy.
  if left and complete then
    for key in pairs(copies) do
      if (left[key] or 0) <= 0 then copies[key] = nil end
    end
  end
  if sold > 0 and not ns.db.settings.silent then
    print("|cffffcc00Recycle:|r Sold " .. sold .. " item(s) for " .. goldStr(total) .. ".")
  end
  -- Re-run once the deferred item data has had a chance to load, while the
  -- merchant is still open, within the retry budget, and only while there is
  -- still buyback headroom left this visit.
  if deferred and retriesLeft > 0 and soldThisVisit < BUYBACK_LIMIT then
    retriesLeft = retriesLeft - 1
    ns:after(300, function()
      if MerchantFrame and MerchantFrame:IsShown() then sellItems() end
    end)
  end
end

ns.SellItems = sellItems -- exposed for the specs

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
      setMark(btn, info and shouldSell(info.itemID, info.quality, info.hyperlink))
    end
  else
    local container = _G["ContainerFrameContainer"]
    if container then
      for _, bagFrame in ipairs(container.ContainerFrames) do
        for _, btn in ipairs(bagFrame.Items) do
          local slot, bag = btn:GetSlotAndBagID()
          local info = C_Container.GetContainerItemInfo(bag, slot)
          setMark(btn, info and shouldSell(info.itemID, info.quality, info.hyperlink))
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
  Baganator.API.RegisterJunkPlugin("Recycle", "recycle", function(_, _, itemID, itemLink)
    return shouldSell(itemID, nil, itemLink)
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
    -- Preserve the stock boolean return ("did I handle this modified click"): Blizzard
    -- callers branch on it (e.g. ContainerFrame/BankFrame `if HandleModifiedItemClick(...)
    -- then return`), so dropping it makes a handled click read as unhandled and fall through.
    local handled = orig(link, item)
    if item and isOurClick() then
      local bag, slot = item:GetBagAndSlot()
      if bag then
        toggle(bag, slot)
        ns:refreshMarks()
      end
    end
    return handled
  end
end

-- ─── Events ──────────────────────────────────────────────────────────────────

function ns.MERCHANT_SHOW()
  retriesLeft = RETRY_BUDGET
  soldThisVisit = 0
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
    ns.db.copiesToSell = {}
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
