local libn = require("LibNAddOn.spec.libn")

describe("ns.lua.strings", function()
  local strings

  before_each(function()
    strings = libn.load().lua.strings
  end)

  describe("startsWith", function()
    it("matches a prefix", function()
      assert.is_true(strings.startsWith("Warbandeer_Alias", "Warbandeer"))
    end)

    it("rejects a non-prefix", function()
      assert.is_falsy(strings.startsWith("LibNUI", "Warbandeer"))
    end)

    it("is falsy for a nil string", function()
      assert.is_falsy(strings.startsWith(nil, "x"))
    end)

    it("matches when prefix equals the string", function()
      assert.is_true(strings.startsWith("abc", "abc"))
    end)
  end)

  describe("split", function()
    it("takes the token FIRST (documented gotcha)", function()
      assert.same({"a", "b", "c"}, strings.split(",", "a,b,c"))
    end)

    it("splits on each character of the token independently", function()
      -- token is a char class, not a literal separator string
      assert.same({"a", "b", "c"}, strings.split(",;", "a,b;c"))
    end)

    it("drops empty segments", function()
      assert.same({"a", "b"}, strings.split(",", ",,a,,b,"))
    end)

    it("returns the whole string when the token never occurs", function()
      assert.same({"abc"}, strings.split("|", "abc"))
    end)
  end)
end)
