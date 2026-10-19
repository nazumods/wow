-- data/setpieces.lua over a stub transmog API. What it earns a spec for is the unknown set id: the
-- client answers GetAllSourceIDs with nil for a set it doesn't have, and on WoW: Forever that is every
-- Retail set in the curated tables — `/collected scan` died on the first one (nazumods/wow#989).

describe("Warbandeer_Collected data/setpieces.lua", function()
  local ns

  -- Set 100 has a head (source 1), a robe (2, folds into Chest) and a weapon (3, no paper-doll slot).
  -- Any other set id is unknown to this client.
  local SOURCES = { [100] = { 1, 2, 3 } }
  local ITEMS = {
    [1] = { itemID = 11, isCollected = true, loc = "INVTYPE_HEAD" },
    [2] = { itemID = 12, isCollected = false, loc = "INVTYPE_ROBE" },
    [3] = { itemID = 13, isCollected = true, loc = "INVTYPE_WEAPON" },
  }
  local LOC_BY_ITEM = {}
  for _, it in pairs(ITEMS) do LOC_BY_ITEM[it.itemID] = it.loc end

  before_each(function()
    _G.C_TransmogSets = { GetAllSourceIDs = function(setID) return SOURCES[setID] end }
    _G.C_TransmogCollection = {
      GetSourceInfo = function(sourceID)
        local it = ITEMS[sourceID]
        return it and { itemID = it.itemID, isCollected = it.isCollected }
      end,
    }
    _G.C_Item = { GetItemInfoInstant = function(itemID) return itemID, nil, nil, LOC_BY_ITEM[itemID] end }
    ns = {}
    assert(loadfile("Warbandeer_Collected/data/setpieces.lua"))("Warbandeer_Collected", ns)
  end)

  after_each(function()
    _G.C_TransmogSets, _G.C_TransmogCollection, _G.C_Item = nil, nil, nil
  end)

  describe("a set id the client doesn't have", function()
    it("has no source ids, as an empty table rather than nil", function()
      assert.same({}, ns.SetSourceIDs(853))
    end)

    it("has no slot pieces, rather than raising", function()
      assert.same({}, ns.SetSlotPieces(853))
    end)
  end)

  describe("a set the client has", function()
    it("returns its source ids as the client gave them", function()
      assert.same({ 1, 2, 3 }, ns.SetSourceIDs(100))
    end)

    it("buckets pieces by slot, a robe into Chest, and leaves the weapon out", function()
      assert.same({
        [1] = { itemID = 11, isCollected = true },
        [5] = { itemID = 12, isCollected = false },
      }, ns.SetSlotPieces(100))
    end)

    it("maps a single source to its slot, and a weapon to none", function()
      assert.equals(1, ns.SourceSlot(1))
      assert.equals(5, ns.SourceSlot(2))
      assert.is_nil(ns.SourceSlot(3))
    end)
  end)

  -- The consumer that raised: `ns:Scan` (commands.lua), the body of `/collected scan` and of the
  -- TRANSMOG_COLLECTION_UPDATED rescan. Loaded for real; only what it reaches at load and in a scan
  -- with no window open is stubbed. Neither set has primary appearances, so both take the
  -- SetSlotPieces fallback.
  describe("ns:Scan", function()
    before_each(function()
      _G.C_TransmogSets.IsBaseSetCollected = function() return false end
      _G.C_TransmogSets.GetSetPrimaryAppearances = function() return nil end
      _G.GetTimePreciseSec = function() return 0 end
      ns.ui = {}
      ns.registerCommand = function() end
      ns.registerEvent = function() end
      ns.prof = { Scan = function() end }
      ns.db = {}
      assert(loadfile("Warbandeer_Collected/commands.lua"))("Warbandeer_Collected", ns)
    end)

    after_each(function() _G.GetTimePreciseSec = nil end)

    it("skips a set the client doesn't have and counts the one it does", function()
      ns.Sets = { { id = 1, name = "Mixed", sets = { { id = 853 }, { id = 100 } } } }
      ns:Scan()
      assert.equals(1, ns.db.total)
      assert.equals(0, ns.db.collected)
      assert.same({ [100] = { collected = 1, total = 2 } }, ns.db.sets[1])
    end)

    it("finishes with nothing counted when no set is known to the client", function()
      ns.Sets = { { id = 1, name = "Retail only", sets = { { id = 853 }, { id = 854 } } } }
      ns:Scan()
      assert.equals(0, ns.db.total)
      assert.same({ [1] = {} }, ns.db.sets)
    end)

    it("finishes with an empty set list", function()
      ns.Sets = {}
      ns:Scan()
      assert.equals(0, ns.db.total)
      assert.same({}, ns.db.sets)
    end)
  end)
end)
