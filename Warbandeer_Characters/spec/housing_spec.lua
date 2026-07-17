local wbchar = require("Warbandeer_Characters.spec.wbchar")

describe("Warbandeer_Characters ns.ShapeHousing", function()
  local ns
  before_each(function() ns = wbchar.load() end)

  local A, H = "nb-alliance", "nb-horde"
  local function nbhds()
    return {
      [A] = { isAlliance = true,  title = "Reaching Beyond the Possible" },
      [H] = { isAlliance = false, title = "Consortium Consternation" },
    }
  end

  it("resolves an Alliance active endeavor with its title", function()
    local s = ns.ShapeHousing(A, nbhds())
    assert.equal("alliance", s.active)
    assert.equal("Reaching Beyond the Possible", s.title)
  end)

  it("resolves a Horde active endeavor", function()
    assert.equal("horde", ns.ShapeHousing(H, nbhds()).active)
  end)

  it("is nil when the active neighborhood is unknown", function()
    assert.is_nil(ns.ShapeHousing("nb-unknown", nbhds()))
  end)

  it("is nil when there is no active neighborhood", function()
    assert.is_nil(ns.ShapeHousing(nil, nbhds()))
  end)

  it("is nil when the neighborhood's faction is unresolved", function()
    assert.is_nil(ns.ShapeHousing(A, { [A] = { title = "x" } }))
  end)

  it("tolerates a nil neighborhood map", function()
    assert.is_nil(ns.ShapeHousing(A, nil))
  end)
end)

describe("Warbandeer_Characters ns.ShapeHouses", function()
  local ns
  before_each(function() ns = wbchar.load() end)

  local AN, HN = "nb-alliance", "nb-horde"
  local function neighborhoods()
    return {
      [AN] = { isAlliance = true,  title = "Reaching Beyond the Possible", progress = 224, required = 1000, resetAt = 500, xp = 5927 },
      [HN] = { isAlliance = false, title = "Consortium Consternation",     progress = 519, required = 1000, resetAt = 600, xp = 6660 },
    }
  end
  local function houses()
    return {
      ["house-a"] = { neighborhoodGUID = AN, name = "7 We Know This Too",        level = 9, favor = 19033 },
      ["house-h"] = { neighborhoodGUID = HN, name = "15 Iron Gravel Cornucopia", level = 9, favor = 18300 },
    }
  end

  it("joins each house with its neighborhood by faction", function()
    local v = ns.ShapeHouses(houses(), neighborhoods())
    assert.equal("7 We Know This Too", v.alliance.name)
    assert.equal(9, v.alliance.level)
    assert.equal(19033, v.alliance.favor)
    assert.equal("Reaching Beyond the Possible", v.alliance.title)
    assert.equal(224, v.alliance.progress)
    assert.equal(1000, v.alliance.required)
    assert.equal(500, v.alliance.resetAt)
    assert.equal(5927, v.alliance.xp)
    assert.equal(18300, v.horde.favor)
    assert.equal(6660, v.horde.xp)
    assert.equal("Consortium Consternation", v.horde.title)
  end)

  it("omits a house whose neighborhood faction is unresolved", function()
    local nb = neighborhoods(); nb[AN].isAlliance = nil
    local v = ns.ShapeHouses(houses(), nb)
    assert.is_nil(v.alliance)
    assert.is_table(v.horde)
  end)

  it("returns an empty table when nothing is captured", function()
    assert.same({}, ns.ShapeHouses(nil, nil))
    assert.same({}, ns.ShapeHouses({}, {}))
  end)
end)
