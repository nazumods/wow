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

    it("does not flag an item below the enchant minimum ilvl", function()
      ns.EnchantMinIlvl = 120
      local lo = { link = link(1, nil), ilvl = 100, equipLoc = "INVTYPE_FINGER" }
      assert.same({}, ns.MissingEnchants(char({ Finger1 = lo })))
      -- at/above the threshold it's flagged again
      lo.ilvl = 120
      local res = ns.MissingEnchants(char({ Finger1 = lo }))
      assert.equals(1, #res)
      assert.equals("Finger1", res[1].slot)
    end)

    it("gates slots we carry no recommendation for too (Head/Legs below the floor)", function()
      ns.EnchantMinIlvl = 120
      -- Head/Legs take an enchant this season but have no bundled stat pick; they must
      -- still drop out below the floor (the original bug — only Finger/Chest/Weapon gated).
      assert.same({}, ns.MissingEnchants(char({
        Head = { link = link(1, nil), ilvl = 71 },
        Legs = { link = link(2, nil), ilvl = 77 },
      })))
    end)

    it("still flags an item with unknown ilvl (ungated)", function()
      ns.EnchantMinIlvl = 120
      local res = ns.MissingEnchants(char({
        Finger1 = { link = link(1, nil), equipLoc = "INVTYPE_FINGER" },  -- no stored ilvl
      }))
      assert.equals(1, #res)
      assert.equals("Finger1", res[1].slot)
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

    it("is nil when the equipped item is below the enchant minimum ilvl", function()
      ns.EnchantMinIlvl = 120
      local m = mage()
      m.equipment = { slots = { Finger1 = { link = "x", ilvl = 100 } } }
      assert.is_nil(ns.RecommendedEnchant(m, "Finger1"))
      -- at the threshold it recommends again
      m.equipment.slots.Finger1.ilvl = 120
      assert.equals(11, ns.RecommendedEnchant(m, "Finger1").id)
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
          { slot = "Helm",   best = { itemId = 502, name = "Enchant Helm - CC Pick" } },
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

      it("matches CC's \"Helm\" synonym onto the Head slot", function()
        local s = ns.RecommendedEnchant(mage(), "Head")
        assert.equals("item", s.kind)
        assert.equals(502, s.id)
        assert.equals("Enchant Helm - CC Pick", s.name)
      end)

      it("resolves the played (active) spec from the stored name when the numeric id is missing", function()
        -- an alt scanned before the numeric id was persisted carries only spec-name strings;
        -- the active (played) spec wins over primary (the loot spec, here a different spec)
        local stale = { name = "Stale", classKey = "Mage",
                        basic = { specialization = { primary = "Fire", active = "Frost" } } }
        local s = ns.RecommendedEnchant(stale, "Finger1")
        assert.equals("item", s.kind)
        assert.equals(500, s.id)          -- ClassCodexGearData.MAGE.frost (active), not fire (loot)
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

  describe("EnchantMismatches", function()
    -- Frost Mage with ClassCodex helm + ring picks (rec carries `.name`, so comparison is
    -- deterministic without a GetSpellName stub).
    local function mage(slots)
      return { name = "Frost", classKey = "Mage",
               basic = { specialization = { id = 64 } },
               equipment = { slots = slots } }
    end
    before_each(function()
      _G.GetSpecializationInfoByID = function(id) return id, "Frost" end
      _G.ClassCodexGearData = { MAGE = { frost = { enchants = {
        { slot = "Helm", best = { itemId = 600, name = "Enchant Helm - Best" } },
        { slot = "Ring", best = { itemId = 601, name = "Enchant Ring - Best" } },
      } } } }
    end)
    after_each(function() _G.GetSpecializationInfoByID = nil; _G.ClassCodexGearData = nil end)

    -- a slot as the data layer stores it: link (carries the enchant id) + applied enchant name
    local function ench(itemID, enchantID, name)
      return { link = link(itemID, enchantID), ilvl = 600, enchant = name }
    end

    it("flags a slot whose applied enchant differs from the recommendation", function()
      local res = ns.EnchantMismatches(mage({ Head = ench(10, 555, "Enchant Helm - Wrong") }))
      assert.equals(1, #res)
      assert.equals("Head", res[1].slot)
      assert.equals("Enchant Helm - Wrong", res[1].applied)
      assert.equals("Enchant Helm - Best", res[1].recommended)
      assert.equals(555, res[1].enchantID)   -- ignore-key component, parsed from the link
    end)

    it("does not flag the recommended enchant (case/space-insensitive match)", function()
      assert.same({}, ns.EnchantMismatches(mage({ Head = ench(10, 555, "enchant helm -  Best") })))
    end)

    it("does not flag when the applied name keeps the 'Enchant <Slot> - ' prefix but the recommendation is the bare name", function()
      -- ClassCodex gives the bare enchant name; the applied name (read from the item's
      -- "Enchanted:" tooltip line) keeps the "Enchant Ring - " prefix. Same enchant → the
      -- prefix must be stripped from both before comparing, else it reads as "wrong".
      _G.ClassCodexGearData.MAGE.frost.enchants = {
        { slot = "Ring", best = { itemId = 601, name = "Eyes of the Eagle" } },
      }
      assert.same({}, ns.EnchantMismatches(mage({
        Finger1 = ench(11, 555, "Enchant Ring - Eyes of the Eagle"),
      })))
    end)

    it("skips a bare slot (no applied enchant) — MissingEnchants' job", function()
      assert.same({}, ns.EnchantMismatches(mage({ Head = ench(10, 0, nil) })))
    end)

    it("skips a slot with no recommendation to compare against", function()
      -- Feet has no CC entry here and no bundled row → can't judge
      assert.same({}, ns.EnchantMismatches(mage({ Feet = ench(10, 555, "Enchant Boots - Whatever") })))
    end)

    it("ignores a non-enchantable slot even if it carries an enchant string", function()
      assert.same({}, ns.EnchantMismatches(mage({ Neck = ench(10, 555, "Enchant Neck - Nope") })))
    end)

    -- Leg enchants are spellthreads: the applied "enchant" is captured as a stat line
    -- ("+41 Intellect & +115 Stamina"), not an "Enchant Legs - X" name, so it's compared
    -- on stat magnitudes against the recommended enchant's tooltip rather than by name.
    describe("stat-line (spellthread) enchants", function()
      before_each(function()
        -- CC recommends a legs spellthread (an item we resolve a tooltip for).
        _G.ClassCodexGearData.MAGE.frost.enchants[#_G.ClassCodexGearData.MAGE.frost.enchants + 1] =
          { slot = "Legs", best = { itemId = 700, name = "Daybreak Spellthread" } }
      end)
      after_each(function() _G.C_TooltipInfo = nil end)

      -- Stub the recommended item's tooltip lines.
      local function tooltip(lines)
        _G.C_TooltipInfo = { GetItemByID = function()
          local out = {}
          for _, t in ipairs(lines) do out[#out + 1] = { leftText = t } end
          return { lines = out }
        end }
      end

      it("does not flag when the recommendation grants the same stats", function()
        tooltip({ "Daybreak Spellthread", "Use: increasing Intellect by 41 and Stamina by 115." })
        assert.same({}, ns.EnchantMismatches(mage({
          Legs = ench(20, 7935, "+41 Intellect & +115 Stamina"),
        })))
      end)

      it("flags when the recommendation grants different stats", function()
        tooltip({ "Daybreak Spellthread", "Use: increasing Intellect by 50 and Stamina by 140." })
        local res = ns.EnchantMismatches(mage({
          Legs = ench(20, 7935, "+41 Intellect & +115 Stamina"),
        }))
        assert.equals(1, #res)
        assert.equals("Legs", res[1].slot)
        assert.equals("+41 Intellect & +115 Stamina", res[1].applied)
      end)

      it("does not flag when the recommendation's tooltip can't be resolved yet", function()
        -- no C_TooltipInfo stub → can't judge → must not re-introduce a false positive
        assert.same({}, ns.EnchantMismatches(mage({
          Legs = ench(20, 7935, "+41 Intellect & +115 Stamina"),
        })))
      end)

      it("does not flag while the recommended scroll's item data is still uncached", function()
        -- An uncached scroll's tooltip carries only its name/quality, not the "Use:" stat
        -- line, so a magnitude compare would wrongly flag a correct spellthread (#236). Gate
        -- on the item being cached: until then it's "can't judge" and a load is requested.
        local requested
        _G.C_Item.IsItemDataCachedByID = function() return false end
        _G.C_Item.RequestLoadItemDataByID = function(id) requested = id end
        tooltip({ "Sunfire Silk Spellthread" })   -- partial: only the name resolved so far
        assert.same({}, ns.EnchantMismatches(mage({
          Legs = ench(20, 7935, "+41 Intellect & +115 Stamina"),
        })))
        assert.equals(700, requested)             -- a load was kicked off for next render
      end)

      it("requires one line to carry all stats (a coincidental single match isn't enough)", function()
        tooltip({ "Item Level 115", "Requires Level 80", "Increases Intellect by 41." })
        local res = ns.EnchantMismatches(mage({
          Legs = ench(20, 7935, "+41 Intellect & +115 Stamina"),
        }))
        assert.equals(1, #res)   -- no single line has both 41 and 115
      end)
    end)
  end)

  describe("MissingGems", function()
    local function char(slots)
      return { name = "Toon", classKey = "Mage", equipment = { slots = slots } }
    end
    local function gearedSlot(empty)
      return { link = link(1, nil), ilvl = 600, emptySockets = empty }
    end

    it("flags slots with one or more empty sockets, in slot order", function()
      local res = ns.MissingGems(char({
        Finger1 = gearedSlot(1),
        Neck    = gearedSlot(2),
        Chest   = gearedSlot(0),   -- socketed / no socket: not flagged
      }))
      assert.equals(2, #res)
      assert.equals("Neck", res[1].slot)      -- GEM_ORDER puts Neck before Finger1
      assert.equals(2, res[1].sockets)
      assert.equals("Finger1", res[2].slot)
    end)

    it("ignores slots with no empty-socket data", function()
      assert.same({}, ns.MissingGems(char({ Chest = { link = link(1, nil) } })))
    end)

    it("returns nothing without scanned equipment", function()
      assert.same({}, ns.MissingGems({ name = "Toon" }))
    end)
  end)

  describe("RecommendedGems", function()
    local function mage()
      return { name = "Frost", classKey = "Mage", basic = { specialization = { id = 64 } } }
    end
    before_each(function()
      _G.ClassCodexGearData = nil
      ns.StatPriority.MAGE[3] = { haste = 1, crit = 2, mastery = 3, versatility = 4 }
    end)

    it("bundled fallback: no diamond, secondary-stat gem for the top stat", function()
      local primary, secondary = ns.RecommendedGems(mage())
      assert.is_nil(primary)                        -- the role-specific diamond isn't bundled
      assert.equals(ns.Gems.byStat.haste, secondary.id)   -- haste is tier 1
      assert.equals("haste", secondary.stat)
    end)

    it("ClassCodex: primary diamond + first secondary gem", function()
      _G.GetSpecializationInfoByID = function(id) return id, "Frost" end
      _G.ClassCodexGearData = { MAGE = { frost = { gems = {
        primary = { itemId = 777, name = "CC Diamond" },
        secondary = { { itemId = 888, name = "CC Fill Gem" } },
      } } } }
      local primary, secondary = ns.RecommendedGems(mage())
      _G.GetSpecializationInfoByID = nil
      assert.equals(777, primary.id)
      assert.equals("CC Diamond", primary.name)
      assert.equals(888, secondary.id)
      assert.equals("CC Fill Gem", secondary.name)
    end)

    it("is nil/nil when the spec is unknown and ClassCodex is absent", function()
      local primary, secondary = ns.RecommendedGems({ name = "NoSpec", classKey = "Mage" })
      assert.is_nil(primary)
      assert.is_nil(secondary)
    end)
  end)

  describe("max-level gating", function()
    -- A still-levelling character gets no enchant/gem surfaces until max level. The
    -- pure-Lua harness leaves ns.wow.maxLevel unset (so the gate is inert in every other
    -- test); set it here to exercise the gate. ClassCodex supplies the picks so the
    -- recommendations carry their own names (no GetSpellName stub needed).
    before_each(function()
      ns.wow.maxLevel = 80
      _G.GetSpecializationInfoByID = function(id) return id, "Frost" end
      _G.ClassCodexGearData = { MAGE = { frost = {
        enchants = { { slot = "Ring", best = { itemId = 500, name = "Enchant Ring - Best" } } },
        gems = { primary = { itemId = 777, name = "CC Diamond" },
                 secondary = { { itemId = 888, name = "CC Fill" } } },
      } } }
    end)
    after_each(function() _G.GetSpecializationInfoByID = nil; _G.ClassCodexGearData = nil end)

    local function mage(level)
      return {
        name = "Frost", classKey = "Mage",
        basic = { level = level, specialization = { id = 64 } },
        equipment = { slots = {
          Finger1 = { link = link(1, nil), ilvl = 600, equipLoc = "INVTYPE_FINGER", emptySockets = 1 },
          Finger2 = { link = link(2, 555), ilvl = 600, equipLoc = "INVTYPE_FINGER",
                      enchant = "Enchant Ring - Wrong" },
        } },
      }
    end

    it("suppresses every enchant/gem surface below max level", function()
      local m = mage(79)
      assert.same({}, ns.MissingEnchants(m))
      assert.is_nil(ns.RecommendedEnchant(m, "Finger1"))
      assert.same({}, ns.EnchantMismatches(m))
      assert.same({}, ns.MissingGems(m))
      local primary, secondary = ns.RecommendedGems(m)
      assert.is_nil(primary)
      assert.is_nil(secondary)
    end)

    it("exposes them again at max level", function()
      local m = mage(80)
      assert.equals(1, #ns.MissingEnchants(m))             -- Finger1 is bare
      assert.equals(500, ns.RecommendedEnchant(m, "Finger1").id)
      assert.equals(1, #ns.EnchantMismatches(m))           -- Finger2's applied enchant is wrong
      assert.equals(1, #ns.MissingGems(m))                 -- Finger1 has an empty socket
      local primary = ns.RecommendedGems(m)
      assert.equals(777, primary.id)
    end)

    it("leaves an unknown character level ungated", function()
      assert.equals(1, #ns.MissingEnchants(mage(nil)))     -- no stored level → not gated
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
