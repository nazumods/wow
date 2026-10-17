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

  describe("change checking by fingerprint (#984)", function()
    -- tracker.lua loaded with its call-time globals stubbed through the environment and a recording ns. A fake clock
    -- is not needed: the ticker is a plain recorded callback that each test fires by hand (one call = one 10 s check).
    local t, env, captures, after_fns, delayed, tickers, chunkEnv

    local specID = 62   -- 0 models a character with no active spec: store() refuses it

    local function profile(nSlots)
      local slots = {}
      for i = 1, nSlots do slots[i] = { id = i } end
      return { char = "Lurias", specID = specID, slots = slots }
    end

    before_each(function()
      specID = 62
      env = { combat = false, cursor = false, print = "A", C_Timer = nil }
      captures, after_fns, delayed, tickers = {}, {}, {}, {}
      env.C_Timer = {
        NewTicker = function(seconds, fn)
          local tk = { seconds = seconds, fn = fn, cancelled = false }
          function tk:Cancel() self.cancelled = true end
          tickers[#tickers + 1] = tk
          return tk
        end,
      }
      local chunk = assert(loadfile("Warbandeer_Bars/tracker.lua"))
      chunkEnv = setmetatable({
        InCombatLockdown = function() return env.combat end,
        GetCursorInfo = function() return env.cursor and "item" or nil end,
        C_Timer = env.C_Timer,
        -- env.special names the special bar that is up, if any ("override", "vehicle", "shapeshift", "possess")
        C_ActionBar = {
          HasOverrideActionBar = function() return env.special == "override" end,
          HasVehicleActionBar = function() return env.special == "vehicle" end,
          HasTempShapeshiftActionBar = function() return env.special == "shapeshift" end,
          IsPossessBarVisible = function() return env.special == "possess" end,
        },
      }, { __index = _G })
      setfenv(chunk, chunkEnv)
      t = {
        db = { profiles = {} },
        registerEvent = function() end,
        after = function(_, ms, fn) after_fns[#after_fns + 1] = { ms = ms, fn = fn } end,
        delay = function(_, ms, fn) delayed[#delayed + 1] = { ms = ms, fn = fn } end,
        CaptureLayouts = function() end,
        Fingerprint = function() return env.print end,
        nSlots = 10,
      }
      t.Capture = function(_, _, _, cursorFree)
        captures[#captures + 1] = { cursorFree = cursorFree }
        return profile(t.nSlots)
      end
      chunk("Warbandeer_Bars", t)
    end)

    local function login()  -- run the pending login timer: the login snapshot, then arming and the ticker
      t:onLogin()
      after_fns[#after_fns].fn()
    end

    local function tick()  -- one 10 s check on the live ticker
      for i = #tickers, 1, -1 do
        if not tickers[i].cancelled then tickers[i].fn(); return end
      end
      error("no live ticker")
    end

    it("no snapshot while the fingerprint is unchanged", function()
      login()
      for _ = 1, 5 do tick() end
      assert.equal(1, #captures)       -- only the login snapshot
    end)

    it("a change, then one steady tick -> exactly one snapshot, and it is cursor-free and unguarded", function()
      login()
      env.print = "B"
      tick()                            -- changed, but not yet steady
      assert.equal(1, #captures)
      tick()                            -- unchanged across one full check
      assert.equal(2, #captures)
      assert.is_true(captures[2].cursorFree)
      tick(); tick()
      assert.equal(2, #captures)        -- the new fingerprint is the stored one now
    end)

    it("a fingerprint that changes every tick -> no snapshot until it holds", function()
      login()
      for i = 1, 6 do env.print = "P" .. i; tick() end
      assert.equal(1, #captures)
      tick()                            -- P6 held for a second tick
      assert.equal(2, #captures)
    end)

    it("a snapshot that stored nothing (no spec yet) is not retried every tick", function()
      login()
      specID = 0                         -- store() refuses a profile without a spec
      env.print = "B"
      tick(); tick()
      assert.equal(2, #captures)         -- one attempt (login + this one) ...
      assert.is_nil(t.db.profiles.Lurias and t.db.profiles.Lurias[0])
      tick(); tick(); tick()
      assert.equal(2, #captures)         -- ... and no more while the fingerprint stays "B"
    end)

    it("a change that is reverted before it holds snapshots nothing", function()
      login()
      env.print = "B"; tick()
      env.print = "A"; tick(); tick()
      assert.equal(1, #captures)
    end)

    it("the snapshot stores a reduction (unguarded)", function()
      t.nSlots = 40
      login()                           -- stores 40 slots
      assert.equal(40, #t.db.profiles.Lurias[62].slots)
      t.nSlots = 5
      env.print = "B"; tick(); tick()
      assert.equal(5, #t.db.profiles.Lurias[62].slots)
    end)

    it("combat skips the tick without advancing it", function()
      login()
      env.print = "B"
      tick()                            -- changed: remembered as the last tick's print
      env.combat = true
      env.print = "C"                   -- the bars changed again during combat
      tick(); tick()                    -- skipped entirely: nothing captured, the remembered print is still "B"
      assert.equal(1, #captures)
      env.combat = false
      tick()                            -- "C" vs the remembered "B": not steady. (Had combat ticks advanced it, this would snapshot.)
      assert.equal(1, #captures)
      tick()
      assert.equal(2, #captures)
    end)

    it("a held cursor skips the tick without advancing it", function()
      login()
      env.print = "B"
      tick()
      env.cursor = true
      env.print = "C"
      tick(); tick()
      assert.equal(1, #captures)
      env.cursor = false
      tick()
      assert.equal(1, #captures)
      tick()
      assert.equal(2, #captures)
    end)

    it("a vehicle / override / possess / temp-shapeshift bar skips the tick without advancing it", function()
      for _, special in ipairs({ "override", "vehicle", "shapeshift", "possess" }) do
        captures = {}
        after_fns, tickers = {}, {}
        env.special, env.print = nil, "A"
        login()
        captures = {}                     -- count only what the ticks take
        env.print = "B"
        tick()                            -- changed: remembered as the last tick's print
        env.special = special
        env.print = "C"                   -- the main bar now shows the special bar's buttons
        tick(); tick(); tick()
        assert.equal(0, #captures, special)
        env.special = nil
        env.print = "B"                   -- the special bar went away: back to the stored-vs-last-tick state
        tick()
        assert.equal(1, #captures, special)   -- "B" held across the skipped ticks: one snapshot
      end
    end)

    it("a client without C_ActionBar, or with only some of the special-bar calls, still saves changes", function()
      -- every call is guarded: a missing one must read as "no special bar", never raise and starve the ticks
      for _, shape in ipairs({ "none", "partial", "empty" }) do
        captures = {}
        after_fns, tickers = {}, {}
        if shape == "none" then
          chunkEnv.C_ActionBar = nil
        elseif shape == "partial" then
          chunkEnv.C_ActionBar = { HasVehicleActionBar = function() return false end }
        else
          chunkEnv.C_ActionBar = {}
        end
        env.print = "A"
        login()
        captures = {}
        env.print = "B"
        assert.has_no.errors(tick, shape)
        tick()
        assert.equal(1, #captures, shape)
      end
    end)

    it("a login snapshot that stored nothing (skipped in combat) is followed by one change snapshot", function()
      env.combat = true
      login()                           -- Snapshot returns nil in combat
      assert.equal(0, #captures)
      env.combat = false
      tick()                            -- the fingerprint never matched a stored profile and is steady
      assert.equal(1, #captures)
      tick(); tick()
      assert.equal(1, #captures)
    end)

    it("a login snapshot refused as sparse is not stored by the first change snapshot either", function()
      t.nSlots = 40
      login()                           -- stores 40 slots
      assert.equal(40, #t.db.profiles.Lurias[62].slots)
      -- a second login in the same state: the bars are still unpopulated, so the guarded login snapshot is refused
      t.nSlots = 5
      login()
      assert.equal(40, #t.db.profiles.Lurias[62].slots)
      tick()                            -- steady: the first change snapshot is still sparse-guarded
      assert.equal(40, #t.db.profiles.Lurias[62].slots)
      env.print = "B"                   -- a real change afterwards is unguarded and records the reduction
      tick(); tick()
      assert.equal(5, #t.db.profiles.Lurias[62].slots)
    end)

    it("nothing before the login snapshot has armed it, and nothing after PLAYER_LOGOUT", function()
      assert.equal(0, #tickers)         -- no ticker before login
      login()
      assert.equal(1, #tickers)
      env.print = "B"
      tick()
      t.PLAYER_LOGOUT()                 -- the ticker may still fire once while the UI tears down
      tick()
      assert.equal(1, #captures)        -- only the login snapshot: no logout snapshot, no late change snapshot
    end)

    it("a login-time error does not leave change checking switched off", function()
      t.CaptureLayouts = function() error("boom") end
      t:onLogin()
      assert.has_error(function() after_fns[#after_fns].fn() end)
      assert.equal(1, #tickers)
      assert.equal(0, #captures)        -- the login work threw before its snapshot
      env.print = "B"; tick(); tick()
      assert.equal(1, #captures)        -- ... but a later change is still saved
    end)

    it("only one ticker exists after a /reload-style re-login", function()
      login()
      login()
      local live = 0
      for _, tk in ipairs(tickers) do if not tk.cancelled then live = live + 1 end end
      assert.equal(2, #tickers)
      assert.equal(1, live)
      assert.equal(10, tickers[#tickers].seconds)
    end)

    it("an unreadable fingerprint is skipped quietly", function()
      login()
      t.Fingerprint = function() error("api down") end
      assert.has_no.errors(tick)
      t.Fingerprint = function() return env.print end
      env.print = "B"
      tick()
      assert.equal(1, #captures)
      tick()
      assert.equal(2, #captures)
    end)

    it("a spec change and a fingerprint change don't interfere", function()
      login()
      t.ACTIVE_TALENT_GROUP_CHANGED()
      assert.equal(1, #delayed)         -- the spec change's own (shared) timer
      env.print = "B"; tick(); tick()
      delayed[1].fn()
      assert.equal(3, #captures)        -- login + change + spec change
      assert.is_falsy(captures[3].cursorFree)
    end)

    it("an in-session snapshot (login, spec change, snapshot command) is not cursor-free", function()
      login()
      t.Snapshot()
      assert.is_falsy(captures[1].cursorFree)
      assert.is_falsy(captures[2].cursorFree)
    end)

    it("the bar events are no longer used", function()
      for _, name in ipairs({ "ACTIONBAR_SLOT_CHANGED", "UPDATE_MACROS", "UPDATE_BINDINGS", "PLAYER_REGEN_ENABLED" }) do
        assert.is_nil(t[name], name)
      end
    end)
  end)
end)
