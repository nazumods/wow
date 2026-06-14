local up = require("ShadowsOfUI-Upgrade.spec.upgrade")

-- Enum.ItemClass / subclass numerics (mirror the addon's data + harness Enum).
local ARMOR, WEAPON = 4, 2
local PLATE, CLOTH = 4, 1
local SWORD1H, SWORD2H = 7, 8
local MISC = 0                         -- holdable off-hand subclass (any-class armour)

-- GetItemStats keys the addon reads.
local STR  = "ITEM_MOD_STRENGTH_SHORT"
local AGI  = "ITEM_MOD_AGILITY_SHORT"
local CRIT = "ITEM_MOD_CRIT_RATING_SHORT"
local HASTE = "ITEM_MOD_HASTE_RATING_SHORT"

local ARMS = 71                        -- arms warrior: primary str, crit tier-1, haste tier-2

-- A warrior with the given equipped slots ({ slot = { ilvl, equipLoc?, link? } }).
local function warrior(name, slots)
  return {
    name = name, classKey = "Warrior",
    basic = { specialization = { id = ARMS } },
    equipment = { slots = slots },
  }
end

describe("ShadowsOfUI-Upgrade upgrade calc", function()
  local h
  before_each(function() h = up.harness() end)

  -- Convenience: register an item and return it ready to drop in a gear pool.
  local function plateChest(id, ilvl, stats)
    return h.defItem{ link = "chest:" .. id, itemID = id, equipLoc = "INVTYPE_CHEST",
      classID = ARMOR, subClassID = PLATE, ilvl = ilvl, stats = stats }
  end

  describe("SlotUpgrade — basic ilvl gating", function()
    it("reports a higher-ilvl held item as an upgrade with the right gain and source", function()
      h.addChar(warrior("Conan", { Chest = { ilvl = 580 } }))
      h.pools.Conan = { bags = { plateChest(1, 620) }, bank = {} }

      local r = h.Api:SlotUpgrade("Conan", "Chest")
      assert.is_not_nil(r)
      assert.equals("Chest", r.slot)
      assert.equals(620, r.ilvl)
      assert.equals(40, r.ilvlGain)
      assert.equals("held", r.where)
      assert.is_falsy(r.betterElsewhere)
    end)

    it("does not report an equal or lower ilvl item", function()
      h.addChar(warrior("Conan", { Chest = { ilvl = 620 } }))
      h.pools.Conan = { bags = { plateChest(1, 620), plateChest(2, 600) }, bank = {} }
      assert.is_nil(h.Api:SlotUpgrade("Conan", "Chest"))
    end)

    it("treats an empty equipped slot as always upgradeable", function()
      h.addChar(warrior("Conan", { Chest = { ilvl = 580 } })) -- Head is empty
      h.pools.Conan = { bags = { h.defItem{ link = "head:1", itemID = 9, equipLoc = "INVTYPE_HEAD",
        classID = ARMOR, subClassID = PLATE, ilvl = 100 } }, bank = {} }
      local r = h.Api:SlotUpgrade("Conan", "Head")
      assert.equals(100, r.ilvlGain) -- 100 − 0
    end)

    it("returns nil when the character has no scanned equipment", function()
      local c = warrior("Conan", nil)
      c.equipment = nil
      h.addChar(c)
      h.pools.Conan = { bags = { plateChest(1, 999) }, bank = {} }
      assert.is_nil(h.Api:SlotUpgrade("Conan", "Chest"))
    end)
  end)

  describe("SlotUpgrade — equip / primary gating", function()
    it("rejects gear the class cannot wear (wrong armour type)", function()
      h.addChar(warrior("Conan", { Chest = { ilvl = 500 } }))
      h.pools.Conan = { bags = { h.defItem{ link = "cloth:1", itemID = 5, equipLoc = "INVTYPE_CHEST",
        classID = ARMOR, subClassID = CLOTH, ilvl = 620 } }, bank = {} }
      assert.is_nil(h.Api:SlotUpgrade("Conan", "Chest"))
    end)

    it("rejects gear carrying the wrong primary stat for the spec", function()
      h.addChar(warrior("Conan", { Chest = { ilvl = 500 } }))
      -- An agility plate chest: equippable by armour type, but useless to a str spec.
      h.pools.Conan = { bags = { plateChest(1, 620, { [AGI] = 50 }) }, bank = {} }
      assert.is_nil(h.Api:SlotUpgrade("Conan", "Chest"))
    end)

    it("accepts gear with the matching primary stat", function()
      h.addChar(warrior("Conan", { Chest = { ilvl = 500 } }))
      h.pools.Conan = { bags = { plateChest(1, 620, { [STR] = 50 }) }, bank = {} }
      assert.is_not_nil(h.Api:SlotUpgrade("Conan", "Chest"))
    end)
  end)

  describe("SlotUpgrade — multi-slot items target the weaker slot", function()
    it("compares a ring against the lower of the two finger slots", function()
      h.addChar(warrior("Conan", { Finger1 = { ilvl = 600 }, Finger2 = { ilvl = 580 } }))
      h.pools.Conan = { bags = { h.defItem{ link = "ring:1", itemID = 7, equipLoc = "INVTYPE_FINGER",
        classID = ARMOR, subClassID = MISC, ilvl = 590 } }, bank = {} }
      local r = h.Api:SlotUpgrade("Conan", "Finger2")
      assert.is_not_nil(r)
      assert.equals(10, r.ilvlGain)         -- 590 − 580 (the weaker ring)
      assert.is_nil(h.Api:SlotUpgrade("Conan", "Finger1"))
    end)
  end)

  describe("SlotUpgrade — held vs warband source", function()
    it("flags betterElsewhere when a warband copy out-levels the best held one", function()
      h.addChar(warrior("Conan", { Chest = { ilvl = 580 } }))
      h.pools.Conan = { bags = { plateChest(1, 610) }, bank = {} }
      h.warband = { plateChest(2, 620) }
      local r = h.Api:SlotUpgrade("Conan", "Chest")
      assert.equals("warband", r.where)
      assert.is_true(r.betterElsewhere)
      assert.equals(40, r.ilvlGain)         -- 620 − 580
    end)

    it("prefers the held copy when it is at least as good as the warband one", function()
      h.addChar(warrior("Conan", { Chest = { ilvl = 580 } }))
      h.pools.Conan = { bags = { plateChest(1, 620) }, bank = {} }
      h.warband = { plateChest(2, 620) }
      local r = h.Api:SlotUpgrade("Conan", "Chest")
      assert.equals("held", r.where)
      assert.is_falsy(r.betterElsewhere)
    end)
  end)

  describe("statTag", function()
    it("tags an item with a tier-1 secondary as good", function()
      h.addChar(warrior("Conan", { Chest = { ilvl = 500 } }))
      h.pools.Conan = { bags = { plateChest(1, 620, { [STR] = 10, [CRIT] = 20 }) }, bank = {} }
      assert.equals("good", h.Api:SlotUpgrade("Conan", "Chest").statTag)
    end)

    it("tags an item with only off-tier secondaries as off", function()
      -- Arms warrior: haste is tier-2, not tier-1.
      h.addChar(warrior("Conan", { Chest = { ilvl = 500 } }))
      h.pools.Conan = { bags = { plateChest(1, 620, { [STR] = 10, [HASTE] = 20 }) }, bank = {} }
      assert.equals("off", h.Api:SlotUpgrade("Conan", "Chest").statTag)
    end)

    it("leaves statTag nil when the item has no secondary stats", function()
      h.addChar(warrior("Conan", { Chest = { ilvl = 500 } }))
      h.pools.Conan = { bags = { plateChest(1, 620, { [STR] = 10 }) }, bank = {} }
      assert.is_nil(h.Api:SlotUpgrade("Conan", "Chest").statTag)
    end)
  end)

  describe("CharacterUpgrades / CharacterUpgradeCount", function()
    it("lists every upgraded slot sorted by ilvl gain, descending", function()
      h.addChar(warrior("Conan", { Chest = { ilvl = 580 }, Head = { ilvl = 610 } }))
      h.pools.Conan = { bags = {
        plateChest(1, 620),                                                    -- +40
        h.defItem{ link = "head:1", itemID = 9, equipLoc = "INVTYPE_HEAD",
          classID = ARMOR, subClassID = PLATE, ilvl = 620 },                   -- +10
      }, bank = {} }

      local list = h.Api:CharacterUpgrades("Conan")
      assert.equals(2, #list)
      assert.equals("Chest", list[1].slot)   -- +40 first
      assert.equals("Head", list[2].slot)    -- +10 second
      assert.equals(2, h.Api:CharacterUpgradeCount("Conan"))
    end)

    it("reports no upgrades for a fully-geared character", function()
      h.addChar(warrior("Conan", { Chest = { ilvl = 620 } }))
      h.pools.Conan = { bags = { plateChest(1, 600) }, bank = {} }
      assert.same({}, h.Api:CharacterUpgrades("Conan"))
      assert.equals(0, h.Api:CharacterUpgradeCount("Conan"))
    end)
  end)

  describe("per-character memo (GetTime TTL)", function()
    it("caches a character's result within the TTL and recomputes after it lapses", function()
      h.addChar(warrior("Conan", { Chest = { ilvl = 580 } }))
      h.pools.Conan = { bags = {}, bank = {} }
      assert.is_nil(h.Api:SlotUpgrade("Conan", "Chest"))   -- caches the empty result

      h.pools.Conan = { bags = { plateChest(1, 620) }, bank = {} }
      assert.is_nil(h.Api:SlotUpgrade("Conan", "Chest"))   -- still the cached empty result

      h.advance(3)                                          -- past the 2s TTL
      assert.is_not_nil(h.Api:SlotUpgrade("Conan", "Chest"))
    end)
  end)

  describe("two-hand reconciliation", function()
    local function twoHandWarrior(mhIlvl)
      return warrior("Conan", { MainHand = { ilvl = mhIlvl, equipLoc = "INVTYPE_2HWEAPON" } })
    end
    local function sword2h(id, ilvl)
      return h.defItem{ link = "2h:" .. id, itemID = id, equipLoc = "INVTYPE_2HWEAPON",
        classID = WEAPON, subClassID = SWORD2H, ilvl = ilvl }
    end
    local function sword1h(id, ilvl)
      return h.defItem{ link = "1h:" .. id, itemID = id, equipLoc = "INVTYPE_WEAPON",
        classID = WEAPON, subClassID = SWORD1H, ilvl = ilvl }
    end
    local function holdable(id, ilvl)
      return h.defItem{ link = "off:" .. id, itemID = id, equipLoc = "INVTYPE_HOLDABLE",
        classID = ARMOR, subClassID = MISC, ilvl = ilvl }
    end

    it("reports a better two-hander as a lone MainHand upgrade", function()
      h.addChar(twoHandWarrior(600))
      h.pools.Conan = { bags = { sword2h(1, 620) }, bank = {} }
      local mh = h.Api:SlotUpgrade("Conan", "MainHand")
      assert.is_not_nil(mh)
      assert.equals(20, mh.ilvlGain)
      assert.is_falsy(mh.pairSwap)
      assert.is_nil(h.Api:SlotUpgrade("Conan", "OffHand"))
    end)

    it("never reports a lone off-hand against the nominally-empty off-hand slot", function()
      h.addChar(twoHandWarrior(600))
      h.pools.Conan = { bags = { holdable(1, 999) }, bank = {} }
      assert.is_nil(h.Api:SlotUpgrade("Conan", "OffHand"))
      assert.is_nil(h.Api:SlotUpgrade("Conan", "MainHand"))
    end)

    it("emits a paired MainHand+OffHand swap when a 1H+off beats the 2H budget", function()
      h.addChar(twoHandWarrior(600))                       -- budget 1200
      h.pools.Conan = { bags = { sword1h(1, 610), holdable(2, 610) }, bank = {} } -- 1220
      local mh = h.Api:SlotUpgrade("Conan", "MainHand")
      local off = h.Api:SlotUpgrade("Conan", "OffHand")
      assert.is_not_nil(mh)
      assert.is_not_nil(off)
      assert.is_true(mh.pairSwap)
      assert.is_true(off.pairSwap)
      assert.equals(10, mh.ilvlGain)                       -- (1220−1200)/2
      assert.equals(10, off.ilvlGain)
    end)

    it("prefers a better 2H over a pair when the 2H budget is at least as high", function()
      h.addChar(twoHandWarrior(600))                       -- budget 1200
      h.pools.Conan = { bags = { sword2h(1, 620), sword1h(2, 610), holdable(3, 610) }, bank = {} }
      -- 2H budget 1240 ≥ pair budget 1220 → single 2H result, no pair.
      local mh = h.Api:SlotUpgrade("Conan", "MainHand")
      assert.is_falsy(mh.pairSwap)
      assert.equals(20, mh.ilvlGain)
      assert.is_nil(h.Api:SlotUpgrade("Conan", "OffHand"))
    end)

    it("leaves normal per-slot weapon behaviour for a non-2H wielder", function()
      h.addChar(warrior("Conan", { MainHand = { ilvl = 600, equipLoc = "INVTYPE_WEAPON" } }))
      h.pools.Conan = { bags = { sword1h(1, 620) }, bank = {} }
      local mh = h.Api:SlotUpgrade("Conan", "MainHand")
      assert.is_not_nil(mh)
      assert.equals(20, mh.ilvlGain)
      assert.is_falsy(mh.pairSwap)
    end)
  end)

  describe("ItemUpgrades (tooltip path)", function()
    local function chestItem(id, ilvl, stats)
      return h.defItem{ link = "chest:" .. id, itemID = id, equipLoc = "INVTYPE_CHEST",
        classID = ARMOR, subClassID = PLATE, ilvl = ilvl, stats = stats }
    end

    it("returns nil for a non-equippable link", function()
      h.addChar(warrior("Conan", { Chest = { ilvl = 500 } }))
      local junk = h.defItem{ link = "junk", itemID = 99, equipLoc = "", classID = 0, subClassID = 0, ilvl = 0 }
      assert.is_nil(h.Api:ItemUpgrades(junk.link))
    end)

    it("lists every character the item upgrades, sorted by gain", function()
      h.addChar(warrior("Conan", { Chest = { ilvl = 580 } }))    -- +40
      h.addChar(warrior("Kull", { Chest = { ilvl = 600 } }))     -- +20
      h.addChar(warrior("Brule", { Chest = { ilvl = 620 } }))    -- no upgrade
      local item = chestItem(1, 620)
      local out = h.Api:ItemUpgrades(item.link)
      assert.equals(2, #out)
      assert.equals("Conan", out[1].name)   -- +40 first
      assert.equals("Kull", out[2].name)
    end)

    it("restricts a soulbound item to its holder via boundTo", function()
      h.addChar(warrior("Conan", { Chest = { ilvl = 580 } }))
      h.addChar(warrior("Kull", { Chest = { ilvl = 580 } }))
      local item = chestItem(1, 620)
      local out = h.Api:ItemUpgrades(item.link, "Kull")
      assert.equals(1, #out)
      assert.equals("Kull", out[1].name)
    end)

    it("does not list a lone off-hand as an upgrade for a 2H wielder", function()
      h.addChar(warrior("Conan", { MainHand = { ilvl = 600, equipLoc = "INVTYPE_2HWEAPON" } }))
      local off = h.defItem{ link = "off:1", itemID = 30, equipLoc = "INVTYPE_HOLDABLE",
        classID = ARMOR, subClassID = MISC, ilvl = 999 }
      assert.is_nil(h.Api:ItemUpgrades(off.link))
    end)
  end)
end)
