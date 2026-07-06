local libn = require("LibNAddOn.spec.libn")

describe("ns.lua.maps", function()
  local maps

  before_each(function()
    maps = libn.load().lua.maps
  end)

  describe("merge", function()
    it("overwrites existing keys, mutating the first table", function()
      local t = {a = 1, b = 2}
      local r = maps.merge(t, {b = 3, c = 4})
      assert.equal(t, r)
      assert.same({a = 1, b = 3, c = 4}, t)
    end)

    it("deep-merges nested tables", function()
      local t = {sub = {x = 1, y = 2}}
      maps.merge(t, {sub = {y = 3}})
      assert.same({sub = {x = 1, y = 3}}, t)
    end)

    it("skips __index keys", function()
      local t = {}
      maps.merge(t, {__index = {}, a = 1})
      assert.same({a = 1}, t)
    end)

    it("ignores nil sources", function()
      assert.same({a = 1}, maps.merge({a = 1}, nil, nil))
    end)

    it("copies plain sub-tables instead of aliasing the source", function()
      local src = {sub = {x = 1}}
      local t = maps.merge({}, src)
      assert.same({x = 1}, t.sub)
      assert.not_equal(src.sub, t.sub)
      t.sub.x = 99
      assert.equal(1, src.sub.x)
    end)

    it("copies nested sub-tables deeply", function()
      local src = {a = {b = {c = 1}}}
      local t = maps.merge({}, src)
      assert.not_equal(src.a.b, t.a.b)
      t.a.b.c = 99
      assert.equal(1, src.a.b.c)
    end)

    it("assigns metatabled values by reference, not by copy", function()
      local obj = setmetatable({v = 1}, {__index = {Method = function() end}})
      local t = maps.merge({}, {obj = obj})
      assert.equal(obj, t.obj)
    end)

    it("keeps a metatabled value by reference even when the destination key already holds a table", function()
      local obj = setmetatable({v = 1}, {__index = {Method = function() end}})
      local dest = {obj = {}}  -- destination[k] is already a plain table
      maps.merge(dest, {obj = obj})
      assert.equal(obj, dest.obj)  -- shared by reference, not field-copied into the existing table
    end)
  end)

  describe("fill", function()
    it("adds missing keys without overwriting existing ones", function()
      local t = {a = 1}
      maps.fill(t, {a = 99, b = 2})
      assert.same({a = 1, b = 2}, t)
    end)

    it("is shallow: never recurses into existing sub-tables (documented gotcha)", function()
      local t = {sub = {x = 1}}
      maps.fill(t, {sub = {x = 99, y = 2}})
      assert.same({sub = {x = 1}}, t)
    end)
  end)

  describe("map", function()
    it("transforms each value, keeping keys", function()
      assert.same({a = 2, b = 4}, maps.map({a = 1, b = 2}, function(v) return v * 2 end))
    end)
  end)

  describe("toMap", function()
    it("keys the result by the list values", function()
      assert.same({a = 1, b = 2}, maps.toMap({"a", "b"}, function(_, i) return i end))
    end)

    it("maps values to themselves without a function", function()
      assert.same({a = "a", b = "b"}, maps.toMap({"a", "b"}))
    end)
  end)

  describe("toList", function()
    it("builds a list from key/value pairs", function()
      local r = maps.toList({a = 1, b = 2}, function(k, v) return k .. v end)
      table.sort(r)
      assert.same({"a1", "b2"}, r)
    end)
  end)

  describe("any", function()
    it("returns true when a value matches", function()
      assert.is_true(maps.any({a = 1, b = 2}, function(v) return v == 2 end))
    end)

    it("returns false when none match", function()
      assert.is_false(maps.any({a = 1}, function(v) return v == 2 end))
    end)
  end)

  describe("anyKey", function()
    it("returns true when a key matches", function()
      assert.is_true(maps.anyKey({a = 1}, function(k) return k == "a" end))
    end)

    it("returns false when none match", function()
      assert.is_false(maps.anyKey({a = 1}, function(k) return k == "z" end))
    end)
  end)
end)
