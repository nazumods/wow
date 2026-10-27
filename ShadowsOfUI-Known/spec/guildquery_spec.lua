local known = require("ShadowsOfUI-Known.spec.known")

-- The recipe's two candidate skill lines: parent (base) profession first, then the recipe's own.
local PARENT, OWN = 197, 2918
local RECIPE = 4242

describe("ShadowsOfUI-Known guild crafter query", function()
  local ns, st
  before_each(function()
    ns, st = known.loadGuildQuery()
    st.profInfo[RECIPE] = { parentProfessionID = PARENT, professionID = OWN }
  end)

  -- A tooltip fake recording refreshes.
  local function tooltip()
    local t = { refreshes = 0, shown = true }
    function t:IsShown() return self.shown end
    function t:RefreshDataNextUpdate() self.refreshes = self.refreshes + 1 end
    return t
  end

  local function mage(name, online) return { name, "MAGE", online } end

  describe("starting a query", function()
    it("returns nil for a missing recipe, and queries nothing", function()
      assert.is_nil((ns.GuildCrafters(nil)))
      assert.equals(0, #st.queries)
    end)

    it("is not queryable out of a guild", function()
      st.inGuild = false
      local list, state = ns.GuildCrafters(RECIPE)
      assert.is_nil(list)
      assert.is_nil(state)
      assert.equals(0, #st.queries)
    end)

    it("is not queryable when the recipe resolves to no skill line", function()
      st.profInfo[RECIPE] = nil
      local list, state = ns.GuildCrafters(RECIPE)
      assert.is_nil(list)
      assert.is_nil(state)
    end)

    it("asks the parent skill line first and reports pending", function()
      local list, state = ns.GuildCrafters(RECIPE, tooltip(), 3)
      assert.is_nil(list)
      assert.equals("pending", state)
      assert.same({ { PARENT, RECIPE, 3 } }, st.queries)
    end)

    it("de-duplicates a recipe whose parent and own skill line are the same", function()
      st.profInfo[RECIPE] = { parentProfessionID = PARENT, professionID = PARENT }
      ns.GuildCrafters(RECIPE)
      st.respond({ PARENT, RECIPE, 0 })
      assert.equals(1, #st.queries)
    end)

    it("primes the guild-recipe subsystem once", function()
      ns.GuildCrafters(RECIPE)
      ns.GuildCrafters(RECIPE + 1)
      assert.equals(1, st.primed)
    end)

    it("a repeat hover of the in-flight recipe fires no second query but adopts the new tooltip", function()
      local first, second = tooltip(), tooltip()
      ns.GuildCrafters(RECIPE, first)
      local list, state = ns.GuildCrafters(RECIPE, second)
      assert.is_nil(list)
      assert.equals("pending", state)
      assert.equals(1, #st.queries)
      st.respond({ PARENT, RECIPE, 1 }, { mage("Alice", true) })
      assert.equals(0, first.refreshes)
      assert.equals(1, second.refreshes)
    end)
  end)

  describe("a response", function()
    it("finishes with the crafters sorted online-first, caches them, and refreshes the tooltip", function()
      local tt = tooltip()
      ns.GuildCrafters(RECIPE, tt)
      st.respond({ PARENT, RECIPE, 3 }, { mage("Zed", false), mage("Bob", true), mage("Amy", true) })
      local list, state = ns.GuildCrafters(RECIPE)
      assert.equals("ready", state)
      assert.equals("Amy", list[1].name)
      assert.equals("Bob", list[2].name)
      assert.equals("Zed", list[3].name)
      assert.equals("Mage", list[1].classKey)
      assert.is_false(list[3].online)
      assert.equals(1, tt.refreshes)
      assert.equals(1, #st.queries)   -- the cached answer fires nothing
    end)

    it("does not refresh a tooltip that is no longer shown", function()
      local tt = tooltip()
      tt.shown = false
      ns.GuildCrafters(RECIPE, tt)
      st.respond({ PARENT, RECIPE, 1 }, { mage("Amy", true) })
      assert.equals(0, tt.refreshes)
    end)

    it("is correlated on the skill line: a late answer for the other candidate is ignored", function()
      ns.GuildCrafters(RECIPE)
      st.respond({ OWN, RECIPE, 1 }, { mage("Amy", true) })   -- in flight is PARENT
      local _, state = ns.GuildCrafters(RECIPE)
      assert.equals("pending", state)
      assert.equals(1, #st.queries)
    end)

    it("is correlated on the recipe: an answer for another recipe is ignored", function()
      ns.GuildCrafters(RECIPE)
      st.respond({ PARENT, RECIPE + 1, 1 }, { mage("Amy", true) })
      local _, state = ns.GuildCrafters(RECIPE)
      assert.equals("pending", state)
    end)

    it("also accepts the queryID in the recipe slot, as Blizzard's own handler does", function()
      ns.GuildCrafters(RECIPE)
      st.respond({ PARENT, 1001, 1 }, { mage("Amy", true) })   -- first query's id
      local _, state = ns.GuildCrafters(RECIPE)
      assert.equals("ready", state)
    end)

    it("ignores an event with no query in flight", function()
      assert.has_no.errors(function() st.respond({ PARENT, RECIPE, 1 }, { mage("Amy", true) }) end)
    end)

    it("ignores an event with no recipe in the payload", function()
      ns.GuildCrafters(RECIPE)
      st.respond({})
      local _, state = ns.GuildCrafters(RECIPE)
      assert.equals("pending", state)
    end)

    it("zero members moves on to the own skill line", function()
      ns.GuildCrafters(RECIPE)
      st.respond({ PARENT, RECIPE, 0 })
      assert.same({ OWN, RECIPE }, { st.queries[2][1], st.queries[2][2] })
      st.respond({ OWN, RECIPE, 1 }, { mage("Amy", true) })
      local list, state = ns.GuildCrafters(RECIPE)
      assert.equals("ready", state)
      assert.equals("Amy", list[1].name)
    end)

    it("both candidates empty finishes with a cached empty list (not pending forever)", function()
      ns.GuildCrafters(RECIPE)
      st.respond({ PARENT, RECIPE, 0 })
      st.respond({ OWN, RECIPE, 0 })
      local list, state = ns.GuildCrafters(RECIPE)
      assert.equals("ready", state)
      assert.same({}, list)
      assert.equals(2, #st.queries)
    end)

    it("drops a secret crafter row but keeps the rest", function()
      local secretName = {}
      st.secret[secretName] = true
      ns.GuildCrafters(RECIPE)
      st.respond({ PARENT, RECIPE, 2 }, { { secretName, "MAGE", true }, mage("Amy", true) })
      local list = ns.GuildCrafters(RECIPE)
      assert.equals(1, #list)
      assert.equals("Amy", list[1].name)
    end)

    it("a secret member count is treated as no crafters and advances", function()
      local secretCount = {}
      st.secret[secretCount] = true
      ns.GuildCrafters(RECIPE)
      st.respond({ PARENT, RECIPE, secretCount })
      assert.equals(2, #st.queries)
    end)

    it("a secret skill line is treated as unknowable and ignored", function()
      local secretLine = {}
      st.secret[secretLine] = true
      ns.GuildCrafters(RECIPE)
      st.respond({ secretLine, RECIPE, 1 }, { mage("Amy", true) })
      local _, state = ns.GuildCrafters(RECIPE)
      assert.equals("pending", state)
    end)
  end)

  describe("a nil queryID (documented MayReturnNothing)", function()
    it("advances immediately instead of waiting out the timeout", function()
      st.nilQuery = true
      local _, state = ns.GuildCrafters(RECIPE)
      assert.equals("pending", state)   -- the caller was told pending before the first candidate failed
      assert.equals(2, #st.queries)     -- both candidates tried back to back
      assert.equals(0, st.pendingTimers())
    end)

    it("finishes empty once every candidate is exhausted", function()
      st.nilQuery = true
      ns.GuildCrafters(RECIPE)
      local list, state = ns.GuildCrafters(RECIPE)
      assert.equals("ready", state)
      assert.same({}, list)
    end)

    it("a nil first query still lets the second candidate answer", function()
      local calls = 0
      local orig = _G.C_GuildInfo.QueryGuildMembersForRecipe
      _G.C_GuildInfo.QueryGuildMembersForRecipe = function(...)
        calls = calls + 1
        if calls == 1 then return nil end
        return orig(...)
      end
      ns.GuildCrafters(RECIPE)
      st.respond({ OWN, RECIPE, 1 }, { mage("Amy", true) })
      local list, state = ns.GuildCrafters(RECIPE)
      assert.equals("ready", state)
      assert.equals("Amy", list[1].name)
    end)
  end)

  describe("timeouts", function()
    it("a silent candidate times out and advances to the next", function()
      ns.GuildCrafters(RECIPE)
      st.fire(1)
      assert.equals(2, #st.queries)
      assert.equals(OWN, st.queries[2][1])
    end)

    it("timing out the last candidate finishes empty and cached", function()
      ns.GuildCrafters(RECIPE)
      st.fire(1)
      st.fire(2)
      local list, state = ns.GuildCrafters(RECIPE)
      assert.equals("ready", state)
      assert.same({}, list)
    end)

    it("a timeout from a candidate that already advanced does not skip the next one", function()
      ns.GuildCrafters(RECIPE)
      st.respond({ PARENT, RECIPE, 0 })   -- advance() to OWN; the PARENT timer is still pending
      st.fire(1)                          -- stale: a.idx moved on
      assert.equals(2, #st.queries)
      local _, state = ns.GuildCrafters(RECIPE)
      assert.equals("pending", state)     -- OWN still awaiting its answer
    end)

    it("a timeout after the response already finished does nothing", function()
      ns.GuildCrafters(RECIPE)
      st.respond({ PARENT, RECIPE, 1 }, { mage("Amy", true) })
      st.fire(1)
      assert.equals(1, #st.queries)
      local list = ns.GuildCrafters(RECIPE)
      assert.equals("Amy", list[1].name)
    end)

    it("a newer hover supersedes the old query: its timeout must not advance the new one", function()
      local other = RECIPE + 1
      st.profInfo[other] = { parentProfessionID = PARENT, professionID = OWN }
      ns.GuildCrafters(RECIPE)
      ns.GuildCrafters(other)         -- replaces `active`
      st.fire(1)                      -- the first recipe's timeout
      assert.equals(2, #st.queries)   -- still just the two initial queries; the new one was not advanced
      local _, state = ns.GuildCrafters(other)
      assert.equals("pending", state)
    end)

    it("a response for the superseded recipe is ignored", function()
      local other = RECIPE + 1
      st.profInfo[other] = { parentProfessionID = PARENT, professionID = OWN }
      ns.GuildCrafters(RECIPE)
      ns.GuildCrafters(other)
      st.respond({ PARENT, RECIPE, 1 }, { mage("Amy", true) })
      local _, state = ns.GuildCrafters(RECIPE)
      assert.equals("pending", state)   -- a fresh query, not a cached hit
    end)
  end)

  describe("cache", function()
    local function resolve(recipeID, name)
      st.profInfo[recipeID] = { parentProfessionID = PARENT, professionID = OWN }
      ns.GuildCrafters(recipeID)
      st.respond({ PARENT, recipeID, 1 }, { mage(name, true) })
    end

    it("is bounded FIFO at 30 recipes", function()
      for i = 1, 31 do resolve(i, "Toon" .. i) end
      local before = #st.queries
      local _, evicted = ns.GuildCrafters(1)
      assert.equals("pending", evicted)             -- oldest evicted: re-queried
      assert.equals(before + 1, #st.queries)
      local _, kept = ns.GuildCrafters(31)
      assert.equals("ready", kept)
    end)

    it("a new crafting-orders session wipes the cache and cancels the in-flight query", function()
      resolve(1, "Amy")
      ns.GuildCrafters(2)
      st.events.CRAFTINGORDERS_SHOW_CUSTOMER()
      st.respond({ PARENT, 2, 1 }, { mage("Bob", true) })   -- cancelled: dropped
      local _, one = ns.GuildCrafters(1)
      assert.equals("pending", one)                         -- cache gone -> re-query
    end)

    it("re-queries the roster on a session start, once primed", function()
      ns.GuildCrafters(RECIPE)
      assert.equals(1, st.primed)
      st.events.CRAFTINGORDERS_SHOW_CUSTOMER()
      assert.equals(2, st.primed)
    end)
  end)
end)
