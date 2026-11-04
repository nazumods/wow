-- Loads Recycle/addon.lua against a fake environment so shouldSell / the manual mark toggle can be
-- unit-tested. Path is relative to the AddOns root (busted's cwd). The WoW globals the file touches
-- are installed for the duration of a load and restored by M.restore() (call from after_each).
local M = {}

local GLOBALS = { "LibNAddOn", "C_Item", "C_Container", "Enum", "PickupMerchantItem", "print" }
local saved

-- item ids the fake client calls equippable (classID 4 = Armor); everything else is a trade good (7).
local ARMOR, WEAPON, TRADE = 4, 2, 7

---@param opts { armor: table<number, boolean>?, container: table?, price: number? }?
---  armor: itemIDs that are equippable; container: the C_Container fake (default: empty);
---  price: the vendor price GetItemInfo reports (default 100)
---@return table ns
function M.load(opts)
  opts = opts or {}
  saved = {}
  for _, k in ipairs(GLOBALS) do saved[k] = _G[k] end

  _G.Enum = { ItemClass = { Weapon = WEAPON, Armor = ARMOR } }
  _G.C_Item = {
    GetItemInfo = function() return nil, nil, 4, nil, nil, nil, nil, nil, nil, nil, opts.price or 100 end,
    RequestLoadItemDataByID = function() end,
    GetItemInfoInstant = function(id)
      return id, nil, nil, nil, nil, (opts.armor and opts.armor[id]) and ARMOR or TRADE
    end,
  }
  _G.C_Container = opts.container or { GetContainerItemInfo = function() end }

  _G.PickupMerchantItem = function() if M.onSell then M.onSell() end end
  M.printed = {}
  _G.print = function(...) M.printed[#M.printed + 1] = table.concat({ ... }, " ") end

  local ns = { db = { settings = { sellGrey = false, silent = true }, itemsToSell = {} } }
  _G.LibNAddOn = function() return ns end
  assert(loadfile("Recycle/addon.lua"))("Recycle", ns)
  return ns
end

function M.restore()
  for _, k in ipairs(GLOBALS) do _G[k] = saved and saved[k] end
end

---A fake set of bags for SellItems: `bags[bag]` is an array of `{ itemID, hyperlink }` (false once
---sold). PickupContainerItem remembers the slot and PickupMerchantItem "sells" it.
---@param bags table<number, table[]>
---@return table container
function M.bags(bags)
  local picked
  M.onSell = function() bags[picked[1]][picked[2]] = false end
  return {
    GetContainerNumSlots = function(bag) return bags[bag] and #bags[bag] or 0 end,
    GetContainerItemInfo = function(bag, slot)
      local it = bags[bag] and bags[bag][slot]
      if not it then return nil end
      return { itemID = it[1], hyperlink = it[2], quality = 4, stackCount = 1 }
    end,
    PickupContainerItem = function(bag, slot) picked = { bag, slot } end,
  }
end

---The copy key `addon.lua` derives from a link made by `M.link(itemID, context, bonuses)`.
---@return string
function M.key(itemID, context, bonuses)
  return itemID .. ":" .. context .. (#bonuses > 0 and ":" .. table.concat(bonuses, ":") or "")
end

---An item hyperlink the way the client writes it: itemID, then enchant/gems/suffix/unique, link level,
---spec, modifiers, context, and the bonus id list.
---@param itemID number
---@param context number
---@param bonuses number[]
---@param linkLevel number?
---@return string
function M.link(itemID, context, bonuses, linkLevel)
  local f = { itemID, 0, 0, 0, 0, 0, 0, 0, linkLevel or 80, 250, 0, context, #bonuses }
  for _, b in ipairs(bonuses) do f[#f + 1] = b end
  return ("|cffa335ee|Hitem:%s|h[Foo Ring]|h|r"):format(table.concat(f, ":"))
end

return M
