-- globals/money.lua isn't part of the libn.lua harness (it hangs off ns.wow), so
-- load it standalone against a minimal ns — it's pure (only math + string), no stubs.

describe("LibNAddOn ns.wow.CoinString", function()
  local CoinString

  before_each(function()
    local ns = {}
    assert(loadfile("LibNAddOn/globals/money.lua"))("LibNAddOn", ns)
    CoinString = ns.wow.CoinString
  end)

  it("formats gold, silver and copper", function()
    assert.equal("1023g 4s 5c", CoinString(10230405))
  end)

  it("omits zero denominations", function()
    assert.equal("1g", CoinString(10000))
    assert.equal("5s", CoinString(500))
    assert.equal("7c", CoinString(7))
    assert.equal("1g 5c", CoinString(10005)) -- silver skipped
    assert.equal("2g 3s", CoinString(20300)) -- copper skipped
  end)

  it("returns 0c for a zero amount", function()
    assert.equal("0c", CoinString(0))
  end)

  it("floors to whole copper", function()
    assert.equal("3s 21c", CoinString(321))
  end)

  it("does not create ns.wow if one already exists", function()
    local existing = { maxLevel = 80 }
    local ns = { wow = existing }
    assert(loadfile("LibNAddOn/globals/money.lua"))("LibNAddOn", ns)
    assert.equal(existing, ns.wow) -- same table, guard preserved it
    assert.equal(80, ns.wow.maxLevel)
    assert.is_function(ns.wow.CoinString)
  end)
end)

describe("LibNAddOn ns.wow.GoldString", function()
  local GoldString

  before_each(function()
    local ns = {}
    assert(loadfile("LibNAddOn/globals/money.lua"))("LibNAddOn", ns)
    GoldString = ns.wow.GoldString
  end)

  after_each(function()
    _G.BreakUpLargeNumbers = nil -- undo any per-test stub
  end)

  it("truncates to whole gold", function()
    assert.equal("1", GoldString(19999))   -- 1g 99s 99c -> 1
    assert.equal("1023", GoldString(10230405))
  end)

  it("returns 0 for a zero amount", function()
    assert.equal("0", GoldString(0))
  end)

  it("floors negative amounts toward minus infinity", function()
    assert.equal("-2", GoldString(-12345)) -- matches math.floor semantics
  end)

  it("applies the client's grouping when BreakUpLargeNumbers exists", function()
    _G.BreakUpLargeNumbers = function(n) return "[" .. n .. "]" end
    assert.equal("[1234]", GoldString(12340000))
  end)

  it("falls back to a plain tostring without BreakUpLargeNumbers", function()
    assert.equal("1234", GoldString(12340000))
  end)
end)
