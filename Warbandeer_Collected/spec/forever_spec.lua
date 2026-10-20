local collected = require("Warbandeer_Collected.spec.collected")

-- Warbandeer_Collected on WoW: Forever (nazumods/wow#989). Forever's rows (data/sets_forever.lua) are
-- `allClasses`: one set any class can wear, repeated in all 13 class columns. Every tally has to count
-- such a row's set once, and Retail rows (which never carry the flag) must count exactly as before.
-- The "no appearance data" wording is the other Forever difference: there is no PTR there to point at.

-- A Forever-shaped row: set `id` in every class column, flagged allClasses.
local function foreverRow(id)
  local sets = {}
  for c = 1, 13 do sets[c] = { id = id, name = "Forever " .. id, classId = c } end
  return { id = id, name = "Forever " .. id, release = 1, category = "World", allClasses = true, sets = sets }
end

local function view()
  return { _ptr = false, _wantedOnly = false, _expansion = "all", _category = "all", embedded = false, _reverse = true }
end

describe("Warbandeer_Collected on Forever", function()
  local ns

  before_each(function()
    ns = collected.loadDataViewData(collected.load())
  end)

  describe("ns.DistinctSets", function()
    it("returns a Retail row's own sets, every cell", function()
      local grp = { id = 1, sets = { { id = 1 }, {}, { id = 3 } } }
      assert.equals(grp.sets, ns.DistinctSets(grp))
    end)

    it("returns an allClasses row's set once", function()
      local grp = foreverRow(5700)
      local distinct = ns.DistinctSets(grp)
      assert.equals(1, #distinct)
      assert.equals(grp.sets[1], distinct[1])
    end)

    it("skips leading empty cells, and gives nothing for an allClasses row with no set", function()
      assert.same({ { id = 9 } }, ns.DistinctSets({ allClasses = true, sets = { {}, { id = 9 } } }))
      assert.same({}, ns.DistinctSets({ allClasses = true, sets = { {} } }))
    end)
  end)

  describe("DataView:VisibleCounts", function()
    it("counts a collected allClasses row as one cell, one complete", function()
      ns.Sets = { foreverRow(5700) }
      ns.db.sets = { [5700] = { [5700] = true } }
      local sets, cells, green = ns.DataView.VisibleCounts(view())
      assert.same({ 1, 1, 1 }, { sets, cells, green })
    end)

    it("counts a Retail row per class cell, as before", function()
      ns.Sets = { { id = 100, name = "Tier", release = 12, category = "Raid",
                    sets = { { id = 1 }, { id = 2 }, { id = 3 } } } }
      ns.db.sets = { [100] = { [1] = true, [2] = { collected = 1, total = 5 }, [3] = true } }
      local sets, cells, green = ns.DataView.VisibleCounts(view())
      assert.same({ 1, 3, 2 }, { sets, cells, green })
    end)
  end)

  describe("ns.SetGroupInfo", function()
    it("reports an allClasses row as one set, its pieces once, and a wanted flag once", function()
      local grp = foreverRow(5700)
      ns.db.sets = { [5700] = { [5700] = { collected = 2, total = 6 } } }
      ns.db.wanted[5700] = true
      local lines = ns.SetGroupInfo(grp)
      assert.equals("0/1 sets complete", lines[1])
      assert.equals("2/6 appearances collected", lines[2])
      assert.is_not_nil(lines[3]:find(" 1 wanted", 1, true))
    end)

    it("still says class sets on a Retail row", function()
      local grp = { id = 100, sets = { { id = 1 }, { id = 2 } } }
      ns.db.sets = { [100] = { [1] = true, [2] = true } }
      assert.equals("2/2 class sets complete", ns.SetGroupInfo(grp)[1])
    end)
  end)

  describe("the no-sources wording", function()
    it("points a Retail client at the PTR", function()
      ns.flavor = { isRetail = true }
      assert.equals("|cff8cc8ffNot yet on live (PTR)|r", ns.NoSourcesStatus())
      assert.is_not_nil(ns.NoSourcesMessage("Tier"):find("upcoming on the PTR", 1, true))
    end)

    it("says only that Forever has no data, never PTR", function()
      ns.flavor = { isForever = true }
      assert.is_nil(ns.NoSourcesStatus():find("PTR", 1, true))
      assert.is_nil(ns.NoSourcesMessage("Tier"):find("PTR", 1, true))
      assert.is_not_nil(ns.NoSourcesMessage("Tier"):find('"Tier" has no appearance data', 1, true))
    end)
  end)

  -- data/forever.lua: the Retail weapon PTR delta means nothing on Forever (it has no PTR), so it is
  -- emptied there, the way data/sets_forever.lua empties the armour delta. Loaded for real.
  describe("data/forever.lua", function()
    local function loadAs(flavor)
      local sources, build = { { id = 1 } }, { live = "12.1.5.70391", ptr = "12.1.7.70424" }
      local env = { flavor = flavor, WeaponPtrSources = sources, WeaponPtrBuild = build }
      assert(loadfile("Warbandeer_Collected/data/forever.lua"))("Warbandeer_Collected", env)
      return env, sources, build
    end

    it("leaves the weapon PTR delta alone on Retail", function()
      local env, sources, build = loadAs({ isRetail = true })
      assert.equals(sources, env.WeaponPtrSources)
      assert.equals(build, env.WeaponPtrBuild)
    end)

    it("empties the weapon PTR delta and its build on Forever", function()
      local env = loadAs({ isForever = true })
      assert.same({}, env.WeaponPtrSources)
      assert.is_nil(env.WeaponPtrBuild)
    end)
  end)

  -- The two call sites are frame-bound (no spec loads them), so they are pinned by their source text:
  -- each goes through the flavor-aware helper, and the Retail PTR literals now live only in
  -- data/setpieces.lua. Reverting either call site to its old literal fails here.
  describe("the no-sources call sites", function()
    local function source(file)
      local f = assert(io.open("Warbandeer_Collected/" .. file, "r"))
      local text = f:read("*a")
      f:close()
      return text
    end

    it("the armour tooltip uses ns.NoSourcesStatus, not the PTR literal", function()
      local text = source("controls/InfoTipArmor.lua")
      assert.is_not_nil(text:find("ns.NoSourcesStatus()", 1, true))
      assert.is_nil(text:find("Not yet on live (PTR)", 1, true))
    end)

    it("the dressing room uses ns.NoSourcesMessage, not the PTR literal", function()
      local text = source("controls/DressingRoomModel.lua")
      assert.is_not_nil(text:find("ns.Print(ns.NoSourcesMessage(", 1, true))
      assert.is_nil(text:find("is upcoming on the PTR", 1, true))
    end)
  end)
end)
