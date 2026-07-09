---@type Warbandeer_Characters
local ns = select(2, ...)
local insert = table.insert
local FetchDepositedMoney = C_Bank.FetchDepositedMoney
local ACCOUNT = Enum.BankType.Account

-- Account-wide warband data. Unlike per-character brokers, the warband bank is
-- shared across the whole account, so it lives once at the DB top level
-- (`db.warband`) rather than being duplicated into every character.

---@class WarbandWeek
---@field start integer server-time of the weekly reset this week began at
---@field baseline integer total warband wealth (copper) at the start of the week

---@class WarbandWeekRecord: WarbandWeek
---@field ending integer total warband wealth (copper) when the week closed
---@field made integer gold made over the week (copper) = ending - baseline

---@class WarbandData
---@field bankGold integer last-known warband (account) bank gold, in copper
---@field week? WarbandWeek current (open) week
---@field history WarbandWeekRecord[] closed weeks, oldest first

---Read the current warband (account) bank gold. Returns nil if not yet available.
local function readBankGold()
  return FetchDepositedMoney(ACCOUNT)
end

---Total warband wealth = warband bank + last-known gold of every character.
---@class Warbandeer_Characters
---@field GetWarbandWealth fun(): integer copper
function ns:GetWarbandWealth()
  local w = self.db.warband
  local total = (w and w.bankGold) or 0
  for _, c in pairs(self.db.characters) do
    if c.currency and c.currency.gold then total = total + c.currency.gold end
  end
  return total
end

---Close out any elapsed week(s) and (re)seed the current week's baseline.
---Uses last-known wealth at first login after the reset as the closing figure
---(best available; consistent with the rest of the addon's last-seen model).
---@class Warbandeer_Characters
---@field RolloverWarbandWeek fun()
function ns:RolloverWarbandWeek()
  ---@type WarbandData
  local w = self.db.warband
  if not w.week then
    w.week = { start = ns.LAST_RESET, baseline = self:GetWarbandWealth() }
    return
  end
  if w.week.start < ns.LAST_RESET then
    local ending = self:GetWarbandWealth()
    insert(w.history, {
      start    = w.week.start,
      ending   = ending,
      made     = ending - w.week.baseline,
    })
    w.week = { start = ns.LAST_RESET, baseline = ending }
  end
end

---Login-time setup: ensure the store exists, capture bank gold, hook updates,
---then run the weekly rollover. Called once per session from `initialize()`.
---@class Warbandeer_Characters
---@field InitWarband fun()
function ns:InitWarband()
  if not self.db.warband then self.db.warband = { bankGold = 0, history = {} } end
  local gold = readBankGold()
  if gold ~= nil then self.db.warband.bankGold = gold end
  ns:registerEvent("ACCOUNT_MONEY", function()
    local g = readBankGold()
    if g ~= nil then ns.db.warband.bankGold = g end
  end)
  self:RolloverWarbandWeek()
end

ns:registerDump("warband", "Warband Wealth", "Dump warband wealth tracking", function(self, out)
  local w = self.db.warband
  if not w then out:line("No warband data yet."); return end
  local g = function(copper) return math.floor((copper or 0) / 10000) end
  out:line("Warband Wealth:")
  out:line("Bank gold: " .. g(w.bankGold) .. "g")
  out:line("Total wealth: " .. g(self:GetWarbandWealth()) .. "g")
  if w.week then
    out:line("Made this week: " .. g(self:GetWarbandWealth() - w.week.baseline) .. "g")
  end
  out:line(#(w.history or {}) .. " week(s) of history.")
end)
