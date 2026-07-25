local wbchar = require("Warbandeer_Characters.spec.wbchar")

describe("Warbandeer_Characters ns.ShapeTitleCatalog", function()
  local ns
  before_each(function() ns = wbchar.load() end)

  local function rows()
    return {
      { id = 1,  name = "Private",   known = true },
      { id = 5,  name = "Corporal",  known = false },
      { id = 42, name = "the Kingslayer" },          -- known omitted entirely
      { id = 77, name = "Battlelord", known = true },
    }
  end

  local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
  end

  it("keys names by title mask id", function()
    local c = ns.ShapeTitleCatalog(rows())
    assert.equal("Private", c.names[1])
    assert.equal("Corporal", c.names[5])
    assert.equal("the Kingslayer", c.names[42])
    assert.equal(4, count(c.names))
  end)

  it("marks only the scanning character's known titles as account-wide", function()
    local c = ns.ShapeTitleCatalog(rows())
    assert.is_true(c.accountWide[1])
    assert.is_true(c.accountWide[77])
    assert.equal(2, count(c.accountWide))
  end)

  -- Absent, not `false`: an unknown title must not serialise a key per title into SavedVariables.
  it("omits unknown titles from accountWide rather than storing false", function()
    local c = ns.ShapeTitleCatalog(rows())
    assert.is_nil(c.accountWide[5])
    assert.is_nil(c.accountWide[42])
  end)

  it("reports both counts", function()
    local c = ns.ShapeTitleCatalog(rows())
    assert.equal(4, c.count)
    assert.equal(2, c.accountWideCount)
  end)

  it("drops rows with no usable name", function()
    local c = ns.ShapeTitleCatalog({
      { id = 1, name = "Private", known = true },
      { id = 2, name = "" },
      { id = 3 },
      { name = "orphan", known = true },
    })
    assert.equal(1, c.count)
    assert.equal(1, count(c.names))
    assert.equal(1, c.accountWideCount)
  end)

  -- A repeated mask id keeps its first name so the count can't drift from the table size.
  it("keeps the first name for a repeated id", function()
    local c = ns.ShapeTitleCatalog({
      { id = 1, name = "Private", known = true },
      { id = 1, name = "Private the Second", known = true },
    })
    assert.equal("Private", c.names[1])
    assert.equal(1, c.count)
    assert.equal(1, c.accountWideCount)
  end)

  it("yields empty tables for an empty scan", function()
    local c = ns.ShapeTitleCatalog({})
    assert.equal(0, c.count)
    assert.equal(0, c.accountWideCount)
    assert.equal(0, count(c.names))
    assert.equal(0, count(c.accountWide))
  end)

  it("tolerates nil rows", function()
    assert.equal(0, ns.ShapeTitleCatalog(nil).count)
  end)

  -- Fresh tables every call, so a title the client no longer reports simply vanishes — there are
  -- no stale keys for a cleanup command to sweep.
  it("drops ids a later scan no longer reports", function()
    local first = ns.ShapeTitleCatalog(rows())
    assert.equal("Corporal", first.names[5])
    local second = ns.ShapeTitleCatalog({ { id = 1, name = "Private", known = true } })
    assert.is_nil(second.names[5])
    assert.is_nil(second.accountWide[77])
    assert.equal(1, second.count)
  end)

  it("carries the provenance meta through verbatim", function()
    local c = ns.ShapeTitleCatalog(rows(), {
      build = "68453", locale = "frFR", scannedAt = 1753300000, scannedBy = "Nazuraki",
    })
    assert.equal("68453", c.build)
    assert.equal("frFR", c.locale)
    assert.equal(1753300000, c.scannedAt)
    assert.equal("Nazuraki", c.scannedBy)
  end)

  it("tolerates missing meta", function()
    local c = ns.ShapeTitleCatalog(rows())
    assert.is_nil(c.build)
    assert.is_nil(c.scannedBy)
    assert.equal(4, c.count)
  end)
end)
