-- data/stats.lua reads live combat-rating APIs. Its load-time WoW touches are plain locals of
-- globals, so the chunk is loaded with a stub environment whose readers pull from `reading`, which a
-- test rewrites between calls. The string "secret" stands in for a secret value (canaccessvalue
-- refuses it), which is how a COMBAT_RATING_UPDATE read in combat looks to addon code.
describe("Warbandeer_Characters stats secondary", function()
  local reading, secondary

  before_each(function()
    reading = {}
    local env = {
      CR_CRIT_MELEE = "crit", CR_HASTE_MELEE = "haste", CR_MASTERY = "mastery",
      CR_VERSATILITY_DAMAGE_DONE = "vers",
      canaccessvalue = function(v) return v ~= "secret" end,
      GetCritChance = function() return reading.critPct end,
      GetHaste = function() return reading.hastePct end,
      GetMasteryEffect = function() return reading.masteryPct end,
      GetCombatRating = function(cr) return reading[cr] end,
      GetCombatRatingBonus = function() return reading.versPct end,
      C_SpecializationInfo = { GetSpecialization = function() return nil end },
    }
    setmetatable(env, { __index = _G })
    local broker
    local ns = {
      RegisterBroker = function() broker = {}; return broker end,
      registerEvent = function() end,
    }
    local chunk = assert(loadfile("Warbandeer_Characters/data/stats.lua"))
    setfenv(chunk, env)
    chunk("Warbandeer_Characters", ns)
    secondary = broker.fields.secondary
  end)

  local function read(current) return secondary.get(nil, nil, current) end

  it("stores every readable value", function()
    reading = { critPct = 20, crit = 400, hastePct = 10, haste = 300, masteryPct = 30,
                mastery = 500, versPct = 5, vers = 200 }
    local s = read(nil)
    assert.equal(20, s.crit.pct)
    assert.equal(400, s.crit.rating)
    assert.equal(30, s.mastery.pct)
    assert.equal(200, s.versatility.rating)
  end)

  it("keeps the previous values when the read is secret", function()
    reading = { critPct = 20, crit = 400, hastePct = 10, haste = 300, masteryPct = 30,
                mastery = 500, versPct = 5, vers = 200 }
    local good = read(nil)
    reading = { critPct = "secret", crit = "secret", hastePct = "secret", haste = "secret",
                masteryPct = "secret", mastery = "secret", versPct = "secret", vers = "secret" }
    assert.same(good, read(good))
  end)

  it("replaces only the stats that read cleanly", function()
    reading = { critPct = 20, crit = 400, hastePct = 10, haste = 300, masteryPct = 30,
                mastery = 500, versPct = 5, vers = 200 }
    local good = read(nil)
    reading = { critPct = 25, crit = "secret", hastePct = "secret", haste = 350, masteryPct = 31,
                mastery = 510, versPct = "secret", vers = 210 }
    local s = read(good)
    assert.equal(25, s.crit.pct)
    assert.equal(400, s.crit.rating)
    assert.equal(10, s.haste.pct)
    assert.equal(350, s.haste.rating)
    assert.equal(5, s.versatility.pct)
    assert.equal(210, s.versatility.rating)
  end)

  it("stores nil for a secret value that has no previous reading", function()
    reading = { critPct = "secret", crit = "secret" }
    local s = read(nil)
    assert.is_nil(s.crit.pct)
    assert.is_nil(s.crit.rating)
  end)
end)
