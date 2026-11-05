-- The API hands out the plain character name for labels while the db key can be "Name-Realm" (#1013).

-- luacheck: globals describe it GetServerTime

describe("API:GetItemCounts names (#1013)", function()
  local ns

  before_each(function()
    local saved = _G.GetServerTime
    _G.GetServerTime = function() return 1000 end
    ns = { api = {}, db = {} }
    assert(loadfile("Warbandeer_Characters/api.lua"))("Warbandeer_Characters", ns)
    _G.GetServerTime = saved
    ns.currentData = { realm = "Realm A" }
    ns.db.characters = {
      Foo = { classKey = "Mage", realm = "Realm A", displayName = "Foo", inventory = { counts = { [1] = 2 } } },
      ["Foo-RealmB"] = { classKey = "Hunter", realm = "Realm B", displayName = "Foo", inventory = { counts = { [1] = 3 } } },
      Old = { classKey = "Mage", realm = "Realm A", inventory = { counts = { [1] = 1 } } }, -- no displayName yet
    }
  end)

  it("labels a qualified character with its plain name and realm, never the Name-Realm key", function()
    local report = ns.api:GetItemCounts(1)
    local byTotal = {}
    for _, e in ipairs(report.characters) do byTotal[e.total] = e end
    assert.equal("Foo", byTotal[3].name)
    assert.equal("Realm B", byTotal[3].realm)
    assert.equal("Foo", byTotal[2].name)
    assert.is_nil(byTotal[2].realm)
  end)

  it("falls back to the key for a record without a displayName", function()
    local report = ns.api:GetItemCounts(1)
    local names = {}
    for _, e in ipairs(report.characters) do names[#names + 1] = e.name end
    table.sort(names)
    assert.same({ "Foo", "Foo", "Old" }, names)
  end)
end)
