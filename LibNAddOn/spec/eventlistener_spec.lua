-- eventListener.lua isn't part of the libn.lua harness (createEventListener calls CreateFrame), so
-- this spec loads it standalone against a stub frame that records its registered events and its
-- scripts, then fires events by calling the captured OnEvent script the way WoW would.
-- Covers the ADDON_LOADED convenience handler (onLoad / onLogin) and `delay`; coalesce / debounce
-- have their own specs.

describe("LibNAddOn eventListener", function()
  local addOn, frame, registered

  ---Fire a game event at the add-on through the frame's OnEvent script.
  local function fire(event, ...)
    frame.scripts.OnEvent(frame, event, ...)
  end

  before_each(function()
    registered, frame = {}, nil
    _G.CreateFrame = function()
      frame = { scripts = {} }
      function frame.RegisterEvent(_, e) registered[e] = true end
      function frame.UnregisterEvent(_, e) registered[e] = nil end
      function frame.SetScript(_, name, fn) frame.scripts[name] = fn end
      return frame
    end
    local ns = {}
    assert(loadfile("LibNAddOn/eventListener.lua"))("LibNAddOn", ns)
    addOn = { _NAME = "Test" }
    ns.createEventListener(addOn)
  end)

  after_each(function()
    _G.CreateFrame = nil
  end)

  describe("ADDON_LOADED convenience handler", function()
    it("is registered up front", function()
      assert.is_true(registered.ADDON_LOADED)
    end)

    it("calls onLoad once for its own add-on", function()
      local n = 0
      function addOn:onLoad() n = n + 1 end
      fire("ADDON_LOADED", "Test")
      assert.equals(1, n)
    end)

    it("ignores another add-on's ADDON_LOADED", function()
      local n = 0
      function addOn:onLoad() n = n + 1 end
      fire("ADDON_LOADED", "SomethingElse")
      assert.equals(0, n)
    end)

    it("passes the add-on as self to onLoad", function()
      local got
      function addOn:onLoad() got = self end
      fire("ADDON_LOADED", "Test")
      assert.equals(addOn, got)
    end)

    it("does nothing when no onLoad is defined", function()
      assert.has_no.errors(function() fire("ADDON_LOADED", "Test") end)
    end)

    it("runs the ADDON_LOADED method, then onLoad, then handlers registered afterwards", function()
      local order = {}
      function addOn:ADDON_LOADED() order[#order + 1] = "method" end
      function addOn:onLoad() order[#order + 1] = "onLoad" end
      addOn:registerEvent("ADDON_LOADED", function() order[#order + 1] = "late" end)
      fire("ADDON_LOADED", "Test")
      assert.same({ "method", "onLoad", "late" }, order)
    end)

    it("lets a handler inserted at index 1 run before onLoad", function()
      local order = {}
      function addOn:onLoad() order[#order + 1] = "onLoad" end
      addOn:registerEvent("ADDON_LOADED", function() order[#order + 1] = "early" end, 1)
      fire("ADDON_LOADED", "Test")
      assert.same({ "early", "onLoad" }, order)
    end)

    it("only registers PLAYER_ENTERING_WORLD for onLogin once the add-on has loaded", function()
      function addOn:onLogin() end
      assert.is_nil(registered.PLAYER_ENTERING_WORLD)
      fire("ADDON_LOADED", "SomethingElse")
      assert.is_nil(registered.PLAYER_ENTERING_WORLD)
      fire("ADDON_LOADED", "Test")
      assert.is_true(registered.PLAYER_ENTERING_WORLD)
    end)

    it("does not register PLAYER_ENTERING_WORLD without an onLogin", function()
      fire("ADDON_LOADED", "Test")
      assert.is_nil(registered.PLAYER_ENTERING_WORLD)
    end)

    it("calls onLogin on login or reload, but not on a plain zone change", function()
      local calls = {}
      function addOn:onLogin(login, reload) calls[#calls + 1] = { login, reload } end
      fire("ADDON_LOADED", "Test")
      fire("PLAYER_ENTERING_WORLD", true, false)
      fire("PLAYER_ENTERING_WORLD", false, true)
      fire("PLAYER_ENTERING_WORLD", false, false)
      assert.same({ { true, false }, { false, true } }, calls)
    end)
  end)

  describe("delay", function()
    -- OnUpdate elapsed is in seconds; delay compares in milliseconds.
    local function tick(seconds) frame.scripts.OnUpdate(frame, seconds) end

    it("arms an OnUpdate script on the listener frame", function()
      addOn:delay(100, function() end)
      assert.is_function(frame.scripts.OnUpdate)
    end)

    it("fires once the accumulated elapsed time reaches ms, then disarms", function()
      local n = 0
      addOn:delay(100, function() n = n + 1 end)
      tick(0.04)
      tick(0.04)
      assert.equals(0, n)
      tick(0.04)
      assert.equals(1, n)
      assert.is_nil(frame.scripts.OnUpdate)
    end)

    it("fires on exactly ms", function()
      local n = 0
      addOn:delay(100, function() n = n + 1 end)
      tick(0.1)
      assert.equals(1, n)
    end)

    it("calls a method by name with the add-on as self when given a string", function()
      local got
      function addOn:refresh() got = self end
      addOn:delay(10, "refresh")
      tick(0.5)
      assert.equals(addOn, got)
    end)

    it("replaces a pending callback and restarts the clock on a second call", function()
      local calls = {}
      addOn:delay(100, function() calls[#calls + 1] = "first" end)
      tick(0.09)
      addOn:delay(100, function() calls[#calls + 1] = "second" end)
      tick(0.09)
      assert.same({}, calls)            -- 90ms into the new window, not 180ms
      tick(0.02)
      assert.same({ "second" }, calls)  -- "first" was dropped
    end)
  end)
end)
