local collected = require("Warbandeer_Collected.spec.collected")

-- outfit.lua is the WoW-side half of the outfit layer, so it is loaded over a stub C_TransmogCollection
-- (call-time only: every name it reads is upvalued at load). `sets` is the game's custom-set store.
describe("custom set name validation", function()
  local ns, sets, created

  before_each(function()
    collected.load()   -- seeds the INVSLOT_* globals the file reads at load
    sets, created = { { id = 1, name = "Boylane 3" } }, {}
    local env = {
      C_Item = { GetItemInfoInstant = function() end },
      Enum = { ItemArmorSubclass = { Cloth = 1, Leather = 2, Mail = 3, Plate = 4 } },
      C_TransmogCollection = {
        GetCustomSets = function()
          local ids = {}
          for _, s in ipairs(sets) do ids[#ids + 1] = s.id end
          return ids
        end,
        GetCustomSetInfo = function(id)
          for _, s in ipairs(sets) do if s.id == id then return s.name, 0 end end
        end,
        GetNumMaxCustomSets = function() return 25 end,
        IsValidCustomSetName = function() return true end,
        NewCustomSet = function(name) created[#created + 1] = name; return 99 end,
      },
    }
    setmetatable(env, { __index = _G })
    ns = {}
    local chunk = assert(loadfile("Warbandeer_Collected/outfit.lua"))
    setfenv(chunk, env)
    chunk("Warbandeer_Collected", ns)
    ns.OutfitIcon = function() return 0 end   -- the icon pick is not under test
  end)

  it("reports a case-different existing name as a collision (#1074)", function()
    local id, err = ns.SaveCustomSet("boylane 3", {})
    assert.is_nil(id)
    assert.matches("already exists", err)
    assert.same({}, created)
  end)

  it("still accepts a genuinely new name", function()
    assert.equal(99, ns.SaveCustomSet("Boylane 4", {}))
  end)
end)
