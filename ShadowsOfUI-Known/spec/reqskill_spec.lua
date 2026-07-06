local known = require("ShadowsOfUI-Known.spec.known")

-- Build a tooltip `data` from a list of left-text strings.
local function tip(...)
  local lines = {}
  for _, txt in ipairs({...}) do lines[#lines + 1] = { leftText = txt } end
  return { lines = lines }
end

describe("ShadowsOfUI-Known ns.ReqSkill", function()
  describe("with ITEM_MIN_SKILL present (anchored to the Requires line)", function()
    local ns
    before_each(function() ns = known.load() end)

    it("reads the threshold from the 'Requires <Prof> (NN)' line", function()
      assert.equal(425, ns.ReqSkill(tip("Recipe: Bolt of Cloth", "Requires Tailoring (425)")))
    end)

    it("ignores an earlier incidental (NN) before the requirement line", function()
      assert.equal(425, ns.ReqSkill(tip(
        "Pattern: Fancy Robe",       -- line 1 (name) always skipped
        "Set: 2 pieces (2)",         -- incidental (2) on a non-Requires line → ignored
        "Requires Tailoring (425)")))
    end)

    it("skips line 1 even if the name itself has (NN)", function()
      assert.equal(300, ns.ReqSkill(tip("Recipe: Thing (99)", "Requires Alchemy (300)")))
    end)

    it("returns 0 when there is no skill requirement", function()
      assert.equal(0, ns.ReqSkill(tip("Recipe: Foo", "Use: Teaches you to make Foo.")))
    end)

    it("does not false-match a parenless 'Requires Level' line", function()
      assert.equal(0, ns.ReqSkill(tip("Recipe: Foo", "Requires Level 60")))
    end)

    it("returns 0 for missing lines", function()
      assert.equal(0, ns.ReqSkill({}))
    end)
  end)

  describe("without ITEM_MIN_SKILL (fallback to first parenthesised integer)", function()
    it("still finds the requirement number", function()
      local ns = known.load(false)
      assert.equal(300, ns.ReqSkill(tip("Recipe: Foo", "Requires Tailoring (300)")))
    end)
  end)
end)
