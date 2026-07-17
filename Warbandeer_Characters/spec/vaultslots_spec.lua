local wbchar = require("Warbandeer_Characters.spec.wbchar")

describe("Warbandeer_Characters ns.SummarizeVaultSlots", function()
  local ns
  before_each(function() ns = wbchar.load() end)

  -- A full raid track (2/4/6) with the top slot still locked, one M+ slot, one world slot, and an
  -- unknown activity type that must be ignored. Raid slots are given out of threshold order to prove
  -- the summariser sorts them.
  local function activities()
    return {
      { type = 3, threshold = 4, progress = 5, ilvl = 658 },
      { type = 3, threshold = 2, progress = 5, ilvl = 652 },
      { type = 3, threshold = 6, progress = 5 },
      { type = 1, threshold = 1, progress = 3, ilvl = 662 },
      { type = 6, threshold = 2, progress = 1 },
      { type = 99, threshold = 1, progress = 1 },
    }
  end

  it("buckets activities into named tracks and drops unknown types", function()
    local t = ns.SummarizeVaultSlots(activities())
    assert.is_table(t.Raid)
    assert.is_table(t.Dungeons)
    assert.is_table(t.World)
    assert.equal(3, #t.Raid)
    assert.equal(1, #t.Dungeons)
    assert.equal(1, #t.World)
  end)

  it("orders a track's slots by ascending threshold", function()
    local raid = ns.SummarizeVaultSlots(activities()).Raid
    assert.same({ threshold = 2, progress = 5, complete = true,  ilvl = 652 }, raid[1])
    assert.same({ threshold = 4, progress = 5, complete = true,  ilvl = 658 }, raid[2])
    assert.same({ threshold = 6, progress = 5, complete = false             }, raid[3])
  end)

  it("flags a slot complete only when progress reaches its threshold", function()
    local raid = ns.SummarizeVaultSlots(activities()).Raid
    assert.is_true(raid[2].complete)
    assert.is_false(raid[3].complete)
  end)

  it("keeps the reward ilvl only on unlocked slots", function()
    local raid = ns.SummarizeVaultSlots(activities()).Raid
    assert.equal(658, raid[2].ilvl)
    assert.is_nil(raid[3].ilvl)
  end)

  it("returns an empty table for no activities", function()
    assert.same({}, ns.SummarizeVaultSlots({}))
  end)
end)

describe("Warbandeer_Characters ns.RaidLocks", function()
  local ns
  before_each(function() ns = wbchar.load() end)

  local function locks()
    return {
      [1200] = {
        [15] = { name = "Manaforge",  total = 8, progress = 6, isRaid = true, reset = 500 },
        [14] = { name = "Manaforge",  total = 8, progress = 8, isRaid = true, reset = 400 },
      },
      [1300] = {
        [16] = { name = "Liberation", total = 9, progress = 3, isRaid = true, reset = 600 },
      },
      [1400] = {
        [2]  = { name = "Some Dungeon", total = 5, progress = 5, isRaid = false, reset = 700 },
      },
    }
  end

  it("returns raid lockouts only, excluding dungeon locks", function()
    local out = ns.RaidLocks(locks())
    assert.equal(3, #out)
    for _, l in ipairs(out) do assert.not_equal("Some Dungeon", l.name) end
  end)

  it("sorts most-prestigious first, then most-progressed", function()
    local out = ns.RaidLocks(locks())
    assert.equal("Liberation", out[1].name); assert.equal("M", out[1].label)
    assert.equal("Manaforge",  out[2].name); assert.equal("H", out[2].label)
    assert.equal("Manaforge",  out[3].name); assert.equal("N", out[3].label)
  end)

  it("breaks a rank+progress tie alphabetically by name", function()
    local out = ns.RaidLocks({
      [1] = { [16] = { name = "Zephyr", total = 8, progress = 4, isRaid = true } },
      [2] = { [16] = { name = "Aegis",  total = 8, progress = 4, isRaid = true } },
    })
    assert.equal("Aegis",  out[1].name)
    assert.equal("Zephyr", out[2].name)
  end)

  it("defaults missing progress/total to 0", function()
    local out = ns.RaidLocks({ [1] = { [14] = { name = "Ruins", isRaid = true } } })
    assert.equal(0, out[1].progress)
    assert.equal(0, out[1].total)
  end)

  it("returns an empty list for nil locks", function()
    assert.same({}, ns.RaidLocks(nil))
  end)
end)
