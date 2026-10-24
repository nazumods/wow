-- ns.setupDB (database.lua): MigrateDB runs on an upgrade only, never on equal or newer stored versions.

local libn = require("LibNAddOn.spec.libn")

describe("setupDB migration gate", function()
  local ns

  before_each(function()
    ns = libn.load()
    _G.TestDB = nil
  end)

  after_each(function()
    _G.TestDB = nil
  end)

  -- Runs ADDON_LOADED for an addon whose toc version is `tocVersion` and whose saved db is
  -- `stored` (nil = first run); returns how many times MigrateDB ran.
  local function load(tocVersion, stored, ops)
    local runs = 0
    local handler
    local addOn = {
      registerEvent = function(_, _, fn) handler = fn end,
      MigrateDB = function() runs = runs + 1 end,
    }
    if stored ~= nil then _G.TestDB = { version = stored } end
    assert(loadfile("LibNAddOn/database.lua"))("LibNAddOn", ns)
    ns.setupDB("Test", addOn, ops or { name = "TestDB", version = tocVersion })
    handler(addOn, "Test")
    return runs, addOn
  end

  it("migrates when no version is stored", function()
    local runs = load(3)
    assert.equals(1, runs)
  end)

  it("migrates on an upgrade", function()
    assert.equals(1, (load(4, 3)))
  end)

  it("does not migrate when the stored version equals the toc version", function()
    assert.equals(0, (load(3, 3)))
  end)

  it("does not migrate on a downgrade (stored version is newer)", function()
    local runs = load(3, 4)
    assert.equals(0, runs)
    assert.equals(4, _G.TestDB.version)
  end)

  it("compares string versions numerically", function()
    assert.equals(1, (load("10", "9")))
    assert.equals(0, (load("9", "10")))
  end)

  it("reads the version from ops.defaults when ops.version is unset", function()
    assert.equals(1, (load(nil, 1, { name = "TestDB", defaults = { version = 2 } })))
  end)

  it("never migrates an addOn that has no MigrateDB or no version", function()
    local handler
    local addOn = { registerEvent = function(_, _, fn) handler = fn end }
    assert(loadfile("LibNAddOn/database.lua"))("LibNAddOn", ns)
    ns.setupDB("Test", addOn, { name = "TestDB", version = 5 })
    assert.has_no.errors(function() handler(addOn, "Test") end)
  end)
end)
