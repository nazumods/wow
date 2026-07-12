-- Unit tests for ShadowsOfUI-Collectibles/core.lua: the v1→v2 palette migration
-- (rollback-safe, non-destructive) and the revamped preset palette. core.lua is
-- pure data/table logic once the LibNAddOn surface it touches at file scope is
-- stubbed. Path is relative to the AddOns root, where busted runs.

local UNCOLLECTED_GREEN = { 0, 1, 0 }
local SOFT_BLUE = { 0.25, 0.45, 1.00 }

local function loadCore()
  _G.SlashCmdList = {}
  _G.LibNAddOn = function(_, ns) return ns end
  local ns = {
    _TITLE = "Collectible Tints",
    RegisterSettings = function() end,
    RegisterChangelog = function() end,
  }
  assert(loadfile("ShadowsOfUI-Collectibles/core.lua"))("ShadowsOfUI-Collectibles", ns)
  return ns
end

describe("ShadowsOfUI-Collectibles core — palette + v1→v2 migration", function()
  local ns
  before_each(function() ns = loadCore() end)

  describe("MigrateDB", function()
    it("gives a fresh install the soft-blue default at v2", function()
      ns.db = {}
      ns:MigrateDB()
      assert.same(SOFT_BLUE, { ns.db.r, ns.db.g, ns.db.b })
      assert.equals(1, ns.db.knownColor)
      assert.equals(2, ns.db.version)
      -- toggle defaults come along
      assert.is_false(ns.db.monochrome)
      assert.is_true(ns.db.markUncollected)
      assert.is_true(ns.db.merchant)
      assert.is_true(ns.db.auctionHouse)
    end)

    it("moves a v1 user still on the pure-red default to soft blue", function()
      ns.db = { version = 1, knownColor = 1, r = 1, g = 0, b = 0,
        monochrome = false, markUncollected = true, merchant = true, auctionHouse = true }
      ns:MigrateDB()
      assert.same(SOFT_BLUE, { ns.db.r, ns.db.g, ns.db.b })
      assert.equals(2, ns.db.version)
    end)

    it("preserves a v1 user's explicitly chosen preset colour", function()
      ns.db = { version = 1, knownColor = 4, r = 1, g = 1, b = 0,
        monochrome = false, markUncollected = true, merchant = true, auctionHouse = true }
      ns:MigrateDB()
      assert.same({ 1, 1, 0 }, { ns.db.r, ns.db.g, ns.db.b }) -- untouched
      assert.equals(2, ns.db.version)
    end)

    it("preserves a v1 user's custom colour", function()
      ns.db = { version = 1, knownColor = 1, r = 0.1, g = 0.2, b = 0.3,
        monochrome = true, markUncollected = false, merchant = true, auctionHouse = true }
      ns:MigrateDB()
      assert.same({ 0.1, 0.2, 0.3 }, { ns.db.r, ns.db.g, ns.db.b })
      assert.equals(2, ns.db.version)
    end)

    it("is idempotent (a second run changes nothing)", function()
      ns.db = { version = 1, knownColor = 1, r = 1, g = 0, b = 0 }
      ns:MigrateDB()
      local snapshot = { ns.db.r, ns.db.g, ns.db.b, ns.db.knownColor, ns.db.version }
      ns:MigrateDB()
      assert.same(snapshot, { ns.db.r, ns.db.g, ns.db.b, ns.db.knownColor, ns.db.version })
    end)
  end)

  describe("palette", function()
    -- settingChanged("knownColor") writes PRESETS[knownColor] into r/g/b, so each
    -- preset's colour is observable through it without exposing the local table.
    local function presetRGB(index)
      ns.db = { knownColor = index }
      ns:settingChanged("knownColor")
      return { ns.db.r, ns.db.g, ns.db.b }
    end

    it("maps the default index (1) to soft blue", function()
      assert.same(SOFT_BLUE, presetRGB(1))
    end)

    it("has no preset equal to the collectible-green tint", function()
      for i = 1, 7 do
        assert.are_not.same(UNCOLLECTED_GREEN, presetRGB(i))
      end
    end)
  end)
end)
