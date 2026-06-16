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
