-- globals/colors.lua only needs ns.lua.lists (from libn.load) and, for rgba, the CreateColor
-- global, so it loads standalone on top of a fresh LibNAddOn namespace.

local libn = require("LibNAddOn.spec.libn")

describe("LibNAddOn Colors", function()
  local Colors

  before_each(function()
    local ns = libn.load()
    assert(loadfile("LibNAddOn/globals/colors.lua"))("LibNAddOn", ns)
    Colors = ns.Colors
  end)

  describe("hex", function()
    it("formats 0-1 components as a 6-digit lowercase hex string", function()
      assert.equals("ff0000", Colors.hex({ 1, 0, 0 }))
      assert.equals("00ff00", Colors.hex({ 0, 1, 0 }))
      assert.equals("0000ff", Colors.hex({ 0, 0, 1 }))
      assert.equals("000000", Colors.hex({ 0, 0, 0 }))
      assert.equals("ffffff", Colors.hex({ 1, 1, 1 }))
    end)

    it("rounds to the nearest byte rather than truncating", function()
      assert.equals("808080", Colors.hex({ 0.5, 0.5, 0.5 }))  -- 127.5 -> 128
      assert.equals("fefefe", Colors.hex({ 0.996, 0.996, 0.996 }))  -- 253.98 -> 254
    end)

    it("ignores an alpha component", function()
      assert.equals("ff8000", Colors.hex({ 1, 0.5, 0, 0.25 }))
    end)

    it("matches the class colours the suite embeds in chat", function()
      assert.equals("c41f3b", Colors.hex(Colors.DeathKnight))
    end)
  end)

  describe("code and wrap", function()
    it("code opens a |cff colour escape", function()
      assert.equals("|cffff0000", Colors.code({ 1, 0, 0 }))
    end)

    it("wrap closes the escape with |r", function()
      assert.equals("|cff00ff00ok|r", Colors.wrap("ok", { 0, 1, 0 }))
    end)
  end)

  describe("alpha", function()
    it("appends alpha to an RGB table", function()
      assert.same({ 1, 0.5, 0, 0.3 }, Colors.alpha({ 1, 0.5, 0 }, 0.3))
    end)

    it("replaces the alpha of an RGBA table", function()
      assert.same({ 1, 0.5, 0, 0.3 }, Colors.alpha({ 1, 0.5, 0, 1 }, 0.3))
    end)

    it("defaults a replaced alpha to 1 when none is given", function()
      assert.same({ 1, 0.5, 0, 1 }, Colors.alpha({ 1, 0.5, 0, 0.2 }))
    end)

    it("returns a new table and leaves the original alone", function()
      local original = { 1, 0.5, 0, 0.2 }
      local result = Colors.alpha(original, 0.9)
      assert.are_not.equal(original, result)
      assert.same({ 1, 0.5, 0, 0.2 }, original)
    end)

    it("accepts a ColorMixin-style object by reading its GetRGBA", function()
      local mixin = { GetRGBA = function() return 0.1, 0.2, 0.3, 1 end }
      assert.same({ 0.1, 0.2, 0.3, 0.4 }, Colors.alpha(mixin, 0.4))
    end)
  end)

  describe("rgba", function()
    it("normalises 0-255 channels through CreateColor and passes alpha through", function()
      local saved = _G.CreateColor
      _G.CreateColor = function(r, g, b, a) return { r, g, b, a } end
      -- re-load so the file-local CreateColor captures the stub
      local ns = libn.load()
      assert(loadfile("LibNAddOn/globals/colors.lua"))("LibNAddOn", ns)
      local c = ns.Colors.rgba(255, 51, 0, 0.5)
      _G.CreateColor = saved
      assert.same({ 1, 0.2, 0, 0.5 }, c)
    end)
  end)
end)
