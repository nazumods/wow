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

  describe("duration", function()
    it("formats m:ss by default, zero-padding seconds", function()
      assert.equals("0:25", strings.duration(25))
      assert.equals("1:05", strings.duration(65))
    end)

    it("leaves minutes unbounded in m:ss", function()
      assert.equals("72:00", strings.duration(4320))
    end)

    it("floors fractional seconds", function()
      assert.equals("0:25", strings.duration(25.9))
    end)

    it("clamps nil and negatives to 0:00", function()
      assert.equals("0:00", strings.duration(nil))
      assert.equals("0:00", strings.duration(-5))
    end)

    it("formats h:mm:ss", function()
      assert.equals("1:02:05", strings.duration(3725, "h:mm:ss"))
      assert.equals("0:00:25", strings.duration(25, "h:mm:ss"))
    end)

    it("auto switches to h:mm:ss at one hour", function()
      assert.equals("59:59", strings.duration(3599, "auto"))
      assert.equals("1:00:00", strings.duration(3600, "auto"))
    end)
  end)

  describe("stripEscapes", function()
    it("strips a colour code and its reset", function()
      assert.equals("Delver's Bounty", strings.stripEscapes("|cffffd700Delver's Bounty|r"))
    end)

    it("strips inline textures and atlases", function()
      assert.equals("Gold", strings.stripEscapes("|TInterface\\Icons\\coin:16|tGold"))
      assert.equals("Rank", strings.stripEscapes("|A:tier-star:16:16|aRank"))
    end)

    it("strips a mix of every escape type in one string", function()
      assert.equals("Tier 8 done",
        strings.stripEscapes("|cff00ff00Tier |A:star:12:12|a8|r |Ttex:10|tdone"))
    end)

    it("leaves a plain string untouched", function()
      assert.equals("just text", strings.stripEscapes("just text"))
    end)

    it("passes nil through as nil", function()
      assert.is_nil(strings.stripEscapes(nil))
    end)

    it("returns a single value (gsub count not leaked)", function()
      assert.equals(1, select("#", strings.stripEscapes("|cffffffffx|r")))
    end)
  end)
end)
