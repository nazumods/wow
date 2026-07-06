local bars = require("Warbandeer_Bars.spec.bars")

describe("Warbandeer_Bars tracker", function()
  local ns

  before_each(function()
    ns = bars.load()
  end)

  describe("shouldStore (sparse-capture guard)", function()
    -- A minimal profile carrying only what the guard inspects: its slot count.
    local function profile(nSlots)
      local slots = {}
      for i = 1, nSlots do slots[i] = { id = i } end
      return { slots = slots }
    end

    it("stores when no profile exists yet, even under the guard", function()
      assert.is_true(ns.shouldStore(nil, profile(0), true))
    end)

    it("stores an unguarded capture even when it is sparser (logout path)", function()
      -- The logout snapshot must record a legitimate reduction.
      assert.is_true(ns.shouldStore(profile(40), profile(5), false))
    end)

    it("skips a guarded capture that is sparser than the stored profile", function()
      -- The login/spec race: bars not yet populated → keep the good profile.
      assert.is_false(ns.shouldStore(profile(40), profile(5), true))
    end)

    it("stores a guarded capture with an equal slot count", function()
      assert.is_true(ns.shouldStore(profile(40), profile(40), true))
    end)

    it("stores a guarded capture that is richer than the stored profile", function()
      assert.is_true(ns.shouldStore(profile(40), profile(41), true))
    end)
  end)
end)
