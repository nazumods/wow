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

  -- Browsing a weapon cell stages it onto the ONE paper doll straight away (#673), so the default
  -- hand is what the model actually puts on the moment a cell is clicked — not just what a button
  -- would offer.
  describe("DefaultWeaponHand", function()
    it("sends everything the main hand can hold to the main hand", function()
      for _, name in ipairs({"OneHAxe", "OneHSword", "OneHMace", "Dagger", "Fist", "Warglaives",
                             "TwoHAxe", "TwoHSword", "TwoHMace", "Polearm", "Staff",
                             "Bow", "Gun", "Crossbow", "Wand"}) do
        assert.equal("main", ns.DefaultWeaponHand(CATEGORY[name]), name .. " should browse into the main hand")
      end
    end)

    -- The two types with no main hand to fall back on — the whole reason this isn't just "main".
    it("sends the off-hand-only types to the off hand", function()
      assert.equal("off", ns.DefaultWeaponHand(CATEGORY.Shield))
      assert.equal("off", ns.DefaultWeaponHand(CATEGORY.Holdable))
    end)

    it("stages nothing for a category that isn't a weapon", function()
      assert.is_nil(ns.DefaultWeaponHand(CATEGORY.Chest))
      assert.is_nil(ns.DefaultWeaponHand(CATEGORY.Paired))
      assert.is_nil(ns.DefaultWeaponHand(nil))
    end)
  end)

  describe("StageCellWeapon", function()
    local EMPTY = {}

    it("browses into the type's default hand", function()
      local out = ns.StageCellWeapon(CATEGORY.OneHSword, nil, 111, EMPTY)
      assert.same({ mainHand = 111, offHand = nil, noOffHand = nil, hand = "main" }, out)

      out = ns.StageCellWeapon(CATEGORY.Shield, nil, 222, EMPTY)
      assert.same({ mainHand = nil, offHand = 222, noOffHand = nil, hand = "off" }, out)
    end)

    -- ↑/↓ through a cell's colour variants: the same hand, the new appearance, nothing accumulated.
    it("replaces in place when stepping to another look in the same hand", function()
      local out = ns.StageCellWeapon(CATEGORY.OneHSword, "main", 222,
        { mainHand = 111, hand = "main" })
      assert.same({ mainHand = 222, offHand = nil, noOffHand = nil, hand = "main" }, out)
    end)

    -- Browsing a sword and then a shield builds a PAIR: a new cell carries no `hand`, so neither
    -- disturbs the other. This is the flow the second bare doll made impossible.
    it("leaves the other hand alone when a different cell is browsed", function()
      local out = ns.StageCellWeapon(CATEGORY.Shield, nil, 222, { mainHand = 111 })
      assert.same({ mainHand = 111, offHand = 222, noOffHand = nil, hand = "off" }, out)
    end)

    -- The chooser's hand buttons are a selector, not a second copy: moving vacates the hand left.
    it("vacates the hand it is moving out of", function()
      local out = ns.StageCellWeapon(CATEGORY.OneHSword, "off", 111,
        { mainHand = 111, hand = "main" })
      assert.same({ mainHand = nil, offHand = 111, noOffHand = nil, hand = "off" }, out)

      out = ns.StageCellWeapon(CATEGORY.OneHSword, "main", 111, { offHand = 111, hand = "off" })
      assert.same({ mainHand = 111, offHand = nil, noOffHand = nil, hand = "main" }, out)
    end)

    -- `noOffHand` is the main-hand pick's business alone, so it follows a main-hand stage and is
    -- dropped when the main hand is vacated — never touched by an off-hand one.
    it("derives the off-hand suppression from the main-hand pick", function()
      local out = ns.StageCellWeapon(CATEGORY.Staff, nil, 111, EMPTY)
      assert.is_true(out.noOffHand)

      -- A Titan's Grip two-hander is equally two-handed but pairs, so it must NOT suppress (#661).
      out = ns.StageCellWeapon(CATEGORY.TwoHAxe, nil, 111, EMPTY)
      assert.is_nil(out.noOffHand)

      -- Vacating the main hand drops the suppression with it: no main-hand pick, nothing to
      -- suppress. (A staff can't be the one moving — it's main-only, so asking for the off hand
      -- keeps it in the main; that fallback is asserted below.)
      out = ns.StageCellWeapon(CATEGORY.OneHSword, "off", 111,
        { mainHand = 111, noOffHand = true, hand = "main" })
      assert.is_nil(out.noOffHand)

      -- An off-hand stage never rewrites what the main hand decided.
      out = ns.StageCellWeapon(CATEGORY.Shield, nil, 222, { mainHand = 111, noOffHand = true })
      assert.is_true(out.noOffHand)
    end)

    -- The chooser greys the ineligible button, but the rule can't depend on that having been
    -- honoured: a shield asked into the main hand still lands where a shield can go.
    it("falls back to the default hand when the one asked for is ineligible", function()
      local out = ns.StageCellWeapon(CATEGORY.Shield, "main", 222, EMPTY)
      assert.same({ mainHand = nil, offHand = 222, noOffHand = nil, hand = "off" }, out)

      out = ns.StageCellWeapon(CATEGORY.Staff, "off", 111, EMPTY)
      assert.same({ mainHand = 111, offHand = nil, noOffHand = true, hand = "main" }, out)
    end)

    it("stages nothing, and disturbs nothing, for a non-weapon category", function()
      local out = ns.StageCellWeapon(CATEGORY.Chest, nil, 333, { mainHand = 111, offHand = 222 })
      assert.same({ mainHand = 111, offHand = 222, noOffHand = nil, hand = nil }, out)
    end)
  end)

  -- `WeaponHands` is the SOLE hand-eligibility answer since #661 (the picker's `canOffHand` test
  -- turned out not to be a dual-wield test at all), so the dropdown split the picker builds from
  -- it is asserted here in the same shape the picker consumes it.
  describe("the picker's dropdown split", function()
    ---@return string[]
    local function offered(hand)
      local out = {}
      for name, category in pairs(CATEGORY) do
        local main, off = ns.WeaponHands(category)
        if (hand == "off" and off) or (hand == "main" and main) then out[#out + 1] = name end
      end
      table.sort(out)
      return out
    end

    -- The off hand takes a second one-hander, a shield or frill, or a Titan's Grip two-hander —
    -- and nothing else. The one-handers are the regression that mattered: they were absent
    -- entirely while this was built on `canOffHand`.
    it("offers the off hand exactly the pairable types", function()
      assert.same({ "Dagger", "Fist", "Holdable", "OneHAxe", "OneHMace", "OneHSword",
                    "Shield", "TwoHAxe", "TwoHMace", "TwoHSword", "Warglaives" }, offered("off"))
    end)

    it("offers the main hand everything but the off-hand-only pair", function()
      assert.same({ "Bow", "Crossbow", "Dagger", "Fist", "Gun", "OneHAxe", "OneHMace", "OneHSword",
                    "Polearm", "Staff", "TwoHAxe", "TwoHMace", "TwoHSword", "Wand", "Warglaives" },
        offered("main"))
    end)

    -- A type the off hand offers must never also be one that greys the off-hand slot, or the
    -- picker would offer a pick its own suppression rule then throws away.
    it("never offers the off hand a type that suppresses it", function()
      for _, category in pairs(CATEGORY) do
        local _, off = ns.WeaponHands(category)
        assert.is_false(off and ns.SuppressesOffHand(category))
      end
    end)
  end)
end)
