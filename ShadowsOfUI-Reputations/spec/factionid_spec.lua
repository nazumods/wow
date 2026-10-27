local reputations = require("ShadowsOfUI-Reputations.spec.reputations")

describe("ShadowsOfUI-Reputations faction lookups", function()
  local function load(reps) return reputations.loadCore(reps) end

  local WARBAND = {
    Alice = {
      [2590] = { name = "Council of Dornogal" },
      [2594] = { name = "The Assembly of the Deeps" },
      [2600] = { name = "The Severed Threads" },
    },
    Bob = {
      [2570] = { name = "Hallowfall Arathi" },
      [2594] = { name = "The Assembly of the Deeps" },
      [9001] = { name = "Orc" },            -- too short to index (MIN_NAME)
      [9002] = {},                          -- nameless entry
    },
  }

  describe("FactionIDByName (full cached name inside tooltip text)", function()
    it("finds a faction whose name appears in the text", function()
      local ns = load(WARBAND)
      assert.equals(2570, ns.FactionIDByName("rewards hallowfall arathi reputation"))
    end)

    it("returns nil when no tracked faction name appears", function()
      local ns = load(WARBAND)
      assert.is_nil(ns.FactionIDByName("a plain sword"))
    end)

    it("prefers the longest matching name over a nested shorter one", function()
      local ns = load({ Alice = {
        [1] = { name = "Dornogal" },
        [2] = { name = "Council of Dornogal" },
      } })
      assert.equals(2, ns.FactionIDByName("increases reputation with council of dornogal"))
    end)

    it("ignores names shorter than the false-positive guard", function()
      local ns = load(WARBAND)
      assert.is_nil(ns.FactionIDByName("an orc banner"))
    end)

    it("is a plain-text match, not a Lua pattern", function()
      local ns = load({ Alice = { [1] = { name = "Order (of) the Cinder" } } })
      assert.equals(1, ns.FactionIDByName("the order (of) the cinder"))
      assert.is_nil(ns.FactionIDByName("the order x the cinder"))
    end)

    it("builds the index lazily on first use", function()
      local ns = load(WARBAND)
      assert.is_nil(ns._factionIndexGen)
      ns.FactionIDByName("x")
      assert.equals(1, ns._factionIndexGen)
    end)

    it("is case-sensitive on the index side: names are indexed lowercased, text must be too", function()
      local ns = load(WARBAND)
      assert.is_nil(ns.FactionIDByName("Hallowfall Arathi"))
    end)
  end)

  describe("FactionIDByQuery (what the user typed to /sreps)", function()
    it("an exact name wins", function()
      local ns = load({ Alice = {
        [1] = { name = "The Deeps" },
        [2] = { name = "The Deeps Expedition" },
      } })
      assert.equals(1, ns.FactionIDByQuery("the deeps"))
    end)

    it("a partial name resolves to the shortest cached name containing it", function()
      local ns = load({ Alice = {
        [1] = { name = "Assembly of the Deeps" },
        [2] = { name = "Assembly of the Deeps Vanguard" },
      } })
      assert.equals(1, ns.FactionIDByQuery("the deeps"))
    end)

    it("a dropped leading word still resolves", function()
      local ns = load(WARBAND)
      assert.equals(2594, ns.FactionIDByQuery("assembly of the deeps"))
    end)

    it("a superset query (extra words) falls back to the longest full name inside it", function()
      local ns = load(WARBAND)
      assert.equals(2570, ns.FactionIDByQuery("hallowfall arathi renown"))
    end)

    it("returns nil for an unknown faction", function()
      local ns = load(WARBAND)
      assert.is_nil(ns.FactionIDByQuery("nonexistent"))
    end)

    it("the same faction on two alts is one index entry", function()
      local ns = load(WARBAND)
      assert.equals(2594, ns.FactionIDByQuery("deeps"))
    end)
  end)

  describe("RebuildFactionIndex", function()
    it("bumps the generation each rebuild so tooltip memos invalidate", function()
      local ns = load(WARBAND)
      ns.RebuildFactionIndex()
      local first = ns._factionIndexGen
      ns.RebuildFactionIndex()
      assert.equals(first + 1, ns._factionIndexGen)
    end)

    it("picks up a faction an alt gained since the last build", function()
      local reps = { Alice = { [1] = { name = "Old Faction" } } }
      local ns = load(reps)
      assert.is_nil(ns.FactionIDByName("new faction"))
      reps.Alice[2] = { name = "New Faction" }
      ns.RebuildFactionIndex()
      assert.equals(2, ns.FactionIDByName("new faction"))
    end)

    it("copes with a character that has no cached reputations", function()
      local ns = load({ Alice = {}, Bob = { [3] = { name = "Some Faction" } } })
      ns.RebuildFactionIndex()
      assert.equals(3, ns.FactionIDByName("some faction"))
    end)
  end)
end)
