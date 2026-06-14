local up = require("ShadowsOfUI-Upgrade.spec.upgrade")

-- Spec IDs (real Blizzard) the harness's CLASSES fixture maps.
local ARMS, FURY, PROT_WAR = 71, 72, 73
local FIRE_MAGE = 63
local FERAL, GUARDIAN, RESTO_DRUID = 103, 104, 105
local SUB_ROGUE = 261

local function charWithSpec(specID)
  return { name = "T", basic = { specialization = { id = specID } } }
end

describe("ShadowsOfUI-Upgrade resolve", function()
  local ns
  before_each(function() ns = up.harness().ns end)

  describe("StatRanks", function()
    it("returns the spec's secondary-stat tier map", function()
      -- Fire mage (MAGE index 2): { crit=3, haste=1, mastery=1, versatility=2 }.
      assert.same({ crit = 3, haste = 1, mastery = 1, versatility = 2 },
        ns.StatRanks(charWithSpec(FIRE_MAGE)))
      -- Arms warrior (WARRIOR index 1): { crit=1, haste=2, mastery=3, versatility=4 }.
      assert.same({ crit = 1, haste = 2, mastery = 3, versatility = 4 },
        ns.StatRanks(charWithSpec(ARMS)))
    end)

    it("resolves the right spec index within a class (not just the first)", function()
      -- Druid feral/guardian/resto are indices 2/3/4 — exercise the index math.
      assert.same({ crit = 3, haste = 2, mastery = 1, versatility = 4 },
        ns.StatRanks(charWithSpec(FERAL)))
      assert.same({ crit = 3, haste = 1, mastery = 3, versatility = 2 },
        ns.StatRanks(charWithSpec(GUARDIAN)))
      assert.same({ crit = 3, haste = 1, mastery = 1, versatility = 2 },
        ns.StatRanks(charWithSpec(RESTO_DRUID)))
    end)

    it("returns nil when the character has no stored spec id", function()
      assert.is_nil(ns.StatRanks({ name = "T" }))
      assert.is_nil(ns.StatRanks({ name = "T", basic = {} }))
      assert.is_nil(ns.StatRanks({ name = "T", basic = { specialization = {} } }))
    end)

    it("returns nil for an unknown spec id", function()
      assert.is_nil(ns.StatRanks(charWithSpec(999999)))
    end)

    it("returns nil for a nil character", function()
      assert.is_nil(ns.StatRanks(nil))
    end)
  end)

  describe("PrimaryStat", function()
    it("maps each spec to its primary stat token", function()
      assert.equals("str", ns.PrimaryStat(charWithSpec(ARMS)))
      assert.equals("str", ns.PrimaryStat(charWithSpec(FURY)))
      assert.equals("str", ns.PrimaryStat(charWithSpec(PROT_WAR)))
      assert.equals("int", ns.PrimaryStat(charWithSpec(FIRE_MAGE)))
      assert.equals("agi", ns.PrimaryStat(charWithSpec(SUB_ROGUE)))
    end)

    it("tracks per-spec primary differences within a class", function()
      -- Druid: balance int / feral agi / guardian agi / resto int.
      assert.equals("agi", ns.PrimaryStat(charWithSpec(FERAL)))
      assert.equals("agi", ns.PrimaryStat(charWithSpec(GUARDIAN)))
      assert.equals("int", ns.PrimaryStat(charWithSpec(RESTO_DRUID)))
    end)

    it("returns nil without a stored spec id or for an unknown spec", function()
      assert.is_nil(ns.PrimaryStat({ name = "T" }))
      assert.is_nil(ns.PrimaryStat(charWithSpec(999999)))
      assert.is_nil(ns.PrimaryStat(nil))
    end)
  end)
end)
