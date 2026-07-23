local collected = require("Warbandeer_Collected.spec.collected")

-- Stand-in hide visuals: slot id + 90000, for the eleven armour/cosmetic slots only. The two
-- weapon slots deliberately resolve to nil, mirroring the real ns.HideVisual — nothing at
-- Enum.TransmogCollectionType 12+ carries the isHideVisual flag.
local function hideFor(slotID)
  if slotID == INVSLOT_MAINHAND or slotID == INVSLOT_OFFHAND then return nil end
  return slotID + 90000
end

describe("shareable outfits", function()
  local ns
  before_each(function() ns = collected.loadOutfitShare(collected.load()) end)

  describe("ShareableOutfit", function()
    it("fills a bare slot with that slot's hide visual", function()
      local list = ns.EmptyOutfitList()
      local out = ns.ShareableOutfit(list, nil, hideFor)
      assert.equal(hideFor(INVSLOT_BACK), out[INVSLOT_BACK].appearanceID)
      assert.equal(hideFor(INVSLOT_TABARD), out[INVSLOT_TABARD].appearanceID)
      assert.equal(hideFor(INVSLOT_HEAD), out[INVSLOT_HEAD].appearanceID)
    end)

    it("leaves a slot that carries a real appearance alone", function()
      local list = ns.EmptyOutfitList()
      list[INVSLOT_CHEST].appearanceID = 30087
      list[INVSLOT_HEAD].appearanceID = 106405
      ns.ShareableOutfit(list, nil, hideFor)
      assert.equal(30087, list[INVSLOT_CHEST].appearanceID)
      assert.equal(106405, list[INVSLOT_HEAD].appearanceID)
    end)

    -- The regression this fix could most easily cause: #654 lets the user cycle a slot to "empty",
    -- which means "no transmog — show the wearer's own gear". Baring it would override that.
    it("leaves a slot the user deliberately emptied at 0", function()
      local list = ns.EmptyOutfitList()
      local out = ns.ShareableOutfit(list, { [INVSLOT_HEAD] = true }, hideFor)
      assert.equal(0, out[INVSLOT_HEAD].appearanceID)
      assert.equal(hideFor(INVSLOT_BACK), out[INVSLOT_BACK].appearanceID, "other slots still bare")
    end)

    it("bares every slot when nothing was deliberately emptied", function()
      local out = ns.ShareableOutfit(ns.EmptyOutfitList(), {}, hideFor)
      for _, slotID in ipairs(ns.OutfitSlotOrder) do
        if slotID ~= INVSLOT_MAINHAND and slotID ~= INVSLOT_OFFHAND then
          assert.equal(hideFor(slotID), out[slotID].appearanceID, "slot " .. slotID)
        end
      end
    end)

    -- The documented limit: no hide visual exists for a weapon, so it stays 0 rather than being
    -- written something invented.
    it("leaves a slot with no hide visual at 0", function()
      local out = ns.ShareableOutfit(ns.EmptyOutfitList(), nil, hideFor)
      assert.equal(0, out[INVSLOT_MAINHAND].appearanceID)
      assert.equal(0, out[INVSLOT_OFFHAND].appearanceID)
    end)

    -- The list is dense over every equippable slot, but only the 13 the wire format carries mean
    -- anything; writing into the others would be invisible until something else read them.
    it("only touches the slots the format carries", function()
      local out = ns.ShareableOutfit(ns.EmptyOutfitList(), nil, function(slotID) return slotID + 90000 end)
      local carried = {}
      for _, slotID in ipairs(ns.OutfitSlotOrder) do carried[slotID] = true end
      for slotID = 1, INVSLOT_LAST_EQUIPPED do
        if not carried[slotID] then
          assert.equal(0, out[slotID].appearanceID, "slot " .. slotID .. " isn't in the wire format")
        end
      end
    end)

    it("leaves the secondary and illusion fields alone", function()
      local list = ns.EmptyOutfitList()
      list[INVSLOT_SHOULDER].secondaryAppearanceID = 4242
      list[INVSLOT_MAINHAND].appearanceID = 76305
      list[INVSLOT_MAINHAND].secondaryAppearanceID = -1
      list[INVSLOT_MAINHAND].illusionID = 5364
      ns.ShareableOutfit(list, nil, hideFor)
      assert.equal(4242, list[INVSLOT_SHOULDER].secondaryAppearanceID)
      assert.equal(-1, list[INVSLOT_MAINHAND].secondaryAppearanceID)
      assert.equal(5364, list[INVSLOT_MAINHAND].illusionID)
    end)

    it("returns the list it was given, and is idempotent", function()
      local list = ns.EmptyOutfitList()
      local once = ns.ShareableOutfit(list, nil, hideFor)
      assert.equal(list, once)
      local twice = ns.ShareableOutfit(ns.ShareableOutfit(ns.EmptyOutfitList(), nil, hideFor), nil, hideFor)
      assert.equal(ns.EncodeOutfit(once), ns.EncodeOutfit(twice))
    end)

    -- The whole point is that the recipient's client reads it, so it has to survive the wire.
    it("round-trips through the /customset format", function()
      local list = ns.EmptyOutfitList()
      list[INVSLOT_CHEST].appearanceID = 30087
      local shared = ns.ShareableOutfit(list, { [INVSLOT_HEAD] = true }, hideFor)
      local str = ns.EncodeOutfit(shared)
      local decoded = assert(ns.DecodeOutfit(str))
      assert.equal(str, ns.EncodeOutfit(decoded))
      assert.equal(30087, decoded[INVSLOT_CHEST].appearanceID)
      assert.equal(hideFor(INVSLOT_BACK), decoded[INVSLOT_BACK].appearanceID)
      assert.equal(0, decoded[INVSLOT_HEAD].appearanceID)
      assert.equal(0, decoded[INVSLOT_MAINHAND].appearanceID)
    end)
  end)
end)
