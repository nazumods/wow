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

    it("stores an unguarded capture even when it is sparser (logout path)", function()
      -- The logout snapshot must record a legitimate reduction.
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

  describe("the logout snapshot (#984)", function()
    -- tracker.lua loaded with the call-time globals Snapshot reads stubbed through its environment.
    local seen
    local function load_tracker()
      seen = {}
      local chunk = assert(loadfile("Warbandeer_Bars/tracker.lua"))
      setfenv(chunk, setmetatable({
        InCombatLockdown = function() return false end,
        GetCursorInfo = function() return nil end,
      }, { __index = _G }))
      local t = { registerEvent = function() end, db = { profiles = {} } }
      t.Capture = function(_, _, _, noCursor)
        seen[#seen + 1] = { noCursor = noCursor }
        return { char = "Lurias", specID = 62, slots = {} }
      end
      chunk("Warbandeer_Bars", t)
      return t
    end

    it("PLAYER_LOGOUT captures with noCursor set", function()
      local t = load_tracker()
      t.PLAYER_LOGOUT()
      assert.same({ { noCursor = true } }, seen)
    end)

    it("an in-session snapshot (login, spec change, snapshot command) does not set noCursor", function()
      local t = load_tracker()
      t.Snapshot(true)
      t.Snapshot()
      assert.equal(2, #seen)
      assert.is_falsy(seen[1].noCursor)
      assert.is_falsy(seen[2].noCursor)
    end)
  end)
end)
