-- Weekly reset anchor (#1108), its slack handling in InitBrokers (#1041) and the warband
-- week rollover (#1012).
--
-- broker.lua computes ns.LAST_RESET from GetServerTime / C_DateAndTime at load, so each
-- test loads it fresh against a chosen "now" and seconds-until-weekly-reset. warband.lua is
-- loaded into the same ns so RolloverWarbandWeek sees the real LAST_RESET / RESET_SLACK.

-- luacheck: globals GetServerTime C_DateAndTime C_Bank Enum

local libn = require("LibNAddOn.spec.libn")

local DAY = 24 * 60 * 60
local WEEK = 7 * DAY
local SLACK = 12 * 60 * 60
local NOW = 1700000000

---@param now integer server time
---@param untilWeekly integer seconds until the next weekly reset
local function load(now, untilWeekly)
  _G.GetServerTime = function() return now end
  _G.C_DateAndTime = {
    GetSecondsUntilDailyReset = function() return 3600 end,
    GetSecondsUntilWeeklyReset = function() return untilWeekly end,
  }
  _G.C_Bank = { FetchDepositedMoney = function() return 0 end }
  _G.Enum = { BankType = { Account = 2 } }
  local ns = { lua = { Class = libn.load().lua.Class } }
  ns.registerDump = function() end
  assert(loadfile("Warbandeer_Characters/broker.lua"))("Warbandeer_Characters", ns)
  assert(loadfile("Warbandeer_Characters/data/warband.lua"))("Warbandeer_Characters", ns)
  return ns
end

describe("Warbandeer_Characters ns.LAST_RESET", function()
  it("is the weekly reset that already happened: <= now and within the last 7 days", function()
    for _, untilWeekly in ipairs({ 1, DAY, 3 * DAY, WEEK - 1, WEEK }) do
      local ns = load(NOW, untilWeekly)
      assert.is_true(ns.LAST_RESET <= NOW)
      assert.is_true(NOW - ns.LAST_RESET <= WEEK)
      assert.equal(NOW + untilWeekly - WEEK, ns.LAST_RESET)
    end
  end)
end)

describe("Warbandeer_Characters InitBrokers weekly reset", function()
  local resets

  ---Fresh ns carrying one counting broker and a db whose stored lastReset is `stored`.
  local function init(ns, stored)
    resets = 0
    ns.brokers.counter = { Init = function() end, Reset = function(_, cadence)
      if cadence == ns.RESET_WEEKLY then resets = resets + 1 end
    end }
    ns.brokerOrder = { "counter" }
    ns.currentData = {}
    -- daily and Sunday anchors are out of scope here; store them current so they never fire
    ns.db = {
      characters = { a = {} },
      lastReset = stored,
      lastDailyReset = ns.LAST_DAILY_RESET,
      lastSundayReset = ns.LAST_SUNDAY_RESET,
    }
    ns:InitBrokers()
  end

  it("fires on the first ever login (nothing stored)", function()
    local ns = load(NOW, 3 * DAY)
    init(ns, nil)
    assert.equal(1, resets)
    assert.equal(ns.LAST_RESET, ns.db.lastReset)
  end)

  it("does not fire when the anchor skews by a second between sessions", function()
    local ns = load(NOW, 3 * DAY)
    init(ns, ns.LAST_RESET - 1)
    assert.equal(0, resets)
    init(ns, ns.LAST_RESET + 1)
    assert.equal(0, resets)
  end)

  it("fires once the stored anchor is a week behind", function()
    local ns = load(NOW, 3 * DAY)
    init(ns, ns.LAST_RESET - WEEK)
    assert.equal(1, resets)
    assert.equal(ns.LAST_RESET, ns.db.lastReset)
  end)

  it("first login after the anchor fix: a stored old-formula value (next reset - 1 day) does not fire", function()
    local ns = load(NOW, 3 * DAY)
    init(ns, NOW + 3 * DAY - DAY)
    assert.equal(0, resets)
  end)

  it("fires exactly once at the next reset for a stored old-formula value", function()
    local oldStored = NOW + 3 * DAY - DAY
    local nextReset = NOW + 3 * DAY
    -- an hour after the reset: the new anchor is the reset itself, a day past the stored value
    local ns = load(nextReset + 3600, WEEK - 3600)
    assert.equal(nextReset, ns.LAST_RESET)
    init(ns, oldStored)
    assert.equal(1, resets)
    -- and the next login the same week, now stored accurately, stays quiet
    init(ns, ns.db.lastReset)
    assert.equal(0, resets)
  end)

  it("slack boundary: exactly 12h does not fire, 12h + 1s does", function()
    local ns = load(NOW, 3 * DAY)
    init(ns, ns.LAST_RESET - SLACK)
    assert.equal(0, resets)
    init(ns, ns.LAST_RESET - SLACK - 1)
    assert.equal(1, resets)
  end)
end)

describe("Warbandeer_Characters RolloverWarbandWeek", function()
  local ns, T

  before_each(function()
    ns = load(NOW, 3 * DAY)
    T = ns.LAST_RESET
    ns.db = { characters = {}, warband = { bankGold = 500, history = {} } }
  end)

  it("seeds the first week at LAST_RESET with the current wealth as baseline", function()
    ns:RolloverWarbandWeek()
    assert.equal(T, ns.db.warband.week.start)
    assert.equal(500, ns.db.warband.week.baseline)
    assert.equal(0, #ns.db.warband.history)
  end)

  it("does not roll over when LAST_RESET is 1s ahead of week.start (skew)", function()
    ns.db.warband.week = { start = T - 1, baseline = 100 }
    ns:RolloverWarbandWeek()
    assert.equal(T - 1, ns.db.warband.week.start)
    assert.equal(100, ns.db.warband.week.baseline)
    assert.equal(0, #ns.db.warband.history)
  end)

  it("does not roll over for a stored start ahead of LAST_RESET (old-formula value)", function()
    ns.db.warband.week = { start = T + 6 * DAY, baseline = 100 }
    ns:RolloverWarbandWeek()
    assert.equal(0, #ns.db.warband.history)
  end)

  it("rolls over when LAST_RESET is a week ahead of week.start", function()
    ns.db.warband.week = { start = T - WEEK, baseline = 100 }
    ns:RolloverWarbandWeek()
    assert.equal(1, #ns.db.warband.history)
    assert.same({ start = T - WEEK, ending = 500, made = 400 }, ns.db.warband.history[1])
    assert.same({ start = T, baseline = 500 }, ns.db.warband.week)
  end)

  it("rolls over once the stored start is a day behind (first reset after the anchor fix)", function()
    ns.db.warband.week = { start = T - DAY, baseline = 100 }
    ns:RolloverWarbandWeek()
    assert.equal(1, #ns.db.warband.history)
  end)
end)
