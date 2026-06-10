local libn = require("LibNAddOn.spec.libn")

describe("ns.lua.lists", function()
  local lists

  before_each(function()
    lists = libn.load().lua.lists
  end)

  describe("values", function()
    it("collects values from multiple tables", function()
      local r = lists.values({1, 2}, {3})
      table.sort(r)
      assert.same({1, 2, 3}, r)
    end)

    it("skips nil arguments", function()
      assert.same({1}, lists.values(nil, {1}, nil))
    end)

    it("includes map values, not keys", function()
      local r = lists.values{a = 10, b = 20}
      table.sort(r)
      assert.same({10, 20}, r)
    end)
  end)

  describe("generate", function()
    it("calls the function 1..n with the index", function()
      assert.same({2, 4, 6}, lists.generate(function(i) return i * 2 end, 3))
    end)
  end)

  describe("map", function()
    it("transforms each value with (v, k)", function()
      assert.same({11, 22}, lists.map({10, 20}, function(v, k) return v + k end))
    end)

    it("copies the list when no function is given", function()
      assert.same({1, 2}, lists.map({1, 2}))
    end)
  end)

  describe("filter", function()
    it("keeps values for which the predicate is truthy", function()
      assert.same({2, 4}, lists.filter({1, 2, 3, 4}, function(v) return v % 2 == 0 end))
    end)
  end)

  describe("find", function()
    it("returns the index of a value", function()
      assert.equal(2, lists.find({"a", "b", "c"}, "b"))
    end)

    it("returns nil when not found", function()
      assert.is_nil(lists.find({"a"}, "z"))
    end)

    it("returns index and value when given a predicate", function()
      local i, v = lists.find({5, 10, 15}, function(v) return v > 7 end)
      assert.equal(2, i)
      assert.equal(10, v)
    end)
  end)

  describe("fold", function()
    it("folds a list into n interleaved lists", function()
      assert.same({{1, 3}, {2, 4}}, lists.fold({1, 2, 3, 4}, 2))
    end)

    it("handles a remainder", function()
      assert.same({{1, 3, 5}, {2, 4}}, lists.fold({1, 2, 3, 4, 5}, 2))
    end)
  end)

  describe("prepend", function()
    it("prepends values in argument order, mutating the list", function()
      local t = {3, 4}
      local r = lists.prepend(t, 1, 2)
      assert.equal(t, r)
      assert.same({1, 2, 3, 4}, t)
    end)
  end)
end)
