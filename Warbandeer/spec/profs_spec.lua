-- Professions view aggregation (#910). BFA is the only faction-split profession tier:
-- Alliance trains "Kul Tiran <Prof>", Horde trains "Zandalari <Prof>", and the scanner
-- (Warbandeer_Characters/data/professions.lua) stores each child's `expansionName` verbatim
-- as `exp.name`. ProfsData's EXP_ABBR must map BOTH names to the "BfA" column, or Horde
-- characters' BFA skills fall out of the grid and render as "-".
--
-- ProfsData.lua is not WoW-API-free -- it reads ns.ui/ns.theme at load -- so it can't ride
-- through spec/warbandeer.lua's pure-file loader. Stub the two fields it touches while loading
-- (buildBestSkills/sortCharEntries never use them) and loadfile it into a fresh ns. Both
-- consumers of EXP_ABBR are covered: buildBestSkills (the grid summary) directly, and the
-- char-list sort (entrySkill, a local) through its public entry point sortCharEntries.
local function loadProfs()
  local ns = { ui = {}, theme = { colors = {} } }
  assert(loadfile("Warbandeer/views/profs/ProfsData.lua"))("Warbandeer", ns)
  return ns.profs
end

-- A minimal character in the shape buildBestSkills reads: a `basic.professions` slot naming
-- the profession + its base skillLineID, and `professions.details[skillID].expansions`
-- carrying the per-expansion child skill lines (name = the child's expansionName).
local function toon(name, profName, skillID, expansions)
  return {
    name  = name,
    basic = { professions = { primary = { name = profName, skillID = skillID } } },
    professions = { details = { [skillID] = { expansions = expansions } } },
  }
end

describe("Warbandeer ns.profs BFA faction skill lines (#910)", function()
  local profs
  before_each(function() profs = loadProfs() end)

  it("maps both faction BFA category names to the BfA column", function()
    assert.equal("BfA", profs.EXP_ABBR["Kul Tiran"])  -- Alliance
    assert.equal("BfA", profs.EXP_ABBR["Zandalari"])  -- Horde (#910)
  end)

  it("buckets a Horde 'Zandalari' BFA skill into the BfA column", function()
    local r = profs.buildBestSkills({
      toon("Grukk", "Enchanting", 333, {
        { name = "Zandalari", skillLevel = 175, maxSkillLevel = 200 },
      }),
    })
    assert.same({ best = 175, max = 200 }, r.Enchanting.BfA)
  end)

  it("still buckets an Alliance 'Kul Tiran' BFA skill into the BfA column", function()
    local r = profs.buildBestSkills({
      toon("Lira", "Enchanting", 333, {
        { name = "Kul Tiran", skillLevel = 150, maxSkillLevel = 200 },
      }),
    })
    assert.same({ best = 150, max = 200 }, r.Enchanting.BfA)
  end)

  it("takes the best BFA skill across a Horde + Alliance pair in one column", function()
    local r = profs.buildBestSkills({
      toon("Grukk", "Enchanting", 333, { { name = "Zandalari", skillLevel = 175, maxSkillLevel = 200 } }),
      toon("Lira",  "Enchanting", 333, { { name = "Kul Tiran", skillLevel = 150, maxSkillLevel = 200 } }),
    })
    assert.equal(175, r.Enchanting.BfA.best)
  end)

  it("ranks a Horde 'Zandalari' BFA skill by value when sorting the BfA column", function()
    -- sortCharEntries reads EXP_ABBR via its local entrySkill; a Zandalari tier must sort
    -- by its skill level, so Horde 175 outranks Alliance 150 under a descending BfA sort.
    local entries = {
      { toon = { name = "Amy" }, detail = { expansions = { { name = "Kul Tiran", skillLevel = 150 } } } },
      { toon = { name = "Zed" }, detail = { expansions = { { name = "Zandalari", skillLevel = 175 } } } },
    }
    profs.sortCharEntries(entries, "BfA", true)
    assert.equal("Zed", entries[1].toon.name)
    assert.equal("Amy", entries[2].toon.name)
  end)

  it("sorts a character with no BFA tier below one with a Zandalari BFA skill", function()
    -- A Zandalari skill must count as a real value (not "missing"), so it outranks an
    -- untrained character even though the name tiebreak would otherwise reverse them.
    local entries = {
      { toon = { name = "Nay" }, detail = { expansions = {} } },
      { toon = { name = "Zed" }, detail = { expansions = { { name = "Zandalari", skillLevel = 175 } } } },
    }
    profs.sortCharEntries(entries, "BfA", true)
    assert.equal("Zed", entries[1].toon.name)
    assert.equal("Nay", entries[2].toon.name)
  end)
end)
