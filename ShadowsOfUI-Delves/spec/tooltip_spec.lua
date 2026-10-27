local delves = require("ShadowsOfUI-Delves.spec.delves")

-- A recorded stat row for the current character. scope is the tier ("11") or "all".
local function mine(fields)
  local s = { name = "Me", scope = "11", count = 3, avg = 600, avgXp = nil, xpCount = 3 }
  for k, v in pairs(fields or {}) do s[k] = v end
  return s
end

local function has(lines, needle)
  for _, l in ipairs(lines) do if l:find(needle, 1, true) then return true end end
  return false
end

describe("ShadowsOfUI-Delves entrance tooltip", function()
  describe("completion time", function()
    it("shows the average time, tier scope and run count", function()
      local _, st = delves.load({ maxLevel = true, stats = { mine() } })
      local lines = st.hover("The Dread Pit")
      assert.equals(1, #lines)
      assert.equals("Avg completion (11): 10:00  · 3 runs", lines[1])
    end)

    it("pluralises runs", function()
      local _, st = delves.load({ maxLevel = true, stats = { mine({ count = 1 }) } })
      assert.is_truthy(st.hover("X")[1]:find("· 1 run", 1, true))
      assert.is_nil(st.hover("X")[1]:find("runs", 1, true))
    end)

    it("marks an all-tiers fallback average", function()
      local _, st = delves.load({ maxLevel = true, stats = { mine({ scope = "all" }) } })
      assert.equals("Avg completion: 10:00  · 3 runs (all tiers)", st.hover("X")[1])
    end)

    it("uses only the current character's row", function()
      local _, st = delves.load({ maxLevel = true, stats = { mine({ name = "Alt", avg = 60 }), mine({ avg = 120 }) } })
      assert.is_truthy(st.hover("X")[1]:find("2:00", 1, true))
    end)

    it("says so when the current character has no timed run", function()
      local _, st = delves.load({ maxLevel = true, stats = { mine({ name = "Alt" }) } })
      assert.same({ "No timed runs yet" }, st.hover("X"))
    end)

    it("says so when the delve has no stats at all", function()
      local _, st = delves.load({ maxLevel = true, stats = nil })
      assert.same({ "No timed runs yet" }, st.hover("X"))
    end)

    it("re-shows the tooltip so it resizes around the added line", function()
      local _, st = delves.load({ maxLevel = true, stats = { mine() } })
      st.hover("X")
      assert.equals(1, st.shows)
    end)
  end)

  describe("leveling XP and XP/hr", function()
    it("shows average XP, share of a level, and XP/hr (avg XP / avg time)", function()
      local _, st = delves.load({ stats = { mine({ avgXp = 30000, avg = 600 }) } })
      local lines = st.hover("X")
      assert.equals(2, #lines)
      -- 30000 XP over 600s = 180000 XP/hr; 30000 / 100000 = 30% of the level
      assert.equals("Avg XP (11): 30000 [30%]  · 180000 XP/hr", lines[2])
    end)

    it("rounds the XP/hr rate to the nearest whole number", function()
      local _, st = delves.load({ stats = { mine({ avgXp = 1000, avg = 7 }) } })
      -- 1000 / 7 * 3600 = 514285.71...
      assert.is_truthy(st.hover("X")[2]:find("514286 XP/hr", 1, true))
    end)

    it("drops the rate for a zero-time average (no divide by zero)", function()
      local _, st = delves.load({ stats = { mine({ avgXp = 5000, avg = 0 }) } })
      local line = st.hover("X")[2]
      assert.is_truthy(line)
      assert.is_nil(line:find("XP/hr", 1, true))
    end)

    it("drops the level share when the level has no XP total", function()
      local _, st = delves.load({ maxXP = 0, stats = { mine({ avgXp = 5000 }) } })
      local line = st.hover("X")[2]
      assert.is_nil(line:find("%", 1, true))
      assert.is_truthy(line:find("XP/hr", 1, true))
    end)

    it("drops the XP line for a run with no XP recorded", function()
      local _, st = delves.load({ stats = { mine({ avgXp = 0 }) } })
      assert.equals(1, #st.hover("X"))
      st = select(2, delves.load({ stats = { mine({ avgXp = nil }) } }))
      assert.equals(1, #st.hover("X"))
    end)

    it("is leveling-only: a max-level character never sees XP, even with stale XP in the window", function()
      local _, st = delves.load({ maxLevel = true, stats = { mine({ avgXp = 30000 }) } })
      assert.equals(1, #st.hover("X"))
      assert.is_false(has(st.lines, "XP"))
    end)

    it("labels an all-tiers XP average", function()
      local _, st = delves.load({ stats = { mine({ scope = "all", avgXp = 30000 }) } })
      assert.is_truthy(st.hover("X")[2]:find("Avg XP: 30000", 1, true))
    end)
  end)

  describe("pin gating", function()
    it("adds nothing while Shift is held (suite convention)", function()
      local _, st = delves.load({ maxLevel = true, stats = { mine() }, shift = true })
      assert.same({}, st.hover("X"))
      assert.equals(0, st.shows)
    end)

    it("ignores a pin that is not a delve entrance", function()
      local _, st = delves.load({ maxLevel = true, stats = { mine() } })
      assert.same({}, st.hover("X", 9999))
    end)

    it("ignores a pin with no POI id", function()
      local _, st = delves.load({ maxLevel = true, stats = { mine() } })
      _G.DelveEntrancePinMixin.OnMouseEnter({ poiInfo = {}, GetMap = function() end })
      assert.same({}, st.lines)
    end)

    it("falls back to the POI lookup when the pin carries no name", function()
      local _, st = delves.load({ maxLevel = true, stats = nil })
      assert.same({ "No timed runs yet" }, st.hover(nil))
    end)
  end)

  describe("AssumedTier", function()
    it("is Tier 11 at the level cap, nil (all-tiers) while leveling", function()
      local ns, st = delves.load({ maxLevel = true })
      assert.equals(11, ns.AssumedTier())
      st.maxLevel = false
      assert.is_nil(ns.AssumedTier())
    end)
  end)
end)
