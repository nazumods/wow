-- The harness itself: libn.load(opts) picks the client flavor flavor.lua detects while loading, so
-- an addon's specs can run as either flavor. The WOW_PROJECT_* globals exist only for the load.

local libn = require("LibNAddOn.spec.libn")

describe("libn.load flavor option", function()
  local saved

  before_each(function()
    saved = { id = _G.WOW_PROJECT_ID, camelot = _G.WOW_PROJECT_CAMELOT }
    _G.WOW_PROJECT_ID, _G.WOW_PROJECT_CAMELOT = nil, nil
  end)

  after_each(function()
    _G.WOW_PROJECT_ID, _G.WOW_PROJECT_CAMELOT = saved.id, saved.camelot
  end)

  it("loads as Retail by default", function()
    local ns = libn.load()
    assert.equals("retail", ns.flavor.id)
    assert.is_true(ns.flavor.isRetail)
  end)

  it("loads as Retail with an empty options table or flavor = 'retail'", function()
    assert.equals("retail", libn.load({}).flavor.id)
    assert.equals("retail", libn.load({ flavor = "retail" }).flavor.id)
  end)

  it("loads as Forever with flavor = 'forever'", function()
    local ns = libn.load({ flavor = "forever" })
    assert.equals("forever", ns.flavor.id)
    assert.is_true(ns.flavor.isForever)
    assert.is_false(ns.Supports("housing"))
  end)

  it("restores the WOW_PROJECT_* globals after a Forever load", function()
    libn.load({ flavor = "forever" })
    assert.is_nil(_G.WOW_PROJECT_ID)
    assert.is_nil(_G.WOW_PROJECT_CAMELOT)
  end)

  it("restores previously defined WOW_PROJECT_* values rather than clearing them", function()
    _G.WOW_PROJECT_ID, _G.WOW_PROJECT_CAMELOT = 1, 18
    libn.load({ flavor = "forever" })
    assert.equals(1, _G.WOW_PROJECT_ID)
    assert.equals(18, _G.WOW_PROJECT_CAMELOT)
    libn.load()
    assert.equals(1, _G.WOW_PROJECT_ID)
    assert.equals(18, _G.WOW_PROJECT_CAMELOT)
  end)

  it("isn't flipped to Forever by constants a previous case left defined", function()
    _G.WOW_PROJECT_ID, _G.WOW_PROJECT_CAMELOT = 18, 18
    assert.equals("retail", libn.load().flavor.id)
  end)

  it("rejects an unknown flavor", function()
    assert.has_error(function() libn.load({ flavor = "classic" }) end)
  end)

  it("rethrows a load failure, and still restores the globals", function()
    -- A default (Retail) load reaches C_AddOns in flavor.lua's detection, which throws here.
    local savedAddOns = _G.C_AddOns
    _G.C_AddOns = setmetatable({}, { __index = function() error("boom") end })
    _G.WOW_PROJECT_ID, _G.WOW_PROJECT_CAMELOT = 1, 18
    local ok, err = pcall(libn.load)
    _G.C_AddOns = savedAddOns
    assert.is_false(ok)
    assert.is_truthy(tostring(err):find("boom", 1, true))
    assert.equals(1, _G.WOW_PROJECT_ID)
    assert.equals(18, _G.WOW_PROJECT_CAMELOT)
  end)
end)
