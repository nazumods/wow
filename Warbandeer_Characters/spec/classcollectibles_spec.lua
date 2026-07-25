local wbchar = require("Warbandeer_Characters.spec.wbchar")

describe("Warbandeer_Characters ns.ShapeClassCollectibles", function()
  local ns
  before_each(function() ns = wbchar.load() end)

  local function rows()
    return {
      quests = {
        { id = 32326, done = true },    -- green fire earned
        { id = 32295, done = true },    -- ...its startQuest, travelling alongside it
        { id = 76370, done = false },   -- a Grimoire the account hasn't unlocked
        { id = 62677 },                 -- done omitted entirely
      },
      mounts = {
        { itemID = 142232, collected = true },    -- Warrior class mount, owned
        { itemID = 143502, collected = false },   -- resolved, not owned
        { spellID = 229376, collected = true },   -- spell-keyed, owned
        { itemID = 47179 },                       -- cold item: id didn't resolve
      },
    }
  end

  local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
  end

  it("keys completed unlock quests by quest id", function()
    local c = ns.ShapeClassCollectibles(rows())
    assert.is_true(c.quests[32326])
    assert.is_true(c.quests[32295])
    assert.equal(2, count(c.quests))
  end)

  -- Absent, not `false`: an untouched account must not serialise a key per catalog quest.
  it("omits uncompleted quests rather than storing false", function()
    local c = ns.ShapeClassCollectibles(rows())
    assert.is_nil(c.quests[76370])
    assert.is_nil(c.quests[62677])
  end)

  it("files spell-keyed and item-keyed mounts in their own map", function()
    local c = ns.ShapeClassCollectibles(rows())
    assert.is_true(c.mounts.items[142232])
    assert.is_true(c.mounts.spells[229376])
    assert.is_nil(c.mounts.spells[142232])
    assert.is_nil(c.mounts.items[229376])
  end)

  -- A spellID and an itemID could collide numerically; the two maps keep them apart, and a row
  -- carrying both resolves as spell-keyed (matching GetClassMounts' resolution order).
  it("keeps a colliding spell and item id independent", function()
    local c = ns.ShapeClassCollectibles({ mounts = {
      { spellID = 999, collected = true },
      { itemID = 999, collected = false },
    } })
    assert.is_true(c.mounts.spells[999])
    assert.is_false(c.mounts.items[999])
  end)

  it("prefers the spell id when a row carries both", function()
    local c = ns.ShapeClassCollectibles({ mounts = { { spellID = 48778, itemID = 40775, collected = true } } })
    assert.is_true(c.mounts.spells[48778])
    assert.is_nil(c.mounts.items[40775])
  end)

  it("stores false for a mount that resolved but isn't collected", function()
    local c = ns.ShapeClassCollectibles(rows())
    assert.is_false(c.mounts.items[143502])
  end)

  -- The cold-item race: GetMountFromItem reads nil until the item's data loads. That must persist as
  -- UNKNOWN (absent), never as a false "not collected" the offline reader would render as missing.
  it("leaves an unresolved mount absent instead of storing false", function()
    local c = ns.ShapeClassCollectibles(rows())
    assert.is_nil(c.mounts.items[47179])
    assert.equal(1, c.mountUnresolved)
  end)

  it("reports the three counts", function()
    local c = ns.ShapeClassCollectibles(rows())
    assert.equal(2, c.questCount)
    assert.equal(2, c.mountCount)
    assert.equal(1, c.mountUnresolved)
  end)

  it("drops rows with no usable id", function()
    local c = ns.ShapeClassCollectibles({
      quests = { { done = true }, { id = 1, done = true } },
      mounts = { { collected = true }, { itemID = 2, collected = true } },
    })
    assert.equal(1, c.questCount)
    assert.equal(1, c.mountCount)
    assert.equal(0, c.mountUnresolved)
  end)

  -- First row for an id wins, so a repeated entry can't drift a count from its table size.
  it("keeps the first answer for a repeated id", function()
    local c = ns.ShapeClassCollectibles({
      quests = { { id = 1, done = true }, { id = 1, done = true } },
      mounts = { { itemID = 2, collected = true }, { itemID = 2, collected = false } },
    })
    assert.equal(1, c.questCount)
    assert.is_true(c.mounts.items[2])
    assert.equal(1, c.mountCount)
  end)

  it("counts a repeated unresolved id once", function()
    local c = ns.ShapeClassCollectibles({ mounts = { { itemID = 2 }, { itemID = 2 } } })
    assert.equal(1, c.mountUnresolved)
    assert.equal(0, c.mountCount)
  end)

  it("yields empty tables for an empty scan", function()
    local c = ns.ShapeClassCollectibles({ quests = {}, mounts = {} })
    assert.equal(0, c.questCount)
    assert.equal(0, c.mountCount)
    assert.equal(0, c.mountUnresolved)
    assert.equal(0, count(c.quests))
    assert.equal(0, count(c.mounts.spells))
    assert.equal(0, count(c.mounts.items))
  end)

  it("tolerates nil rows and missing sections", function()
    assert.equal(0, ns.ShapeClassCollectibles(nil).questCount)
    assert.equal(0, ns.ShapeClassCollectibles({}).mountCount)
    assert.equal(0, count(ns.ShapeClassCollectibles({ mounts = { { itemID = 1, collected = true } } }).quests))
  end)

  -- Fresh tables every call, so an id a later scan no longer reports simply vanishes — there are no
  -- stale keys for a cleanup command to sweep.
  it("drops ids a later scan no longer reports", function()
    local first = ns.ShapeClassCollectibles(rows())
    assert.is_true(first.quests[32326])
    local second = ns.ShapeClassCollectibles({ mounts = { { spellID = 229376, collected = true } } })
    assert.is_nil(second.quests[32326])
    assert.is_nil(second.mounts.items[142232])
    assert.equal(0, second.questCount)
    assert.equal(1, second.mountCount)
  end)

  it("carries the provenance meta through verbatim", function()
    local c = ns.ShapeClassCollectibles(rows(), {
      build = "68453", scannedAt = 1753300000, scannedBy = "Nazuraki",
    })
    assert.equal("68453", c.build)
    assert.equal(1753300000, c.scannedAt)
    assert.equal("Nazuraki", c.scannedBy)
  end)

  it("tolerates missing meta", function()
    local c = ns.ShapeClassCollectibles(rows())
    assert.is_nil(c.build)
    assert.is_nil(c.scannedAt)
    assert.is_nil(c.scannedBy)
    assert.equal(2, c.questCount)
  end)
end)
