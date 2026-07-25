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

  it("stamps the profile as schema v3", function()
    assert.equal(3, capture({}).version)
  end)
end)
