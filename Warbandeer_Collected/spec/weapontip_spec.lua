-- The weapon cell hover panel's content rules (#856): what the appearance list renders, where it
-- truncates, and what the status line counts. The rendering itself is frame work and stays
-- in-game-tested — these cover the derivation the panel reads, which is where the two mistakes that
-- can't be seen on screen live: a tail count that disagrees with the cap, and a status that counts
-- buckets where it should count appearances.

local collected = require("Warbandeer_Collected.spec.collected")

describe("weapon tip content", function()
  local ns, env

  before_each(function()
    ns = collected.load()
    env = collected.loadWeaponTip(ns)
  end)

  ---Register a resolvable source for a visual. `name = nil` is the still-streaming case.
  local function source(visualID, fields)
    env.sources[visualID] = fields
  end

  describe("lines", function()
    it("renders one line per appearance, in order", function()
      source(10, { name = "Dagger A", itemID = 1 })
      source(20, { name = "Dagger B", itemID = 2 })
      local lines, overflow = ns.WeaponTipLines({10, 20}, {})
      assert.equal(2, #lines)
      assert.equal("Dagger A", lines[1].text)
      assert.equal("Dagger B", lines[2].text)
      assert.equal(0, overflow)
    end)

    it("has no lines and no tail for an empty bucket", function()
      local lines, overflow = ns.WeaponTipLines({}, {})
      assert.equal(0, #lines)
      assert.equal(0, overflow)
    end)

    it("caps the list and reports how many it dropped", function()
      local visuals = {}
      for i = 1, 30 do visuals[i] = i; source(i, { name = "Look " .. i, itemID = i }) end
      local lines, overflow = ns.WeaponTipLines(visuals, {}, 20)
      assert.equal(20, #lines)
      assert.equal(10, overflow)
      assert.equal("Look 20", lines[20].text)
    end)

    it("caps at ns.WeaponTipCap by default", function()
      local visuals = {}
      for i = 1, ns.WeaponTipCap + 5 do visuals[i] = i; source(i, { name = "Look " .. i }) end
      local lines, overflow = ns.WeaponTipLines(visuals, {})
      assert.equal(ns.WeaponTipCap, #lines)
      assert.equal(5, overflow)
    end)

    it("does not truncate a bucket that exactly fills the cap", function()
      local visuals = {}
      for i = 1, 20 do visuals[i] = i; source(i, { name = "Look " .. i }) end
      local lines, overflow = ns.WeaponTipLines(visuals, {}, 20)
      assert.equal(20, #lines)
      assert.equal(0, overflow)
    end)

    it("marks each line collected from the injected map", function()
      source(10, { name = "Owned" })
      source(20, { name = "Missing" })
      local lines = ns.WeaponTipLines({10, 20}, { [10] = true })
      assert.is_true(lines[1].collected)
      assert.is_false(lines[2].collected)
    end)

    it("leaves collected nil under PTR preview, so no row draws a mark", function()
      source(10, { name = "Upcoming" })
      local lines = ns.WeaponTipLines({10}, nil)
      assert.is_nil(lines[1].collected)
    end)

    it("suffixes the difficulty when the source carries one", function()
      source(10, { name = "Blade", difficulty = "Mythic" })
      source(20, { name = "Blade" })
      local lines = ns.WeaponTipLines({10, 20}, {})
      assert.equal("Blade  |cffb0a060Mythic|r", lines[1].text)
      assert.equal("Blade", lines[2].text)
    end)

    it("falls back to the visual id when the source has no name yet, and asks for the item", function()
      source(10, { itemID = 4242 })
      local lines = ns.WeaponTipLines({10}, {})
      assert.equal("Appearance 10", lines[1].text)
      assert.equal(4242, lines[1].pending)
    end)

    it("falls back with nothing pending when the look has no resolvable source at all", function()
      local lines = ns.WeaponTipLines({99}, {})
      assert.equal("Appearance 99", lines[1].text)
      assert.is_nil(lines[1].pending)
    end)

    it("has nothing pending once a name has streamed in", function()
      source(10, { name = "Blade", itemID = 4242 })
      local lines = ns.WeaponTipLines({10}, {})
      assert.is_nil(lines[1].pending)
    end)
  end)

  describe("status", function()
    it("counts wanted per appearance, not per bucket", function()
      ns.db.weaponWanted[10] = true
      ns.db.weaponWanted[20] = true
      local st = ns.WeaponTipStatus({10, 20, 30}, {})
      assert.equal(2, st.wanted)
      -- The cell's own marker is the "any" aggregate; the status line must not borrow it.
      assert.is_true(ns:WeaponCellWanted({10, 20, 30}))
    end)

    it("reports no wanted for an unflagged bucket", function()
      local st = ns.WeaponTipStatus({10, 20}, {})
      assert.equal(0, st.wanted)
    end)

    it("reports the BEST tier among the cell's looks", function()
      ns.db.weaponRank[10] = "A"
      ns.db.weaponRank[20] = "S"
      local st = ns.WeaponTipStatus({10, 20}, {})
      assert.equal("S", st.rank)
    end)

    it("has no tier when nothing in the bucket is ranked", function()
      local st = ns.WeaponTipStatus({10, 20}, {})
      assert.is_nil(st.rank)
    end)

    it("counts collected against the bucket total", function()
      local st = ns.WeaponTipStatus({10, 20, 30}, { [10] = true, [30] = true })
      assert.equal(2, st.collected)
      assert.equal(3, st.total)
    end)

    it("counts nothing collected under PTR preview, keeping total as the upcoming count", function()
      local st = ns.WeaponTipStatus({10, 20}, nil)
      assert.equal(0, st.collected)
      assert.equal(2, st.total)
    end)

    -- #857 settled this permanently: a weapon cell's Shift-click stays a no-op, so the armour tip's
    -- "Shift-click to mark wanted" hint must never reach a weapon cell. Assert on the COMPOSED status
    -- line — the string the renderer actually draws (ns.WeaponTipStatusLine) — not on the
    -- WeaponTipStatus table, which has no hint field to set and so cannot catch a hint added where
    -- the line is built (controls/InfoTipWeapon.lua used to build it inline, out of the spec's reach).
    it("composes a status line carrying no shift-click hint, on live and under PTR", function()
      ns.db.weaponWanted[10] = true
      ns.db.weaponRank[10] = "S"
      local live = ns.WeaponTipStatusLine(ns.WeaponTipStatus({10, 20}, { [10] = true }), false)
      local ptr = ns.WeaponTipStatusLine(ns.WeaponTipStatus({10, 20}, nil), true)
      assert.is_nil(live:find("Shift"))
      assert.is_nil(ptr:find("Shift"))
      -- The count fills the slot the hint would have taken, so the line is never an empty gap.
      assert.is_true(#live > 0)
      assert.is_true(#ptr > 0)
    end)

    it("puts the collected count in the status line on live", function()
      local line = ns.WeaponTipStatusLine(ns.WeaponTipStatus({10, 20, 30}, { [10] = true, [30] = true }), false)
      assert.is_not_nil(line:find("2/3 collected"))
    end)

    it("shows the upcoming count instead of collected under PTR preview", function()
      local line = ns.WeaponTipStatusLine(ns.WeaponTipStatus({10, 20}, nil), true)
      assert.is_not_nil(line:find("2 upcoming"))
      assert.is_nil(line:find("collected"))
    end)

    it("carries the wanted count and the best-tier tag when flagged", function()
      ns.db.weaponWanted[10] = true
      ns.db.weaponRank[10] = "A"
      ns.db.weaponRank[20] = "S"
      local line = ns.WeaponTipStatusLine(ns.WeaponTipStatus({10, 20}, {}), false)
      assert.is_not_nil(line:find("1 wanted"))
      assert.is_not_nil(line:find("Tier S %(best%)"))
    end)
  end)
end)
