-- eventListener.lua isn't part of the libn.lua harness (createEventListener
-- calls CreateFrame), so this spec loads it standalone against a stub frame + a
-- controllable C_Timer, then drives the debounce() reset-trailing timer.
-- Sibling to coalesce_spec: the key contrast is LAST-call-wins vs first-wins.

describe("LibNAddOn debounce", function()
  local addOn, timers

  -- Queue scheduled callbacks instead of running them; flush() fires the batch
  -- in scheduling order, so a superseded generation's timer no-ops.
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
    addOn:debounce("k", 250, function() n = n + 1 end)
    assert.equals(0, n)                 -- trailing edge: nothing runs synchronously
    assert.equals(1, #timers)
    assert.equals(0.25, timers[1].delay)
    flush()
    assert.equals(1, n)
  end)

  it("collapses a same-key burst into a single fire", function()
    local n = 0
    for _ = 1, 10 do addOn:debounce("k", 250, function() n = n + 1 end) end
    assert.equals(10, #timers)          -- each call reschedules (unlike coalesce, which drops)
    flush()
    assert.equals(1, n)                 -- but only the newest generation passes its guard
  end)

  it("runs the LAST call's fn in a burst, superseding earlier ones", function()
    local calls = {}
    addOn:debounce("k", 250, function() table.insert(calls, "first") end)
    addOn:debounce("k", 250, function() table.insert(calls, "second") end)
    flush()
    assert.same({ "second" }, calls)    -- reset-trailing: newest wins (coalesce would keep "first")
  end)

  it("keeps different keys independent", function()
    local a, b = 0, 0
    addOn:debounce("a", 250, function() a = a + 1 end)
    addOn:debounce("b", 250, function() b = b + 1 end)
    flush()
    assert.equals(1, a)
    assert.equals(1, b)
  end)

  it("fires again on a fresh call after a previous fire", function()
    local n = 0
    local function bump() n = n + 1 end
    addOn:debounce("k", 250, bump)
    flush()
    assert.equals(1, n)
    addOn:debounce("k", 250, bump)      -- new generation after the previous settled
    flush()
    assert.equals(2, n)
  end)
end)
