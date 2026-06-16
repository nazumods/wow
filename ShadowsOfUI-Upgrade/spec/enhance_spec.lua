local up = require("ShadowsOfUI-Upgrade.spec.upgrade")

-- Build an item link string with a given enchant id (field 2 of the itemString).
-- `enchant` nil → no enchant field at all (a freshly-looted item); 0 → explicit 0.
local function link(itemID, enchant)
  return ("|cffffffff|Hitem:%d:%s::::|h[item]|h|r"):format(itemID, enchant == nil and "" or tostring(enchant))
end

-- An equipped-slot entry as the data layer stores it.
local function slot(itemID, enchant, equipLoc)
  return { link = link(itemID, enchant), ilvl = 600, equipLoc = equipLoc }
end

describe("ShadowsOfUI-Upgrade enhance", function()
  local ns, h
  before_each(function() h = up.harness(); ns = h.ns end)

  describe("ItemEnchantID", function()
    it("reads the enchant id from a link", function()
      assert.equals(7900, ns.ItemEnchantID(link(1001, 7900)))
    end)

    it("returns 0 for an unenchanted item (empty or absent field)", function()
      assert.equals(0, ns.ItemEnchantID(link(1001, 0)))
      assert.equals(0, ns.ItemEnchantID(link(1001, nil)))
    end)

    it("returns 0 for a nil link", function()
      assert.equals(0, ns.ItemEnchantID(nil))
    end)

    it("parses a bare itemString too", function()
      assert.equals(42, ns.ItemEnchantID("item:1001:42:::"))
    end)
  end)

  describe("MissingEnchants", function()
    local function char(slots)
      return { name = "Toon", classKey = "Mage", equipment = { slots = slots } }
    end

    it("returns nothing without scanned equipment", function()
      assert.same({}, ns.MissingEnchants({ name = "Toon" }))
      assert.same({}, ns.MissingEnchants(nil))
    end)

    it("flags an enchantable slot with no enchant, in slot order", function()
      local res = ns.MissingEnchants(char({
        Chest    = slot(1, nil),
        Shoulder = slot(2, 0),
        Legs     = slot(3, 7900),   -- enchanted: not flagged
      }))
      assert.equals(2, #res)
      assert.equals("Shoulder", res[1].slot)  -- ENCHANT_ORDER puts Shoulder before Chest
      assert.equals("Chest", res[2].slot)
    end)

    it("ignores slots that never take an enchant (Neck/Waist/Hands, and Midnight's Back/Wrist)", function()
      local res = ns.MissingEnchants(char({
        Neck  = slot(1, nil),
        Waist = slot(2, nil),
        Hands = slot(3, nil),
        Back  = slot(4, nil),   -- cloak: not enchantable in Midnight
        Wrist = slot(5, nil),   -- bracer: not enchantable in Midnight
      }))
      assert.same({}, res)
    end)

    it("skips an empty slot", function()
      assert.same({}, ns.MissingEnchants(char({ Chest = nil })))
    end)

    it("flags an unenchanted off-hand weapon", function()
      local res = ns.MissingEnchants(char({ OffHand = slot(1, nil, "INVTYPE_WEAPONOFFHAND") }))
      assert.equals(1, #res)
      assert.equals("OffHand", res[1].slot)
    end)

    it("does not flag an off-hand shield or holdable (can't be enchanted)", function()
      assert.same({}, ns.MissingEnchants(char({ OffHand = slot(1, nil, "INVTYPE_SHIELD") })))
      assert.same({}, ns.MissingEnchants(char({ OffHand = slot(2, nil, "INVTYPE_HOLDABLE") })))
    end)
  end)

  describe("RecommendedEnchant", function()
    -- A Frost Mage (spec 64 = MAGE index 3). Tests set ns.StatPriority.MAGE[3]
    -- explicitly so the top stat is deterministic regardless of the shipped table.
    local function mage()
      return { name = "Frost", classKey = "Mage",
               basic = { specialization = { id = 64 } } }
    end

    before_each(function()
      _G.ClassCodexGearData = nil   -- bundled path unless a test opts into ClassCodex
      ns.StatPriority.MAGE[3] = { haste = 1, crit = 2, mastery = 3, versatility = 4 }
      ns.Enchants = {
        Finger = { byStat = { haste = 11, crit = 12, mastery = 13, versatility = 14 } },
        Weapon = { fixed = 99 },
      }
    end)

    it("picks the stat-variant matching the character's top secondary", function()
      local s = ns.RecommendedEnchant(mage(), "Finger1")
      assert.equals("spell", s.kind)
      assert.equals(11, s.id)        -- haste is tier 1
      assert.equals("haste", s.stat)
    end)

    it("maps both rings onto the shared Finger family", function()
      assert.equals(11, ns.RecommendedEnchant(mage(), "Finger2").id)
    end)

    it("maps both weapon slots onto the shared fixed Weapon enchant", function()
      assert.equals(99, ns.RecommendedEnchant(mage(), "MainHand").id)
      assert.equals(99, ns.RecommendedEnchant(mage(), "OffHand").id)
    end)

    it("returns the fixed recipe regardless of spec", function()
      local s = ns.RecommendedEnchant({ name = "NoSpec" }, "MainHand")
      assert.equals("spell", s.kind)
      assert.equals(99, s.id)
    end)

    it("is nil for a stat-variant slot when the spec is unknown", function()
      assert.is_nil(ns.RecommendedEnchant({ name = "NoSpec" }, "Finger1"))
    end)

    it("is nil for a slot with no bundled recommendation", function()
      assert.is_nil(ns.RecommendedEnchant(mage(), "Back"))
    end)

    it("falls to the next-best stat when the top one has no variant", function()
      ns.StatPriority.MAGE[3] = { mastery = 1, haste = 2, crit = 3, versatility = 4 }
      ns.Enchants.Finger = { byStat = { haste = 11, crit = 12 } }  -- no mastery variant
      local s = ns.RecommendedEnchant(mage(), "Finger1")
      assert.equals(11, s.id)        -- haste is the best stat that has a variant
      assert.equals("haste", s.stat)
    end)

    describe("ClassCodex source (preferred when installed)", function()
      before_each(function()
        _G.GetSpecializationInfoByID = function(id) return id, "Frost" end  -- → specKey "frost"
        _G.ClassCodexGearData = { MAGE = { frost = { enchants = {
          { slot = "Ring",   best = { itemId = 500, name = "Enchant Ring - CC Pick" } },
          { slot = "Weapon", best = { itemId = 501, name = "Enchant Weapon - CC Pick" } },
        } } } }
      end)
      after_each(function() _G.GetSpecializationInfoByID = nil end)

      it("returns the per-spec pick, overriding the bundled recipe", function()
        local s = ns.RecommendedEnchant(mage(), "Finger1")
        assert.equals("item", s.kind)
        assert.equals(500, s.id)
        assert.equals("Enchant Ring - CC Pick", s.name)
      end)

      it("tolerates singular/plural slot strings and maps weapons", function()
        assert.equals("Enchant Weapon - CC Pick", ns.RecommendedEnchant(mage(), "OffHand").name)
      end)

      it("falls back to the bundled recipe when CC has no row for the slot", function()
        local s = ns.RecommendedEnchant(mage(), "Chest")  -- not in the CC stub
        -- bundled has no Chest row here either, so nil — proves it didn't error on CC
        assert.is_nil(s)
      end)

      it("falls back when the global is malformed", function()
        _G.ClassCodexGearData = { MAGE = "broken" }
        local s = ns.RecommendedEnchant(mage(), "Finger1")
        assert.equals("spell", s.kind)   -- bundled
        assert.equals(11, s.id)
      end)
    end)
  end)

  describe("Upgrade:MissingEnchants (published)", function()
    it("resolves the character by name through the data layer", function()
      h.addChar({ name = "Toon", classKey = "Mage", equipment = { slots = {
        Chest = slot(1, nil), Legs = slot(2, 7900),
      } } })
      local res = h.Api:MissingEnchants("Toon")
      assert.equals(1, #res)
      assert.equals("Chest", res[1].slot)
    end)

    it("is empty for an unknown character", function()
      assert.same({}, h.Api:MissingEnchants("Ghost"))
    end)
  end)
end)
