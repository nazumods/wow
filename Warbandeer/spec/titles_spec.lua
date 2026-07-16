local warbandeer = require("Warbandeer.spec.warbandeer")

-- Synthetic universe of five titles (ids are title mask ids — they need not be contiguous).
local function universe()
  return {
    { id = 10, name = "the Explorer" },
    { id = 20, name = "the Insane" },
    { id = 30, name = "the Kingslayer" },
    { id = 40, name = "Battlemaster" },
    { id = 50, name = "Chef" },
  }
end

-- Two characters with overlapping earned lists (the shape TitlesData.gatherCharacters produces).
local function characters()
  return {
    { name = "Alto",   known = { { id = 10, name = "the Explorer" }, { id = 40, name = "Battlemaster" } } },
    { name = "Zephyr", known = { { id = 10, name = "the Explorer" }, { id = 30, name = "the Kingslayer" } } },
  }
end

-- Epithet catalog keyed by titleID (the shape TitlesData.epithetById produces).
local function epithet()
  return {
    [20] = { titleID = 20, q = 5, cat = "Feat of Strength", obtainable = "no" },  -- unearned, gone
    [30] = { titleID = 30, q = 4, cat = "Raid",             obtainable = "yes" }, -- earned already
    [50] = { titleID = 50, q = 2, cat = "Profession",       obtainable = "yes" }, -- unearned + earnable
  }
end

local function byId(list)
  local m = {}
  for _, e in ipairs(list) do m[e.id] = e end
  return m
end

describe("Warbandeer ns.ComputeTitles", function()
  local ns
  before_each(function() ns = warbandeer.load() end)

  it("returns an empty list and zero counts for an empty universe", function()
    local r = ns.ComputeTitles({}, characters(), nil)
    assert.same({}, r.list)
    assert.same({ total = 0, earned = 0, unearned = 0, earnable = 0 }, r.counts)
  end)

  it("tolerates nil universe and nil characters", function()
    local r = ns.ComputeTitles(nil, nil, nil)
    assert.same({}, r.list)
    assert.equal(0, r.counts.total)
  end)

  it("splits earned vs unearned by the warband union", function()
    local r = ns.ComputeTitles(universe(), characters(), nil)
    local m = byId(r.list)
    assert.is_true(m[10].earned)   -- both characters
    assert.is_true(m[30].earned)   -- Zephyr
    assert.is_true(m[40].earned)   -- Alto
    assert.is_false(m[20].earned)  -- nobody
    assert.is_false(m[50].earned)  -- nobody
    assert.equal(3, r.counts.earned)
    assert.equal(2, r.counts.unearned)
    assert.equal(5, r.counts.total)
  end)

  it("lists every owner of a shared title, alphabetically", function()
    local r = ns.ComputeTitles(universe(), characters(), nil)
    local m = byId(r.list)
    assert.same({ "Alto", "Zephyr" }, m[10].owners)
    assert.same({ "Alto" }, m[40].owners)
    assert.same({}, m[20].owners)
  end)

  it("sorts the list by name, then id as a tiebreak", function()
    local r = ns.ComputeTitles(universe(), characters(), nil)
    local names = {}
    for _, e in ipairs(r.list) do names[#names + 1] = e.name end
    assert.same({ "Battlemaster", "Chef", "the Explorer", "the Insane", "the Kingslayer" }, names)
  end)

  it("derives earnable as unearned AND Epithet obtainable == 'yes'", function()
    local r = ns.ComputeTitles(universe(), characters(), epithet())
    local m = byId(r.list)
    assert.is_true(m[50].earnable)   -- unearned + obtainable yes
    assert.is_false(m[30].earnable)  -- obtainable yes but already earned
    assert.is_false(m[20].earnable)  -- unearned but obtainable no
    assert.is_false(m[10].earnable)  -- earned, no epithet entry
    assert.equal(1, r.counts.earnable)
  end)

  it("attaches the matched Epithet entry by titleID", function()
    local r = ns.ComputeTitles(universe(), characters(), epithet())
    local m = byId(r.list)
    assert.equal(5, m[20].epithet.q)
    assert.equal("Profession", m[50].epithet.cat)
    assert.is_nil(m[10].epithet)  -- no catalog entry for id 10
  end)

  it("degrades cleanly without Epithet — no enrichment, nothing earnable", function()
    local r = ns.ComputeTitles(universe(), characters(), nil)
    for _, e in ipairs(r.list) do
      assert.is_nil(e.epithet)
      assert.is_false(e.earnable)
    end
    assert.equal(0, r.counts.earnable)
  end)

  it("treats a character with no known list as owning nothing", function()
    local chars = { { name = "Fresh", known = nil }, { name = "Alto", known = { { id = 10 } } } }
    local r = ns.ComputeTitles(universe(), chars, nil)
    local m = byId(r.list)
    assert.same({ "Alto" }, m[10].owners)
    assert.equal(1, r.counts.earned)
  end)

  it("ignores Epithet entries with no matching universe title", function()
    local ep = { [999] = { titleID = 999, q = 3, obtainable = "yes" } }
    local r = ns.ComputeTitles(universe(), characters(), ep)
    assert.equal(0, r.counts.earnable) -- 999 isn't in the universe, so it can't be earnable
    for _, e in ipairs(r.list) do assert.not_equal(999, e.id) end
  end)
end)
