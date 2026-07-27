local collected = require("Warbandeer_Collected.spec.collected")

-- The filtering both grids share (GridShared.lua). These were byte-identical copies in the armor
-- and weapon data/filter files until #770 step 1; the point of covering them is that one shared
-- implementation now decides which rows EVERY grid shows, so a change here is a change to both.

describe("grid filtering", function()
  local ns

  before_each(function()
    ns = collected.loadGridShared(collected.load())
  end)

  describe("GridMatches", function()
    local grp = { release = 10, category = "Raid" }

    it("passes everything when no filter is set", function()
      assert.is_true(ns.GridMatches({ _expansion = "all", _category = "all" }, grp))
    end)

    it("filters by expansion", function()
      assert.is_true(ns.GridMatches({ _expansion = 10, _category = "all" }, grp))
      assert.is_false(ns.GridMatches({ _expansion = 9, _category = "all" }, grp))
    end)

    it("filters by category", function()
      assert.is_true(ns.GridMatches({ _expansion = "all", _category = "Raid" }, grp))
      assert.is_false(ns.GridMatches({ _expansion = "all", _category = "Dungeon" }, grp))
    end)

    it("requires BOTH filters to pass, not either", function()
      assert.is_false(ns.GridMatches({ _expansion = 9, _category = "Raid" }, grp))
      assert.is_false(ns.GridMatches({ _expansion = 10, _category = "Dungeon" }, grp))
      assert.is_true(ns.GridMatches({ _expansion = 10, _category = "Raid" }, grp))
    end)

    -- PTR preview is a small upcoming-only list with no category, so the dropdowns are meant to
    -- apply to the live grid only. Filtering it would silently empty the preview.
    it("ignores every filter under PTR preview", function()
      assert.is_true(ns.GridMatches({ _ptr = true, _expansion = 9, _category = "Dungeon" }, grp))
    end)

    -- A group with no category still has to survive "no category filter", or rows would vanish
    -- from the unfiltered grid.
    it("keeps a group with no category while the filter is off", function()
      assert.is_true(ns.GridMatches({ _expansion = "all", _category = "all" }, { release = 1 }))
      assert.is_false(ns.GridMatches({ _expansion = "all", _category = "Raid" }, { release = 1 }))
    end)
  end)

  describe("CategoryOptions", function()
    local function keys(opts)
      local out = {}
      for i, o in ipairs(opts) do out[i] = o.key end
      return out
    end

    it("leads with All and lists present categories in the given order", function()
      local source = { { category = "Dungeon" }, { category = "Raid" } }
      assert.same({ "all", "Raid", "Dungeon" }, keys(ns.CategoryOptions(source, { "Raid", "Dungeon" })))
    end)

    it("omits ordered categories that aren't present", function()
      local source = { { category = "Raid" } }
      assert.same({ "all", "Raid" }, keys(ns.CategoryOptions(source, { "Raid", "PvP", "Delve" })))
    end)

    it("deduplicates a category shared by many rows", function()
      local source = { { category = "Raid" }, { category = "Raid" }, { category = "Raid" } }
      assert.same({ "all", "Raid" }, keys(ns.CategoryOptions(source, { "Raid" })))
    end)

    -- The point of the trailing pass: the data files gain categories without the filter's ordering
    -- list being touched, and a dropped one would be invisible — the rows simply couldn't be found.
    it("appends a present category missing from the order rather than dropping it", function()
      local source = { { category = "Raid" }, { category = "Newthing" } }
      local got = keys(ns.CategoryOptions(source, { "Raid" }))
      assert.equal(3, #got)
      assert.same({ "all", "Raid" }, { got[1], got[2] })
      assert.equal("Newthing", got[3])
    end)

    it("ignores rows carrying no category", function()
      local source = { { category = "Raid" }, {}, { category = "Raid" } }
      assert.same({ "all", "Raid" }, keys(ns.CategoryOptions(source, { "Raid" })))
    end)

    it("still offers All for an empty source", function()
      assert.same({ "all" }, keys(ns.CategoryOptions({}, { "Raid" })))
    end)
  end)
end)
