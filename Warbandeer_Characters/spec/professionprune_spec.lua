-- /wbc cleanup professions (#1049): stale crafting/gathering data is removed only by the explicit `apply`
-- argument, never for Archaeology or unknown keys, and never for a character whose professions snapshot
-- is partial or unconfirmed.

-- luacheck: globals describe it before_each

local function load(live)
  local ns = { db = { characters = {} }, printed = {}, currentPlayer = "Old" }
  ns.Print = function(msg) ns.printed[#ns.printed + 1] = msg end
  ns.registerCommand = function(_, cmd, sub, handler) ns.cmd = { cmd = cmd, sub = sub, handler = handler } end
  local function slot(id) return { GetInfo = function() return id and { skillID = id } or nil end } end
  ns.wow = { Player = { GetProfessions = function()
    live = live or { 171, 164 }
    return { prof1 = slot(live[1]), prof2 = slot(live[2]) }
  end } }
  assert(loadfile("Warbandeer_Characters/data/professionprune.lua"))("Warbandeer_Characters", ns)
  return ns
end

local function toon()
  return {
    basic = { professions = { primary = { skillID = 171 }, secondary = { skillID = 164 }, cooking = { skillID = 185 } } },
    professions = { details = { [171] = { r = 1 }, [164] = { r = 2 }, [333] = { r = 3 } }, gear = { [333] = {}, [171] = {} } },
    concentration = { data = { [171] = {}, [165] = {} } },
    artisanCurrency = { data = { [333] = {} } },
    professionKnowledge = { data = { [164] = {}, [773] = {} } },
  }
end

describe("ns.PruneProfessionData (#1049)", function()
  local ns

  before_each(function() ns = load() end)

  it("registers as `cleanup professions` (a subcommand, so plain /wbc cleanup is unchanged)", function()
    assert.equal("cleanup", ns.cmd.cmd)
    assert.equal("professions", ns.cmd.sub)
  end)

  it("removes entries for crafting skill lines the character no longer has, across all five stores", function()
    local t = toon()
    local removed, skipped = ns.PruneProfessionData(t, true)
    assert.is_false(skipped)
    assert.equal(5, removed) -- details 333, gear 333, concentration 165, artisan 333, knowledge 773
    assert.is_nil(t.professions.details[333])
    assert.is_nil(t.professions.gear[333])
    assert.is_nil(t.concentration.data[165])
    assert.is_nil(t.artisanCurrency.data[333])
    assert.is_nil(t.professionKnowledge.data[773])
  end)

  it("keeps the data for professions still held, including cooking", function()
    local t = toon()
    ns.PruneProfessionData(t, true)
    assert.is_not_nil(t.professions.details[171])
    assert.is_not_nil(t.professions.details[164])
    assert.is_not_nil(t.professions.gear[171])
    assert.is_not_nil(t.concentration.data[171])
    assert.is_not_nil(t.professionKnowledge.data[164])
    local c = toon()
    c.professions.details[185] = {}
    ns.PruneProfessionData(c, true)
    assert.is_not_nil(c.professions.details[185])
  end)

  it("never touches Archaeology gear or an unknown key, held or not", function()
    local t = toon()
    t.professions.gear[794] = { arch = true } -- Archaeology: written by the gear scan, absent from basic.professions
    t.professions.details[99999] = { unknown = true }
    t.professionKnowledge.data[12345] = {}
    ns.PruneProfessionData(t, true)
    assert.is_not_nil(t.professions.gear[794])
    assert.is_not_nil(t.professions.details[99999])
    assert.is_not_nil(t.professionKnowledge.data[12345])
  end)

  it("with apply=false it only counts", function()
    local t = toon()
    local removed = ns.PruneProfessionData(t, false)
    assert.equal(5, removed)
    assert.is_not_nil(t.professions.details[333])
  end)

  it("skips a character whose professions were never captured", function()
    local t = toon()
    t.basic = nil
    local removed, skipped = ns.PruneProfessionData(t, true)
    assert.equal(0, removed)
    assert.is_true(skipped)
    assert.is_not_nil(t.professions.details[333])
  end)

  it("skips a snapshot with only cooking/fishing (primaries read empty)", function()
    local t = toon()
    t.basic.professions = { fishing = { skillID = 356 }, cooking = { skillID = 185 } }
    local removed, skipped = ns.PruneProfessionData(t, true)
    assert.is_true(skipped)
    assert.equal(0, removed)
    assert.is_not_nil(t.professions.details[171])
  end)

  it("skips a snapshot with a slot table that has no skillID (half-loaded read)", function()
    local t = toon()
    t.basic.professions.secondary = {}
    local removed, skipped = ns.PruneProfessionData(t, true)
    assert.is_true(skipped)
    assert.equal(0, removed)
    assert.is_not_nil(t.professions.details[164])
  end)

  it("with a live read: skips if the client shows no main profession, and counts what it holds as held", function()
    local t = toon()
    assert.is_true(select(2, ns.PruneProfessionData(t, true, {})))
    assert.is_not_nil(t.professions.details[333])
    -- live shows Enchanting (333) although the snapshot lacks it: it is kept
    local removed = ns.PruneProfessionData(t, true, { [171] = true, [333] = true })
    assert.is_not_nil(t.professions.details[333])
    assert.equal(2, removed) -- concentration 165, knowledge 773
  end)

  it("tolerates a character with none of the stores", function()
    local t = { basic = { professions = { primary = { skillID = 171 } } } }
    assert.equal(0, (ns.PruneProfessionData(t, true)))
  end)
end)

describe("/wbc cleanup professions command (#1049)", function()
  local ns

  local function joined() return table.concat(ns.printed, "\n") end

  before_each(function()
    ns = load()
    ns.db.characters = { Old = toon(), Fresh = { basic = nil }, Clean = { basic = { professions = { primary = { skillID = 171 } } } } }
  end)

  it("no argument is a preview: reports, deletes nothing, says how to apply", function()
    ns.cmd.handler(ns, "")
    assert.is_not_nil(ns.db.characters.Old.professions.details[333])
    assert.is_true(joined():find("Old: would remove 5", 1, true) ~= nil)
    assert.is_true(joined():find("Fresh", 1, true) ~= nil) -- listed as skipped
    assert.is_true(joined():find("professions apply", 1, true) ~= nil)
  end)

  it("`preview` is a preview", function()
    ns.cmd.handler(ns, "preview")
    assert.is_not_nil(ns.db.characters.Old.professions.details[333])
  end)

  for _, typo in ipairs({ "previw", "Preview", "preview ", "--preview", "APPLY", "apply ", "yes" }) do
    it("`" .. typo .. "` deletes nothing and prints usage", function()
      ns.cmd.handler(ns, typo)
      assert.is_not_nil(ns.db.characters.Old.professions.details[333])
      assert.is_true(ns.printed[1]:find("Usage", 1, true) ~= nil)
    end)
  end

  it("`apply` deletes, leaving a character with nothing stale and an unscanned one alone", function()
    ns.cmd.handler(ns, "apply")
    assert.is_nil(ns.db.characters.Old.professions.details[333])
    assert.is_true(joined():find("Old: removed 5", 1, true) ~= nil)
    assert.is_nil(joined():find("Clean:", 1, true))
  end)

  it("cross-checks the logged-in character against the live client: no main profession live, nothing deleted", function()
    ns = load({ nil, nil })
    ns.db.characters = { Old = toon() }
    ns.cmd.handler(ns, "apply")
    assert.is_not_nil(ns.db.characters.Old.professions.details[333])
    assert.is_true(joined():find("Skipped", 1, true) ~= nil)
  end)

  it("says so when nothing is stale", function()
    ns.db.characters = { Clean = { basic = { professions = { primary = { skillID = 171 } } } } }
    ns.cmd.handler(ns, "apply")
    assert.equal("No stale profession data.", ns.printed[1])
  end)
end)
