local libn = require("LibNAddOn.spec.libn")

describe("ns.lua.Class", function()
  local Class

  before_each(function()
    Class = libn.load().lua.Class
  end)

  it("runs the constructor on the options table", function()
    local C = Class(nil, function(self) self.built = true end)
    local o = C:new{name = "x"}
    assert.is_true(o.built)
    assert.equal("x", o.name)
  end)

  it("fills defaults without overwriting provided options", function()
    local C = Class(nil, function() end, {width = 100, height = 50})
    local o = C:new{width = 200}
    assert.equal(200, o.width)
    assert.equal(50, o.height)
  end)

  it("resolves methods defined after Class() via the metatable", function()
    local C = Class(nil, function() end)
    function C:Greet() return "hi " .. self.name end
    local o = C:new{name = "bob"}
    assert.equal("hi bob", o:Greet())
  end)

  it("runs parent constructor and defaults before the child's", function()
    local order = {}
    local P = Class(nil, function(self) table.insert(order, "parent") end, {p = 1})
    local C = Class(P, function(self) table.insert(order, "child") end, {c = 2})
    local o = C:new{}
    assert.same({"parent", "child"}, order)
    assert.equal(1, o.p)
    assert.equal(2, o.c)
  end)

  it("lets a child override parent methods", function()
    local P = Class(nil, function() end)
    function P:Kind() return "parent" end
    local C = Class(P, function() end)
    function C:Kind() return "child" end
    assert.equal("child", C:new{}:Kind())
    assert.equal("parent", P:new{}:Kind())
  end)

  it("calls the defaults onLoad after construction, not as a field", function()
    local loaded
    local C = Class(nil, function(self) self.ready = true end, {
      onLoad = function(self) loaded = self.ready end,
    })
    local o = C:new{}
    assert.is_true(loaded)
    assert.is_nil(o.onLoad)
  end)

  it("mixes extra tables into the class", function()
    local mixin = {Extra = function() return 42 end}
    local C = Class(nil, function() end, nil, mixin)
    assert.equal(42, C:new{}:Extra())
  end)

  it("gives each instance its own copy of table-valued defaults", function()
    local C = Class(nil, function() end, {list = {}, point = {x = 1}})
    local a, b = C:new{}, C:new{}
    assert.not_equal(a.list, b.list)
    table.insert(a.list, "item")
    a.point.x = 99
    assert.same({}, b.list)
    assert.equal(1, b.point.x)
    assert.equal(1, C:new{}.point.x) -- the class defaults stay pristine too
  end)

  it("copies table-valued defaults deeply", function()
    local C = Class(nil, function() end, {position = {Center = {}}})
    local a, b = C:new{}, C:new{}
    assert.not_equal(a.position.Center, b.position.Center)
  end)

  it("shares metatabled and function defaults by reference", function()
    local frame = setmetatable({}, {__index = {IsShown = function() end}})
    local fn = function() end
    local C = Class(nil, function() end, {parent = frame, handler = fn})
    local o = C:new{}
    assert.equal(frame, o.parent)
    assert.equal(fn, o.handler)
  end)

  it("keeps a caller-provided table by reference, uncopied", function()
    local mine = {"a"}
    local C = Class(nil, function() end, {list = {}})
    assert.equal(mine, C:new{list = mine}.list)
  end)

  it("copies parent table-valued defaults per instance as well", function()
    local P = Class(nil, function() end, {plist = {}})
    local C = Class(P, function() end, {})
    local a, b = C:new{}, C:new{}
    assert.not_equal(a.plist, b.plist)
  end)

  it("calls parent class-level onLoad exactly once when constructing a subclass", function()
    local calls = 0
    local P = Class(nil, function() end)
    function P:onLoad() calls = calls + 1 end
    local C = Class(P, function() end)
    C:new{}
    assert.equal(1, calls)
  end)
end)
