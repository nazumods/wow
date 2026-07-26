local collected = require("Warbandeer_Collected.spec.collected")

-- The sample string from Blizzard's own format comment (Blizzard_TransmogShared.lua). Decoding
-- this and re-encoding it byte-for-byte is the wire-compatibility test: our strings have to be
-- interchangeable with the ones the game emits and accepts.
local BLIZZ_SAMPLE = "/customset v1 7019,7017,0,0,7022,0,0,7015,7020,7016,7018,7021,70216,0,0,0,0"

-- Build a 17-value payload from a sparse map of {position = value}, defaulting the rest to 0.
-- Positions are the wire order documented in outfitcodec.lua, so a test can name the one field
-- it cares about instead of writing out seventeen zeros.
local function payload(overrides)
  local v = {}
  for i = 1, 17 do v[i] = overrides[i] or 0 end
  return "/customset v1 " .. table.concat(v, ",")
end

describe("outfit codec", function()
  local ns
  before_each(function() ns = collected.load() end)

  describe("EmptyOutfitList", function()
    it("has one zeroed entry per equippable slot", function()
      local list = ns.EmptyOutfitList()
      assert.equal(INVSLOT_LAST_EQUIPPED, #list)
      for _, info in ipairs(list) do
        assert.equal(0, info.appearanceID)
        assert.equal(0, info.secondaryAppearanceID)
        assert.equal(0, info.illusionID)
      end
    end)
  end)

  describe("EncodeOutfit", function()
    it("emits 17 values for an empty outfit", function()
      local str = ns.EncodeOutfit(ns.EmptyOutfitList())
      local n = 0
      for _ in str:gmatch("[^,]+") do n = n + 1 end
      assert.equal(17, n)
      assert.equal(payload({}), str)
    end)

    it("tolerates a list missing entries for slots the format carries", function()
      assert.equal(payload({}), ns.EncodeOutfit({}))
    end)
  end)

  describe("DecodeOutfit", function()
    it("round-trips Blizzard's own sample string byte-for-byte", function()
      local list, err = ns.DecodeOutfit(BLIZZ_SAMPLE)
      assert.is_nil(err)
      assert.equal(BLIZZ_SAMPLE, ns.EncodeOutfit(list))
    end)

    it("lands each value of the sample in the right slot", function()
      local list = assert(ns.DecodeOutfit(BLIZZ_SAMPLE))
      assert.equal(7019, list[INVSLOT_HEAD].appearanceID)
      assert.equal(7017, list[INVSLOT_SHOULDER].appearanceID)
      assert.equal(7022, list[INVSLOT_CHEST].appearanceID)
      assert.equal(7015, list[INVSLOT_WRIST].appearanceID)
      assert.equal(7020, list[INVSLOT_HAND].appearanceID)
      assert.equal(7016, list[INVSLOT_WAIST].appearanceID)
      assert.equal(7018, list[INVSLOT_LEGS].appearanceID)
      assert.equal(7021, list[INVSLOT_FEET].appearanceID)
      assert.equal(70216, list[INVSLOT_MAINHAND].appearanceID)
      assert.equal(0, list[INVSLOT_BACK].appearanceID)
      assert.equal(0, list[INVSLOT_OFFHAND].appearanceID)
    end)

    it("carries shirt and tabard, which the armor grid never supplies", function()
      -- positions 6 and 7 are Body(shirt).app and Tabard.app
      local list = assert(ns.DecodeOutfit(payload({ [6] = 4242, [7] = 5353 })))
      assert.equal(4242, list[INVSLOT_BODY].appearanceID)
      assert.equal(5353, list[INVSLOT_TABARD].appearanceID)
      assert.equal(payload({ [6] = 4242, [7] = 5353 }), ns.EncodeOutfit(list))
    end)

    -- #654: a hidden slot travels as the hide visual's own sourceID, and an empty one as 0. The
    -- codec has no idea which is which — that's the point. What it has to guarantee is that it
    -- never conflates them, so a look exported with a hidden helm imports back hidden and not as
    -- "no transmog" (which would render the wearer's equipped helm instead).
    it("keeps a hidden slot's appearance distinct from an empty one", function()
      local HIDE_HELM = 55023
      local str = payload({ [1] = HIDE_HELM })
      local list = assert(ns.DecodeOutfit(str))
      assert.equal(HIDE_HELM, list[INVSLOT_HEAD].appearanceID)
      assert.equal(0, list[INVSLOT_CHEST].appearanceID)
      assert.equal(str, ns.EncodeOutfit(list))
    end)

    it("round-trips both illusions and both secondaries", function()
      -- 3 = shoulder secondary, 14 = main-hand secondary, 15/17 = main/off-hand illusions
      local str = payload({ [2] = 11, [3] = 22, [13] = 33, [14] = -1, [15] = 44, [16] = 55, [17] = 66 })
      local list = assert(ns.DecodeOutfit(str))
      assert.equal(22, list[INVSLOT_SHOULDER].secondaryAppearanceID)
      assert.equal(-1, list[INVSLOT_MAINHAND].secondaryAppearanceID)
      assert.equal(44, list[INVSLOT_MAINHAND].illusionID)
      assert.equal(66, list[INVSLOT_OFFHAND].illusionID)
      assert.equal(str, ns.EncodeOutfit(list))
    end)

    it("preserves -1 main-hand secondary (ordinary weapon, not a paired artifact)", function()
      local list = assert(ns.DecodeOutfit(payload({ [13] = 99, [14] = -1 })))
      assert.equal(-1, list[INVSLOT_MAINHAND].secondaryAppearanceID)
    end)

    it("clamps a negative illusion to none", function()
      local list = assert(ns.DecodeOutfit(payload({ [15] = -1, [17] = -5 })))
      assert.equal(0, list[INVSLOT_MAINHAND].illusionID)
      assert.equal(0, list[INVSLOT_OFFHAND].illusionID)
    end)

    it("accepts a bare v1 payload without the slash command", function()
      local list, err = ns.DecodeOutfit(BLIZZ_SAMPLE:gsub("^/customset%s+", ""))
      assert.is_nil(err)
      assert.equal(7019, list[INVSLOT_HEAD].appearanceID)
    end)

    it("accepts surrounding whitespace", function()
      local list, err = ns.DecodeOutfit("   " .. BLIZZ_SAMPLE .. "  \n")
      assert.is_nil(err)
      assert.equal(7019, list[INVSLOT_HEAD].appearanceID)
    end)

    it("rejects a wrong value count", function()
      local list, err = ns.DecodeOutfit("/customset v1 1,2,3")
      assert.is_nil(list)
      assert.matches("expected 17 values", err)
    end)

    it("rejects a non-numeric value", function()
      local list, err = ns.DecodeOutfit(payload({}):gsub("^(/customset v1 )0", "%1abc"))
      assert.is_nil(list)
      assert.matches("whole number", err)
    end)

    it("rejects a fractional value", function()
      local list, err = ns.DecodeOutfit(payload({}):gsub("^(/customset v1 )0", "%11%.5"))
      assert.is_nil(list)
      assert.matches("whole number", err)
    end)

    -- #760. `tonumber` accepts far more than the format does, and the old `floor(n) ~= n` test
    -- narrowed none of it: `floor(inf) == inf` is true on Lua 5.1, so `1e400` decoded to an `inf`
    -- appearance id that threw a raw Lua error once it reached the model — from a string another
    -- player can paste at you.
    it("rejects infinities however they're spelled", function()
      for _, bad in ipairs({ "1e400", "-1e400", "inf", "-inf", "1e20" }) do
        local list, err = ns.DecodeOutfit(payload({ [1] = bad }))
        assert.is_nil(list, bad .. " should not decode")
        assert.matches("whole number", err)
      end
    end)

    it("rejects hex and signed-positive forms tonumber would take", function()
      for _, bad in ipairs({ "0x10", "0X1F", "+5" }) do
        local list, err = ns.DecodeOutfit(payload({ [1] = bad }))
        assert.is_nil(list, bad .. " should not decode")
        assert.matches("whole number", err)
      end
    end)

    -- Already refused before #760, but only incidentally — `nan ~= nan` made the old integrality
    -- test fail. Pinned so the new grammar keeps it.
    it("rejects nan", function()
      local list, err = ns.DecodeOutfit(payload({ [1] = "nan" }))
      assert.is_nil(list)
      assert.matches("whole number", err)
    end)

    -- The case the digit pattern alone can't catch: all digits, and still `1e20` once parsed. It
    -- IS a whole number, so it earns its own message rather than a misleading one.
    it("rejects an all-digit value too large to be an id", function()
      local list, err = ns.DecodeOutfit(payload({ [1] = "99999999999999999999" }))
      assert.is_nil(list)
      assert.matches("too large", err)
    end)

    it("accepts the largest int32 id and refuses the next one up", function()
      local list = assert(ns.DecodeOutfit(payload({ [1] = 2147483647 })))
      assert.equal(2147483647, list[INVSLOT_HEAD].appearanceID)
      local bad, err = ns.DecodeOutfit(payload({ [1] = 2147483648 }))
      assert.is_nil(bad)
      assert.matches("too large", err)
    end)

    it("rejects a missing or unknown version prefix", function()
      assert.is_nil((ns.DecodeOutfit("/customset 1,2,3")))
      local list, err = ns.DecodeOutfit("/customset v2 1,2,3")
      assert.is_nil(list)
      assert.matches("v1", err)
    end)

    it("rejects a non-string", function()
      local list, err = ns.DecodeOutfit(nil)
      assert.is_nil(list)
      assert.matches("string", err)
    end)
  end)

  describe("OutfitInputKind", function()
    -- A real 113-character link, as measured in game (see issue #643). The display text is
    -- deliberately kept, since that is what a shift-clicked link carries.
    local LINK = "|cffffd100|Htransmogcustomset:1094:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h[Outfit]|h|r"

    it("recognizes a full chat hyperlink", function()
      assert.equal("link", ns.OutfitInputKind(LINK))
    end)

    it("recognizes bare link data re-typed out of one", function()
      assert.equal("link", ns.OutfitInputKind("transmogcustomset:1094:0:0"))
    end)

    it("recognizes both /customset shapes", function()
      assert.equal("v1", ns.OutfitInputKind(BLIZZ_SAMPLE))
      assert.equal("v1", ns.OutfitInputKind((BLIZZ_SAMPLE:gsub("^/customset%s+", ""))))
    end)

    it("tolerates surrounding whitespace on either shape", function()
      assert.equal("link", ns.OutfitInputKind("  " .. LINK .. "\n"))
      assert.equal("v1", ns.OutfitInputKind("  " .. BLIZZ_SAMPLE .. "\n"))
    end)

    -- The link test runs first, so a link whose display text opens with the version prefix must
    -- still route to the game's decoder rather than ours.
    it("reads a link as a link even when its display text looks like a v1 string", function()
      assert.equal("link", ns.OutfitInputKind("|Htransmogcustomset:1|h[v1 1,2,3]|h"))
    end)

    it("rejects anything else", function()
      assert.is_nil(ns.OutfitInputKind("/customset v2 1,2,3"))
      assert.is_nil(ns.OutfitInputKind("v1"))
      assert.is_nil(ns.OutfitInputKind("|Hitem:19019|h[Thunderfury]|h"))
      assert.is_nil(ns.OutfitInputKind(""))
      assert.is_nil(ns.OutfitInputKind(nil))
      assert.is_nil(ns.OutfitInputKind(17))
    end)
  end)
end)
