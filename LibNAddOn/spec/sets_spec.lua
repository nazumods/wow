local libn = require("LibNAddOn.spec.libn")

describe("ns.lua.sets", function()
  local sets

  before_each(function()
    sets = libn.load().lua.sets
  end)

  describe("Set", function()
    it("keeps numeric values as numeric keys (regression #30)", function()
      local s = sets.Set{87308, 91795}
      assert.is_true(s[87308])
      assert.is_true(s[91795])
      assert.is_nil(s["87308"])
    end)

    it("keeps string values as string keys", function()
      local s = sets.Set{"Druid", "Mage"}
      assert.is_true(s.Druid)
      assert.is_true(s.Mage)
      assert.is_nil(s.Warrior)
    end)

    it("returns an empty set for an empty list", function()
      assert.same({}, sets.Set{})
    end)

    it("ignores map-style arguments (ipairs gotcha)", function()
      -- Documented gotcha: Set iterates with ipairs, so non-array keys
      -- are silently dropped. Set{q=86204} was the #30 footgun.
      assert.same({}, sets.Set{q = 86204})
    end)
  end)

  describe("values", function()
    it("uses map values as keys, preserving their type", function()
      local s = sets.values{Dornogal = 82362, Hallowfall = 82407}
      assert.is_true(s[82362])
      assert.is_true(s[82407])
      assert.is_nil(s["82362"])
      assert.is_nil(s.Dornogal)
    end)

    it("works on array-style tables too", function()
      local s = sets.values{"a", "b"}
      assert.is_true(s.a)
      assert.is_true(s.b)
    end)
  end)
end)
