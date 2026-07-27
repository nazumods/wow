local libn = require("LibNAddOn.spec.libn")

describe("ns.lua.signal", function()
  local ns
  before_each(function() ns = libn.load() end)

  it("fires every subscriber, in registration order", function()
    local s, seen = ns.lua.signal(), {}
    s:Subscribe(function() seen[#seen + 1] = "a" end)
    s:Subscribe(function() seen[#seen + 1] = "b" end)
    s:Fire()
    assert.same({ "a", "b" }, seen)
  end)

  it("passes every argument through, nils included", function()
    local s, got = ns.lua.signal(), nil
    s:Subscribe(function(...) got = { n = select("#", ...), ... } end)
    s:Fire(1, nil, "three")
    assert.equals(3, got.n)
    assert.equals(1, got[1])
    assert.is_nil(got[2])
    assert.equals("three", got[3])
  end)

  it("is a no-op with no subscribers", function()
    assert.has_no.errors(function() ns.lua.signal():Fire("x") end)
  end)

  it("counts registrations", function()
    local s = ns.lua.signal()
    assert.equals(0, s:Count())
    local fn = s:Subscribe(function() end)
    assert.equals(1, s:Count())
    s:Unsubscribe(fn)
    assert.equals(0, s:Count())
  end)

  it("returns the function from Subscribe, so it can be kept for Unsubscribe", function()
    local s = ns.lua.signal()
    local fn = function() end
    assert.equals(fn, s:Subscribe(fn))
  end)

  it("Unsubscribe reports whether it removed anything", function()
    local s, fn = ns.lua.signal(), function() end
    assert.is_false(s:Unsubscribe(fn))
    s:Subscribe(fn)
    assert.is_true(s:Unsubscribe(fn))
  end)

  it("removes only ONE registration of a function subscribed twice", function()
    local s, n = ns.lua.signal(), 0
    local fn = function() n = n + 1 end
    s:Subscribe(fn); s:Subscribe(fn)
    s:Unsubscribe(fn)
    s:Fire()
    assert.equals(1, n)
  end)

  -- The reason Fire iterates a snapshot: without one, removing the running listener shifts the
  -- list left and the loop skips whichever listener took its place.
  it("still runs later subscribers when one unsubscribes itself mid-fire", function()
    local s, seen = ns.lua.signal(), {}
    local first
    first = s:Subscribe(function() seen[#seen + 1] = "first"; s:Unsubscribe(first) end)
    s:Subscribe(function() seen[#seen + 1] = "second" end)
    s:Fire()
    assert.same({ "first", "second" }, seen)
  end)

  it("does not run a listener subscribed during the fire that added it", function()
    local s, seen = ns.lua.signal(), {}
    s:Subscribe(function()
      seen[#seen + 1] = "outer"
      s:Subscribe(function() seen[#seen + 1] = "inner" end)
    end)
    s:Fire()
    assert.same({ "outer" }, seen)
    s:Fire()
    assert.same({ "outer", "outer", "inner" }, seen)
  end)

  it("keeps separate signals independent", function()
    local a, b, n = ns.lua.signal(), ns.lua.signal(), 0
    a:Subscribe(function() n = n + 1 end)
    b:Fire()
    assert.equals(0, n)
    a:Fire()
    assert.equals(1, n)
  end)
end)
