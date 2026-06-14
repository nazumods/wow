local up = require("ShadowsOfUI-Upgrade.spec.upgrade")

-- Enum.ItemWeaponSubclass IDs (mirror data/classgear.lua).
local AXE1H, AXE2H = 0, 1
local MACE1H = 4
local SWORD1H, SWORD2H = 7, 8
local STAFF, DAGGER = 10, 15
local WAND = 19
local ARMOR, WEAPON = 4, 2          -- Enum.ItemClass
local CLOTH, LEATHER, MAIL, PLATE = 1, 2, 3, 4   -- Enum.ItemArmorSubclass

describe("ShadowsOfUI-Upgrade equip", function()
  local ns
  before_each(function() ns = up.harness().ns end)

  describe("CompetingSlots", function()
    it("maps body armour to its single slot", function()
      assert.same({ "Head" }, ns.CompetingSlots("INVTYPE_HEAD"))
      assert.same({ "Chest" }, ns.CompetingSlots("INVTYPE_CHEST"))
      assert.same({ "Chest" }, ns.CompetingSlots("INVTYPE_ROBE"))
    end)

    it("maps rings and trinkets to both their slots", function()
      assert.same({ "Finger1", "Finger2" }, ns.CompetingSlots("INVTYPE_FINGER"))
      assert.same({ "Trinket1", "Trinket2" }, ns.CompetingSlots("INVTYPE_TRINKET"))
    end)

    it("maps every main-hand-ish weapon to MainHand and off-hands to OffHand", function()
      for _, loc in ipairs({ "INVTYPE_WEAPON", "INVTYPE_2HWEAPON",
        "INVTYPE_WEAPONMAINHAND", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT" }) do
        assert.same({ "MainHand" }, ns.CompetingSlots(loc), loc)
      end
      for _, loc in ipairs({ "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE" }) do
        assert.same({ "OffHand" }, ns.CompetingSlots(loc), loc)
      end
    end)

    it("returns nil for a non-equipment invtype", function()
      assert.is_nil(ns.CompetingSlots("INVTYPE_BAG"))
      assert.is_nil(ns.CompetingSlots(""))
    end)
  end)

  describe("IsTwoHand", function()
    it("is true for two-handers and 2H ranged only", function()
      assert.is_true(ns.IsTwoHand("INVTYPE_2HWEAPON"))
      assert.is_true(ns.IsTwoHand("INVTYPE_RANGED"))
      assert.is_true(ns.IsTwoHand("INVTYPE_RANGEDRIGHT"))
    end)

    it("is false for one-handers, off-hands, armour and nil", function()
      assert.is_false(ns.IsTwoHand("INVTYPE_WEAPON"))
      assert.is_false(ns.IsTwoHand("INVTYPE_WEAPONOFFHAND"))
      assert.is_false(ns.IsTwoHand("INVTYPE_SHIELD"))
      assert.is_false(ns.IsTwoHand("INVTYPE_HEAD"))
      assert.is_false(ns.IsTwoHand(nil))
    end)
  end)

  describe("WeaponRole", function()
    it("classifies main-hand 1H, 2H and off-hand", function()
      assert.equals("mh1h", ns.WeaponRole("INVTYPE_WEAPON"))
      assert.equals("mh1h", ns.WeaponRole("INVTYPE_WEAPONMAINHAND"))
      assert.equals("mh2h", ns.WeaponRole("INVTYPE_2HWEAPON"))
      assert.equals("mh2h", ns.WeaponRole("INVTYPE_RANGED"))
      assert.equals("off", ns.WeaponRole("INVTYPE_WEAPONOFFHAND"))
      assert.equals("off", ns.WeaponRole("INVTYPE_SHIELD"))
      assert.equals("off", ns.WeaponRole("INVTYPE_HOLDABLE"))
    end)

    it("is nil for armour and rings", function()
      assert.is_nil(ns.WeaponRole("INVTYPE_HEAD"))
      assert.is_nil(ns.WeaponRole("INVTYPE_FINGER"))
    end)
  end)

  describe("CanEquip — body armour type gating", function()
    it("allows the class's own armour type and rejects the rest", function()
      assert.is_true(ns.CanEquip("Warrior", "INVTYPE_CHEST", ARMOR, PLATE))
      assert.is_false(ns.CanEquip("Warrior", "INVTYPE_CHEST", ARMOR, MAIL))
      assert.is_true(ns.CanEquip("Rogue", "INVTYPE_HEAD", ARMOR, LEATHER))
      assert.is_false(ns.CanEquip("Rogue", "INVTYPE_HEAD", ARMOR, PLATE))
      assert.is_true(ns.CanEquip("Mage", "INVTYPE_HAND", ARMOR, CLOTH))
      assert.is_false(ns.CanEquip("Mage", "INVTYPE_HAND", ARMOR, LEATHER))
    end)
  end)

  describe("CanEquip — non-body armour is all-class", function()
    it("lets any class wear cloaks, rings, necks, trinkets regardless of subclass", function()
      -- subClassID irrelevant for these — pass a mismatching one to prove it's ignored.
      assert.is_true(ns.CanEquip("Warrior", "INVTYPE_CLOAK", ARMOR, CLOTH))
      assert.is_true(ns.CanEquip("Mage", "INVTYPE_FINGER", ARMOR, PLATE))
      assert.is_true(ns.CanEquip("Rogue", "INVTYPE_NECK", ARMOR, MAIL))
      assert.is_true(ns.CanEquip("Priest", "INVTYPE_HOLDABLE", ARMOR, LEATHER))
    end)
  end)

  describe("CanEquip — shields", function()
    it("only shield-capable classes can equip a shield", function()
      assert.is_true(ns.CanEquip("Warrior", "INVTYPE_SHIELD", ARMOR, 6))
      assert.is_true(ns.CanEquip("Paladin", "INVTYPE_SHIELD", ARMOR, 6))
      assert.is_true(ns.CanEquip("Shaman", "INVTYPE_SHIELD", ARMOR, 6))
      assert.is_false(ns.CanEquip("Mage", "INVTYPE_SHIELD", ARMOR, 6))
      assert.is_false(ns.CanEquip("Rogue", "INVTYPE_SHIELD", ARMOR, 6))
    end)
  end)

  describe("CanEquip — weapon proficiency", function()
    it("gates on the class's allowed weapon subclasses", function()
      -- Mage: staff/1H-sword/dagger/wand only.
      assert.is_true(ns.CanEquip("Mage", "INVTYPE_WEAPON", WEAPON, DAGGER))
      assert.is_true(ns.CanEquip("Mage", "INVTYPE_WEAPON", WEAPON, WAND))
      assert.is_false(ns.CanEquip("Mage", "INVTYPE_2HWEAPON", WEAPON, AXE2H))
      -- Warrior: broad melee, no daggers? (data allows DAGGER) — but no wands/staves-as-int.
      assert.is_true(ns.CanEquip("Warrior", "INVTYPE_2HWEAPON", WEAPON, SWORD2H))
      assert.is_true(ns.CanEquip("Warrior", "INVTYPE_WEAPON", WEAPON, AXE1H))
      assert.is_false(ns.CanEquip("Warrior", "INVTYPE_WEAPON", WEAPON, WAND))
      -- Rogue: 1H axe yes, 2H axe no, mace1h yes.
      assert.is_true(ns.CanEquip("Rogue", "INVTYPE_WEAPON", WEAPON, AXE1H))
      assert.is_false(ns.CanEquip("Rogue", "INVTYPE_2HWEAPON", WEAPON, AXE2H))
      assert.is_true(ns.CanEquip("Rogue", "INVTYPE_WEAPON", WEAPON, MACE1H))
    end)

    it("rejects a weapon subclass an unknown class can't be looked up for", function()
      assert.is_false(ns.CanEquip("NotAClass", "INVTYPE_WEAPON", WEAPON, SWORD1H))
    end)
  end)

  describe("CanEquip — unknown item class", function()
    it("is false for anything that isn't Armor or Weapon", function()
      assert.is_false(ns.CanEquip("Warrior", "INVTYPE_HEAD", 0, 0))
      assert.is_false(ns.CanEquip("Mage", "INVTYPE_WEAPON", 15, STAFF))
    end)
  end)
end)
