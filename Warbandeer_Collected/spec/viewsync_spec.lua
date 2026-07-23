local collected = require("Warbandeer_Collected.spec.collected")

-- The real Enum.TransmogCollectionType values, so a wrong constant in viewsync.lua surfaces here
-- rather than passing against a stub that agrees with the mistake.
local CATEGORY = {
  Head = 1, Shoulder = 2, Back = 3, Chest = 4, Shirt = 5, Tabard = 6,
  Wrist = 7, Hands = 8, Waist = 9, Legs = 10, Feet = 11,
  Wand = 12, OneHAxe = 13, OneHSword = 14, OneHMace = 15, Dagger = 16, Fist = 17,
  Shield = 18, Holdable = 19, TwoHAxe = 20, TwoHSword = 21, TwoHMace = 22,
  Staff = 23, Polearm = 24, Bow = 25, Gun = 26, Crossbow = 27, Warglaives = 28, Paired = 29,
}

describe("view sync", function()
  local ns

  before_each(function()
    _G.Enum = { TransmogCollectionType = CATEGORY }
    ns = collected.loadViewSync(collected.load())
  end)

  describe("PreviewToRestore", function()
    local ARMOR = { group = "armor group", set = "armor set" }
    local WEAPON = { group = "weapon group", set = "weapon set" }
    local memory = { armor = ARMOR, weapons = WEAPON }

    it("restores the target view's preview when switching away from the other one", function()
      assert.equal(WEAPON, ns.PreviewToRestore("armor", "weapons", memory))
      assert.equal(ARMOR, ns.PreviewToRestore("weapons", "armor", memory))
    end)

    -- Re-selecting the view already on screen must not re-Dress the model.
    it("leaves the room alone when it already shows that view's preview", function()
      assert.is_nil(ns.PreviewToRestore("armor", "armor", memory))
      assert.is_nil(ns.PreviewToRestore("weapons", "weapons", memory))
    end)

    it("leaves the room alone when the target view has no previous preview", function()
      assert.is_nil(ns.PreviewToRestore("armor", "weapons", { armor = ARMOR }))
      assert.is_nil(ns.PreviewToRestore("weapons", "armor", { weapons = WEAPON }))
      assert.is_nil(ns.PreviewToRestore("armor", "weapons", {}))
      assert.is_nil(ns.PreviewToRestore("armor", "weapons", nil))
    end)

    -- Outfit mode: a loaded library look belongs to neither grid (both cursors clear when one
    -- loads), so toggling a grid must not swap it out from under the user.
    it("never disturbs a loaded look", function()
      assert.is_nil(ns.PreviewToRestore(nil, "armor", memory))
      assert.is_nil(ns.PreviewToRestore(nil, "weapons", memory))
    end)
  end)

  describe("WeaponHands", function()
    local function hands(category)
      local main, off = ns.WeaponHands(category)
      return (main and "M" or "") .. (off and "O" or "")
    end

    it("offers both hands for every dual-wield one-hander", function()
      for _, name in ipairs({"OneHAxe", "OneHSword", "OneHMace", "Dagger", "Fist", "Warglaives"}) do
        assert.equal("MO", hands(CATEGORY[name]), name .. " should be stageable in either hand")
      end
    end)

    it("offers the main hand only for the two-handers nothing pairs with", function()
      for _, name in ipairs({"Polearm", "Staff", "Bow", "Gun", "Crossbow"}) do
        assert.equal("M", hands(CATEGORY[name]), name .. " leaves no room for an off hand")
      end
    end)

    -- Titan's Grip (Fury Warrior) dual-wields two-handed axes, maces and swords, so those three
    -- are off-hand eligible in spite of being two-handed (#661). No class is consulted — see the
    -- set's note in viewsync.lua.
    it("offers both hands for the Titan's Grip two-handers", function()
      for _, name in ipairs({"TwoHAxe", "TwoHSword", "TwoHMace"}) do
        assert.equal("MO", hands(CATEGORY[name]), name .. " pairs under Titan's Grip")
      end
    end)

    -- A wand is one-handed but main-hand-only since Legion — the case neither the two-handed nor
    -- the one-handed set covers on its own.
    it("offers the main hand only for a wand", function()
      assert.equal("M", hands(CATEGORY.Wand))
    end)

    it("offers the off hand only for shields and holdables", function()
      assert.equal("O", hands(CATEGORY.Shield))
      assert.equal("O", hands(CATEGORY.Holdable))
    end)

    it("offers nothing for a category that isn't a stageable weapon", function()
      assert.equal("", hands(CATEGORY.Head))
      assert.equal("", hands(CATEGORY.Paired))
      assert.equal("", hands(9999))
      assert.equal("", hands(nil))
    end)
  end)

  describe("SuppressesOffHand", function()
    it("agrees with WeaponHands — a suppressing main-hand offers no off hand", function()
      for _, category in pairs(CATEGORY) do
        if ns.SuppressesOffHand(category) then
          local main, off = ns.WeaponHands(category)
          assert.is_true(main, "a suppressing weapon must be main-hand eligible")
          assert.is_false(off, "a suppressing weapon must not be off-hand eligible")
        end
      end
    end)

    it("names the two-handers nothing pairs with", function()
      for _, name in ipairs({"Polearm", "Staff", "Bow", "Gun", "Crossbow"}) do
        assert.is_true(ns.SuppressesOffHand(CATEGORY[name]), name .. " leaves no room for an off hand")
      end
    end)

    -- The whole of #661: these three are two-handed AND dual-wieldable, so a main-hand pick has to
    -- leave the off-hand slot live instead of greying it out.
    it("is false for the Titan's Grip two-handers", function()
      for _, name in ipairs({"TwoHAxe", "TwoHSword", "TwoHMace"}) do
        assert.is_false(ns.SuppressesOffHand(CATEGORY[name]), name .. " pairs under Titan's Grip")
      end
    end)

    it("is false for one-handers, wands, shields and non-weapons", function()
      assert.is_false(ns.SuppressesOffHand(CATEGORY.OneHSword))
      assert.is_false(ns.SuppressesOffHand(CATEGORY.Wand))
      assert.is_false(ns.SuppressesOffHand(CATEGORY.Shield))
      assert.is_false(ns.SuppressesOffHand(CATEGORY.Chest))
      assert.is_false(ns.SuppressesOffHand(nil))
    end)
  end)

  describe("TitansGripWeapon", function()
    it("names exactly the three two-handers a Fury Warrior dual-wields", function()
      assert.is_true(ns.TitansGripWeapon(CATEGORY.TwoHAxe))
      assert.is_true(ns.TitansGripWeapon(CATEGORY.TwoHSword))
      assert.is_true(ns.TitansGripWeapon(CATEGORY.TwoHMace))
      -- Polearms and staves are two-handed but NOT Titan's Grip weapons; that split is the
      -- distinction the whole rule turns on, and it is the one thing worth re-checking if
      -- Blizzard ever widens the talent.
      assert.is_false(ns.TitansGripWeapon(CATEGORY.Polearm))
      assert.is_false(ns.TitansGripWeapon(CATEGORY.Staff))
      assert.is_false(ns.TitansGripWeapon(CATEGORY.Bow))
      assert.is_false(ns.TitansGripWeapon(CATEGORY.OneHSword))
      assert.is_false(ns.TitansGripWeapon(nil))
    end)

    it("offers both hands for every one it names", function()
      for _, category in pairs(CATEGORY) do
        if ns.TitansGripWeapon(category) then
          local main, off = ns.WeaponHands(category)
          assert.is_true(main and off, "a Titan's Grip weapon goes in either hand")
        end
      end
    end)

    -- The two predicates partition the two-handers: a category either pairs or it suppresses,
    -- never both. A category added to one set and forgotten in the other trips this.
    it("never overlaps SuppressesOffHand", function()
      for _, category in pairs(CATEGORY) do
        assert.is_false(ns.TitansGripWeapon(category) and ns.SuppressesOffHand(category))
      end
    end)
  end)

  describe("OffHandOnlyWeapon", function()
    it("names exactly the off-hand slot categories", function()
      assert.is_true(ns.OffHandOnlyWeapon(CATEGORY.Shield))
      assert.is_true(ns.OffHandOnlyWeapon(CATEGORY.Holdable))
      -- The pair the capability flags cannot tell apart: a shield and a two-hander report
      -- identical isWeapon/canMainHand/canOffHand, which is why this is an explicit set.
      assert.is_false(ns.OffHandOnlyWeapon(CATEGORY.TwoHSword))
      assert.is_false(ns.OffHandOnlyWeapon(CATEGORY.OneHSword))
      assert.is_false(ns.OffHandOnlyWeapon(nil))
    end)
  end)
end)
