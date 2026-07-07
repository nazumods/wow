---@type ShadowsOfUI_PostOffice
local ns = select(2, ...)

-- TradeBlock: raise the BlockTrades CVar while the mailbox is open so incoming
-- trade requests are auto-declined, then restore the player's own setting on
-- close. SetTemporaryCVar (LibNAddOn) backs up the original once and guarantees
-- a logout restore even if we never see the close.
local CVAR = "BlockTrades"

local function block()
  if not ns.db.tradeBlock then return end
  ns:SetTemporaryCVar(CVAR, 1)
end

local function unblock()
  ns:RestoreCVar(CVAR)
end

ns.OnMailShow(block)
ns.OnMailHide(unblock)

-- Toggle taking effect while already standing at the mailbox.
ns.OnSettingChanged("tradeBlock", function(value)
  if not ns._atMailbox then return end
  if value then block() else unblock() end
end)
