local bars = require("Warbandeer_Bars.spec.bars")

describe("Warbandeer_Bars capture", function()
  -- `actions` maps action-bar slot id -> { type, index, subType? } (what GetActionInfo
  -- reports); `pets` maps pet GUID -> { speciesID, customName, speciesName }.
  local function capture(actions, pets)
    local ns = bars.loadCapture{
      GetActionInfo = function(i)
        local a = actions[i]
        if not a then return nil end
        return a.type, a.index, a.subType
      end,
      C_PetJournal = {
        -- speciesID, customName, level, xp, maxXp, displayID, isFavorite, name, icon, ...
        GetPetInfoByPetID = function(guid)
          local p = pets and pets[guid]
          if not p then return nil end
          return p.speciesID, p.customName, 25, 0, 0, 0, false, p.speciesName, 1394954
        end,
      },
      UnitName             = function() return "Lurias" end,
      UnitClass            = function() return "Mage", "MAGE", 8 end,
      UnitLevel            = function() return 80 end,
      GetRealmName         = function() return "Draenor" end,
      GetCurrentBindingSet = function() return 1 end,
      time                 = function() return 1700000000 end,
    }
    return ns.Capture({ bars = true })
  end

  ---@return table  captured slots keyed by action-bar slot id
  local function slotsById(profile)
    local by = {}
    for _, s in ipairs(profile.slots) do by[s.id] = s end
    return by
  end

  describe("summonpet slots (#637)", function()
    local PET = "BattlePet-0-000011AABBCC"

    it("stores speciesID and both names alongside the GUID", function()
      local slots = slotsById(capture(
        { [3] = { type = "summonpet", index = PET } },
        { [PET] = { speciesID = 39, customName = "Fluffy", speciesName = "Mechanical Squirrel" } }))

      -- The GUID stays the restore key; the rest is what makes the slot readable offline.
      assert.equal(PET, slots[3].strindex)
      assert.equal(39, slots[3].speciesID)
      assert.equal("Mechanical Squirrel", slots[3].speciesName)
      assert.equal("Fluffy", slots[3].customName)
    end)

    it("omits customName for an unnamed pet but keeps the species", function()
      -- C_PetJournal reports an unnamed pet's customName as "" — storing that would put an
      -- empty string where a reader expects "no custom name".
      local slots = slotsById(capture(
        { [1] = { type = "summonpet", index = PET } },
        { [PET] = { speciesID = 39, customName = "", speciesName = "Mechanical Squirrel" } }))

      assert.is_nil(slots[1].customName)
      assert.equal(39, slots[1].speciesID)
      assert.equal("Mechanical Squirrel", slots[1].speciesName)
    end)

    it("still captures the slot when the journal can't resolve the GUID", function()
      -- A caged/released pet drops out of the journal; the slot must survive as a GUID.
      local slots = slotsById(capture({ [7] = { type = "summonpet", index = PET } }, {}))

      assert.equal("summonpet", slots[7].type)
      assert.equal(PET, slots[7].strindex)
      assert.is_nil(slots[7].speciesID)
      assert.is_nil(slots[7].speciesName)
      assert.is_nil(slots[7].customName)
    end)
  end)

  describe("other slot types are unchanged", function()
    it("keeps spell / item / equipmentset slots to their existing shape", function()
      local slots = slotsById(capture({
        [1] = { type = "spell", index = 133 },
        [2] = { type = "item", index = 6948 },
        [4] = { type = "equipmentset", index = "Raid" },
      }))

      assert.same({ id = 1, type = "spell", index = 133 }, slots[1])
      assert.same({ id = 2, type = "item", index = 6948 }, slots[2])
      assert.same({ id = 4, type = "equipmentset", strindex = "Raid" }, slots[4])
    end)

    it("skips empty slots", function()
      local profile = capture({ [5] = { type = "spell", index = 133 } })
      assert.equal(1, #profile.slots)
    end)
  end)

  describe("temp macros: cursor vs no-cursor resolution (#984)", function()
    -- A temp macro slot reports subType; its real index is only known via the cursor round-trip, or (logout)
    -- via its action text / the stored profile.
    local calls, cursorIndex

    local function run(opts)
      calls = {}
      local actions = opts.actions or { [7] = { type = "macro", index = 0, subType = "x" } }
      local function trace(name, fn)
        return function(...) calls[#calls + 1] = name; if fn then return fn(...) end end
      end
      local ns = bars.loadCapture{
        GetActionInfo = function(i)
          local a = actions[i]
          if not a then return nil end
          return a.type, a.index, a.subType
        end,
        PickupAction  = trace("PickupAction"),
        PlaceAction   = trace("PlaceAction"),
        ClearCursor   = trace("ClearCursor"),
        GetCursorInfo = function() return "macro", cursorIndex end,
        C_ActionBar   = { GetActionText = function() return opts.text end },
        GetMacroIndexByName = function(name) return (opts.byName or {})[name] or 0 end,
        UnitName = function() return "Lurias" end,
        UnitClass = function() return "Mage", "MAGE", 8 end,
        GetRealmName = function() return "Draenor" end,
        -- capture.lua upvalues these from C_SpecializationInfo at load (its `_G.` fallback bypasses `env`).
        C_SpecializationInfo = {
          GetSpecialization = function() return 1 end,
          GetSpecializationInfo = function() return 62, "Arcane", "", 1 end,
        },
        GetCurrentBindingSet = function() return 1 end,
        UnitLevel = function() return 80 end,
        time = function() return 1700000000 end,
      }
      ns.db = { profiles = { Lurias = { [62] = opts.stored } } }
      return slotsById(ns.Capture({ bars = true }, false, false, opts.atLogout))
    end

    before_each(function() cursorIndex = 42 end)

    it("an in-session snapshot still resolves via the cursor", function()
      local slots = run{ atLogout = false, text = "Mine", byName = { Mine = 9 } }
      assert.equal(42, slots[7].index)
      assert.same({ "PickupAction", "PlaceAction", "ClearCursor" }, calls)
    end)

    it("logout never touches the cursor", function()
      run{ atLogout = true, text = "Mine", byName = { Mine = 9 } }
      assert.same({}, calls)
    end)

    it("logout resolves a temp macro by its action text", function()
      local slots = run{ atLogout = true, text = "Mine", byName = { Mine = 9 } }
      assert.equal(9, slots[7].index)
    end)

    it("logout falls back to the stored profile's index at the same slot", function()
      local slots = run{ atLogout = true, text = "Gone",
        stored = { slots = { { id = 7, type = "macro", index = 31 } } } }
      assert.equal(31, slots[7].index)
    end)

    it("logout does not take a stored index from a slot that was not a macro", function()
      local slots = run{ atLogout = true, text = "Gone",
        stored = { slots = { { id = 7, type = "spell", index = 31 } } } }
      assert.is_nil(slots[7].index)
    end)

    it("logout matches the stored profile by slot id, not by taking any macro entry", function()
      local slots = run{ atLogout = true, text = "Gone",
        stored = { slots = { { id = 9, type = "macro", index = 77 }, { id = 7, type = "macro", index = 31 } } } }
      assert.equal(31, slots[7].index)
      local other = run{ atLogout = true, text = "Gone",
        stored = { slots = { { id = 9, type = "macro", index = 77 } } } }
      assert.is_nil(other[7].index)
    end)

    it("logout ignores an empty action text rather than looking up the empty name", function()
      local slots = run{ atLogout = true, text = "", byName = { [""] = 5 } }
      assert.is_nil(slots[7].index)
    end)

    it("logout leaves index nil when neither works", function()
      local slots = run{ atLogout = true, text = "Gone" }
      assert.is_nil(slots[7].index)
      assert.equal("macro", slots[7].type)
    end)

    it("logout keeps a non-temp macro's own index", function()
      local slots = run{ atLogout = true, actions = { [7] = { type = "macro", index = 12 } } }
      assert.equal(12, slots[7].index)
    end)
  end)

  describe("the logout snapshot's spec fallback (#984)", function()
    -- One loaded capture.lua (so its lastSpec lives across calls) whose spec info and character the test steers.
    local ns, spec, char
    local ACTIONS = { [1] = { "spell", 133 } }

    before_each(function()
      spec, char = { 62, "Arcane", "", 1 }, "Lurias"
      ns = bars.loadCapture{
        GetActionInfo = function(i) local a = ACTIONS[i]; if a then return a[1], a[2] end end,
        C_SpecializationInfo = {
          GetSpecialization = function() return 1 end,
          GetSpecializationInfo = function() return spec and spec[1], spec and spec[2], nil, spec and spec[4] end,
        },
        UnitName = function() return char end,
        UnitClass = function() return "Mage", "MAGE", 8 end,
        GetRealmName = function() return "Draenor" end,
        GetCurrentBindingSet = function() return 1 end,
        UnitLevel = function() return 80 end,
        time = function() return 1700000000 end,
      }
    end)

    local function cap(atLogout) return ns.Capture({ bars = true }, false, false, atLogout) end

    it("logout with empty spec info stores under the character's last known spec", function()
      cap(false)
      spec = nil
      local p = cap(true)
      assert.equal(62, p.specID)
      assert.equal("Arcane", p.spec)
      assert.equal(1, p.specIcon)
    end)

    it("logout with empty spec info and no last spec for this character stores nothing", function()
      spec = nil
      assert.equal(0, cap(true).specID)
    end)

    it("a last spec from another character is never used", function()
      cap(false)
      spec, char = nil, "Other"
      assert.equal(0, cap(true).specID)
    end)

    it("an in-session capture with no spec is still not stored", function()
      cap(false)
      spec = nil
      assert.equal(0, cap(false).specID)
    end)

    it("lastSpec updates on a spec change", function()
      cap(false)
      spec = { 63, "Fire", "", 2 }
      cap(false)
      spec = nil
      local p = cap(true)
      assert.equal(63, p.specID)
      assert.equal("Fire", p.spec)
    end)

    it("a capture that resolves spec id 0 does not overwrite the remembered spec", function()
      cap(false)
      spec = { 0, "None", "", 0 }
      cap(false)
      spec = nil
      assert.equal(62, cap(true).specID)
    end)

    it("a spec that resolves at logout wins over the remembered one", function()
      cap(false)
      spec = { 64, "Frost", "", 3 }
      assert.equal(64, cap(true).specID)
    end)
  end)

  it("stamps the profile as schema v3", function()
    assert.equal(3, capture({}).version)
  end)
end)
