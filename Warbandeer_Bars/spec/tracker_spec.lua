local bars = require("Warbandeer_Bars.spec.bars")

describe("Warbandeer_Bars tracker", function()
  local ns

  before_each(function()
    ns = bars.load()
  end)

  describe("shouldStore (sparse-capture guard)", function()
    -- A minimal profile carrying only what the guard inspects: its slot count.
    local function profile(nSlots)
      local slots = {}
      for i = 1, nSlots do slots[i] = { id = i } end
      return { slots = slots }
    end

    it("stores when no profile exists yet, even under the guard", function()
      assert.is_true(ns.shouldStore(nil, profile(0), true))
    end)

    it("stores an unguarded capture even when it is sparser (the change-driven path)", function()
      -- The change-driven snapshot must record a legitimate reduction.
      assert.is_true(ns.shouldStore(profile(40), profile(5), false))
    end)

    it("skips a guarded capture that is sparser than the stored profile", function()
      -- The login/spec race: bars not yet populated → keep the good profile.
      assert.is_false(ns.shouldStore(profile(40), profile(5), true))
    end)

    it("stores a guarded capture with an equal slot count", function()
      assert.is_true(ns.shouldStore(profile(40), profile(40), true))
    end)

    it("stores a guarded capture that is richer than the stored profile", function()
      assert.is_true(ns.shouldStore(profile(40), profile(41), true))
    end)
  end)

  describe("change-driven snapshots (#984)", function()
    -- tracker.lua loaded with its call-time globals stubbed through the environment and a recording ns.
    local t, env, debounced, captures, registered, after_fns, delayed, pending, now

    local function advance(ms)  -- move the simulated clock; fire the pending debounces that fall due
      now = now + ms
      local due = {}
      for key, p in pairs(pending) do
        if p.due <= now then pending[key] = nil; due[#due + 1] = p.fn end
      end
      for _, fn in ipairs(due) do fn() end
    end

    local function profile(nSlots)
      local slots = {}
      for i = 1, nSlots do slots[i] = { id = i } end
      return { char = "Lurias", specID = 62, slots = slots }
    end

    before_each(function()
      env = { combat = false, cursor = false }
      debounced, captures, registered, after_fns, delayed = {}, {}, {}, {}, {}
      pending, now = {}, 0
      local chunk = assert(loadfile("Warbandeer_Bars/tracker.lua"))
      setfenv(chunk, setmetatable({
        InCombatLockdown = function() return env.combat end,
        GetCursorInfo = function() return env.cursor and "item" or nil end,
      }, { __index = _G }))
      t = {
        db = { profiles = {} },
        registerEvent = function(_, name) registered[#registered + 1] = name end,
        -- records every call; `pending[key]` models the real reset-trailing debounce on a simulated clock (`now`, in ms)
        debounce = function(_, key, ms, fn)
          debounced[#debounced + 1] = { key = key, ms = ms, fn = fn }
          pending[key] = { due = now + ms, fn = fn }
        end,
        after = function(_, ms, fn) after_fns[#after_fns + 1] = { ms = ms, fn = fn } end,
        delay = function(_, ms, fn) delayed[#delayed + 1] = { ms = ms, fn = fn } end,
        CaptureLayouts = function() end,
        nSlots = 10,
      }
      t.Capture = function(_, _, _, cursorFree)
        captures[#captures + 1] = { cursorFree = cursorFree }
        -- a cursor-path capture picks actions up and puts them back, which fires bar events at us
        if not cursorFree then t.ACTIONBAR_SLOT_CHANGED() end
        return profile(t.nSlots)
      end
      chunk("Warbandeer_Bars", t)
    end)

    local function login()  -- run the pending login timer (the login snapshot, then arming)
      t:onLogin()
      after_fns[1].fn()
    end

    it("nothing snapshots at PLAYER_LOGOUT", function()
      login()
      t.PLAYER_LOGOUT()
      assert.equal(1, #captures)       -- only the login snapshot
    end)

    it("a change timer still pending at logout captures nothing", function()
      login()
      t.ACTIONBAR_SLOT_CHANGED()
      t.PLAYER_LOGOUT()
      advance(10000)
      assert.equal(1, #captures)
    end)

    it("a burst of slot changes schedules one snapshot, 10 s after the last", function()
      login()
      t.ACTIONBAR_SLOT_CHANGED(); t.ACTIONBAR_SLOT_CHANGED(); t.ACTIONBAR_SLOT_CHANGED()
      -- every event restarts the wait on the SAME keyed timer (the debounce replaces the pending call)
      assert.equal(3, #debounced)
      for _, d in ipairs(debounced) do
        assert.equal("change", d.key)
        assert.equal(10000, d.ms)
      end
      assert.equal(1, #captures)       -- only the login snapshot so far
      advance(10000)
      assert.equal(2, #captures)
      advance(10000)
      assert.equal(2, #captures)       -- one snapshot, not one per event
    end)

    it("a change 9 s after the previous one pushes the snapshot back again", function()
      login()
      t.ACTIONBAR_SLOT_CHANGED()
      advance(9000)
      assert.equal(1, #captures)
      t.ACTIONBAR_SLOT_CHANGED()       -- restarts the wait
      advance(9000)                    -- 18 s after the first change, 9 s after the second
      assert.equal(1, #captures)
      advance(1000)                    -- 10 s after the second
      assert.equal(2, #captures)
    end)

    it("a login-time error does not leave change tracking switched off", function()
      t.CaptureLayouts = function() error("boom") end
      t:onLogin()
      assert.has_error(function() after_fns[1].fn() end)
      t.ACTIONBAR_SLOT_CHANGED()
      assert.equal(1, #debounced)
    end)

    it("a change due while the cursor holds something is tried again after another quiet period", function()
      login()
      t.ACTIONBAR_SLOT_CHANGED()
      env.cursor = true
      advance(10000)
      assert.equal(1, #captures)       -- skipped: the cursor is held
      env.cursor = false
      advance(10000)
      assert.equal(2, #captures)
    end)

    it("macro and binding changes schedule it too", function()
      login()
      t.UPDATE_MACROS()
      t.UPDATE_BINDINGS()
      assert.equal(2, #debounced)
    end)

    it("registers the change events and PLAYER_REGEN_ENABLED", function()
      local seen = {}
      for _, n in ipairs(registered) do seen[n] = true end
      for _, n in ipairs({ "ACTIONBAR_SLOT_CHANGED", "UPDATE_MACROS", "UPDATE_BINDINGS", "PLAYER_REGEN_ENABLED" }) do
        assert.is_true(seen[n], n)
      end
    end)

    it("change events before the login snapshot has run are ignored", function()
      t.ACTIONBAR_SLOT_CHANGED(); t.UPDATE_MACROS(); t.UPDATE_BINDINGS()
      assert.equal(0, #debounced)
    end)

    it("the event the login snapshot's own cursor path fires does not schedule a change snapshot", function()
      -- the stub Capture fires a bar event during the cursor-path login capture; arming comes after it
      login()
      assert.equal(0, #debounced)
    end)

    it("events fired by a cursor-path capture are ignored", function()
      login()
      t.Snapshot(false, false)   -- e.g. the snapshot command: fires a bar event from inside Capture
      assert.equal(0, #debounced)
    end)

    it("a capture that errors does not leave the capturing flag stuck", function()
      login()
      t.Capture = function() error("boom") end
      assert.has_error(function() t.Snapshot(false, false) end)
      t.ACTIONBAR_SLOT_CHANGED()
      assert.equal(1, #debounced)
    end)

    it("the change snapshot is cursor-free", function()
      login()
      t.ACTIONBAR_SLOT_CHANGED()
      debounced[1].fn()
      assert.is_true(captures[#captures].cursorFree)
    end)

    it("a change snapshot due in combat runs after combat", function()
      login()
      t.ACTIONBAR_SLOT_CHANGED()
      env.combat = true
      debounced[1].fn()
      assert.equal(1, #captures)         -- nothing captured while in combat
      env.combat = false
      t.PLAYER_REGEN_ENABLED()
      assert.equal(2, #captures)
      assert.is_true(captures[2].cursorFree)
      t.PLAYER_REGEN_ENABLED()           -- the pending flag was consumed
      assert.equal(2, #captures)
    end)

    it("leaving combat with nothing pending captures nothing", function()
      login()
      t.PLAYER_REGEN_ENABLED()
      assert.equal(1, #captures)
    end)

    it("the change snapshot stores a reduction (unguarded)", function()
      t.nSlots = 40
      login()                              -- stores 40 slots
      assert.equal(40, #t.db.profiles.Lurias[62].slots)
      t.nSlots = 5
      t.ACTIONBAR_SLOT_CHANGED()
      debounced[1].fn()
      assert.equal(5, #t.db.profiles.Lurias[62].slots)
    end)

    it("a spec change and a bar change don't cancel each other's pending snapshot", function()
      login()
      t.ACTIVE_TALENT_GROUP_CHANGED()
      t.ACTIONBAR_SLOT_CHANGED()
      assert.equal(1, #delayed)                 -- the spec change's own (shared) timer
      assert.equal("change", debounced[1].key)  -- the bar change's keyed timer, not `delay`
      delayed[1].fn()
      debounced[1].fn()
      assert.equal(3, #captures)                -- login + spec change + bar change
    end)

    it("an in-session snapshot (login, spec change, snapshot command) is not cursor-free", function()
      login()
      t.Snapshot()
      assert.is_falsy(captures[1].cursorFree)
      assert.is_falsy(captures[2].cursorFree)
    end)
  end)
end)
