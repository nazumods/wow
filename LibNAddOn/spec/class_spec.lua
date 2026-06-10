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
end)
