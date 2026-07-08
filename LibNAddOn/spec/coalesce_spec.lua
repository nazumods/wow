-- eventListener.lua isn't part of the libn.lua harness (createEventListener
-- calls CreateFrame), so this spec loads it standalone against a stub frame + a
-- controllable C_Timer, then drives the coalesce() trailing-edge timer.

describe("LibNAddOn coalesce", function()
  local addOn, timers

  -- Queue scheduled callbacks instead of running them; flush() fires the batch.
  local function flush()
    local batch = timers
    timers = {}
    for _, t in ipairs(batch) do t.fn() end
  end

  before_each(function()
    timers = {}
    _G.C_Timer = { After = function(delay, fn) table.insert(timers, { delay = delay, fn = fn }) end }
    _G.CreateFrame = function()
      return { RegisterEvent = function() end, UnregisterEvent = function() end, SetScript = function() end }
    end

    local ns = {}
    assert(loadfile("LibNAddOn/eventListener.lua"))("LibNAddOn", ns)
    addOn = { _NAME = "Test" }
    ns.createEventListener(addOn)
  end)

  it("schedules a trailing-edge fire, converting ms to seconds", function()
    local n = 0
    addOn:coalesce("k", 250, function() n = n + 1 end)
    assert.equals(0, n)                 -- trailing edge: nothing runs synchronously
    assert.equals(1, #timers)
    assert.equals(0.25, timers[1].delay)
    flush()
    assert.equals(1, n)
  end)

  it("collapses a same-key storm into a single fire", function()
    local n = 0
    for _ = 1, 10 do addOn:coalesce("k", 250, function() n = n + 1 end) end
    assert.equals(1, #timers)           -- only the first call scheduled a timer
    flush()
    assert.equals(1, n)
  end)

  it("keeps different keys independent", function()
    local a, b = 0, 0
    addOn:coalesce("a", 250, function() a = a + 1 end)
    addOn:coalesce("b", 250, function() b = b + 1 end)
    assert.equals(2, #timers)
    flush()
    assert.equals(1, a)
    assert.equals(1, b)
  end)

  it("opens a fresh window after firing", function()
    local n = 0
    local function bump() n = n + 1 end
    addOn:coalesce("k", 250, bump)
    flush()
    assert.equals(1, n)
    addOn:coalesce("k", 250, bump)      -- window reopened after the fire cleared the key
    assert.equals(1, #timers)
    flush()
    assert.equals(2, n)
  end)

  it("runs the first call's fn in a window and drops later ones", function()
    local calls = {}
    addOn:coalesce("k", 250, function() table.insert(calls, "first") end)
    addOn:coalesce("k", 250, function() table.insert(calls, "second") end)
    flush()
    assert.same({ "first" }, calls)
  end)
end)
