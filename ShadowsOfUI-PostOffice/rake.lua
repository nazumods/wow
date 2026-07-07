---@type ShadowsOfUI_PostOffice
local ns = select(2, ...)

-- Rake: report the coin collected during a mailbox visit. Snapshot the player's
-- money on arrival, print the gain when the mailbox closes. (Postal's Rake only
-- reports; it does not auto-loot — that stays the user's click.)
local moneyAtOpen ---@type number?

ns.OnMailShow(function()
  if not ns.db.rake then moneyAtOpen = nil; return end
  moneyAtOpen = GetMoney()
end)

ns.OnMailHide(function()
  if not ns.db.rake or not moneyAtOpen then return end
  local gained = GetMoney() - moneyAtOpen
  moneyAtOpen = nil
  if gained > 0 then
    ns:Print("Collected", GetCoinTextureString(gained))
  end
end)
