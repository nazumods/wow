local collect = require("ShadowsOfUI-Collectibles.spec.collect")

describe("ShadowsOfUI-Collectibles detect — tooltip-load negative-cache gating", function()
  local ns, state
  local LINK = "item:5000"
  local ID = 5000

  before_each(function()
    ns, state = collect.load()
    -- A learn item Blizzard tags Consumable (not Recipe class): only the tooltip
    -- "Teaches you" / "already known" scan can classify it — the M1/L1 path.
    state.itemInfo[ID] = { name = "Tome of Foo", classID = Enum.ItemClass.Consumable }
  end)

  describe("IsCollectible (M1 — permanent negative must not lock on an unloaded tooltip)", function()
    it("does not cache false while the tooltip has not loaded", function()
      state.tooltip[LINK] = nil                       -- GetHyperlink returns nil
      assert.is_false(ns.IsCollectible(LINK))
      -- taught-spell line resolves later:
      state.tooltip[LINK] = { "Tome of Foo", "Teaches you: Foo." }
      assert.is_true(ns.IsCollectible(LINK))          -- recovers — was not locked false
    end)

    it("caches the positive once the Teaches-you line is present", function()
      state.tooltip[LINK] = { "Tome of Foo", "Teaches you: Foo." }
      assert.is_true(ns.IsCollectible(LINK))
      state.tooltip[LINK] = nil                        -- tooltip gone
      assert.is_true(ns.IsCollectible(LINK))           -- served from cache
    end)

    it("caches the negative for a genuinely non-collectible loaded item", function()
      state.tooltip[LINK] = { "Just a potion.", "Use: heal." }   -- loaded, no teach line
      assert.is_false(ns.IsCollectible(LINK))
      -- even if the tooltip later gains a teach line, the reliable negative stands
      -- (a real item's type never changes; this proves the perf cache still works)
      state.tooltip[LINK] = { "Teaches you: Foo." }
      assert.is_false(ns.IsCollectible(LINK))
    end)

    it("treats a battlepet link as collectible without a tooltip", function()
      assert.is_true(ns.IsCollectible("battlepet:1234"))
    end)
  end)

  describe("IsKnown (L1 — negative must not read stale on an unloaded tooltip)", function()
    it("does not cache false while the tooltip has not loaded", function()
      state.tooltip[LINK] = nil
      assert.is_false(ns.IsKnown(LINK))
      state.tooltip[LINK] = { "Tome of Foo", "Already known." }
      assert.is_true(ns.IsKnown(LINK))                 -- recovers on load
    end)

    it("caches the negative once a full tooltip lacks the known line", function()
      state.tooltip[LINK] = { "Tome of Foo", "Use: learn Foo." }
      assert.is_false(ns.IsKnown(LINK))
      state.tooltip[LINK] = { "Already known." }       -- would flip live...
      assert.is_false(ns.IsKnown(LINK))                -- ...but cached negative holds
    end)
  end)

  describe("IsKnown (L3 — QuestItems / SpecialItems positives are cached)", function()
    it("caches a QuestItems positive (monotonic)", function()
      ns.QuestItems[ID] = 777
      state.questDone[777] = true
      assert.is_true(ns.IsKnown(LINK))
      state.questDone[777] = false                     -- state flips underneath
      assert.is_true(ns.IsKnown(LINK))                 -- cached positive survives
    end)

    it("does not cache a QuestItems negative (flips on turn-in)", function()
      ns.QuestItems[ID] = 777
      state.questDone[777] = false
      assert.is_false(ns.IsKnown(LINK))
      state.questDone[777] = true
      assert.is_true(ns.IsKnown(LINK))                 -- re-evaluated live, now known
    end)

    it("caches a SpecialItems positive (monotonic)", function()
      -- SpecialItems[id] = { srcItemID, fieldIndex, expectedValue }; the source
      -- item's link field #fieldIndex is compared to expectedValue.
      ns.SpecialItems[ID] = { 6000, 2, 42 }
      state.itemInfo[6000] = { name = "Src", srcLink = "item:42:0:0" }
      assert.is_true(ns.IsKnown(LINK))
      state.itemInfo[6000].srcLink = "item:99:0:0"     -- source changes underneath
      assert.is_true(ns.IsKnown(LINK))                 -- cached positive survives
    end)
  end)

  describe("IsKnown (L2 — recipe cross-alt negative must not lock before the item name loads)", function()
    before_each(function()
      -- A crafting recipe whose crafted item an alt already knows. subClassID 1 maps to
      -- skill line 165 in detect.lua's RECIPE_SUBCLASS_TO_SKILL; craftedName() strips the
      -- "Recipe:" prefix, so the stored learned name is the bare "Foo".
      ns.api = {
        GetAllCharacters = function()
          return {
            { professions = { details = { [165] = { recipes = {
              main = { learned = { { name = "Foo" } } },
            } } } } },
          }
        end,
      }
    end)

    it("does not cache false while the item name is unloaded, then recovers to alt-known", function()
      -- Name unloaded (GetItemInfo → nil) but the tooltip HAS loaded with no "already
      -- known" line for THIS char: the cross-alt check can't run, so a false is a lie.
      state.itemInfo[ID] = { classID = Enum.ItemClass.Recipe, subClassID = 1 }  -- name = nil
      state.tooltip[LINK] = { "Recipe: Foo" }
      assert.is_false(ns.IsKnown(LINK))                -- unknown *for now* (name missing)
      state.itemInfo[ID].name = "Recipe: Foo"          -- name resolves
      assert.is_true(ns.IsKnown(LINK))                 -- recovers — was NOT locked false
    end)

    it("still caches the negative once the name is loaded and no alt knows it", function()
      state.itemInfo[ID] = { name = "Recipe: Bar", classID = Enum.ItemClass.Recipe, subClassID = 1 }
      state.tooltip[LINK] = { "Recipe: Bar" }          -- loaded; this char doesn't know it
      assert.is_false(ns.IsKnown(LINK))
      state.tooltip[LINK] = { "Already known." }        -- would flip live...
      assert.is_false(ns.IsKnown(LINK))                 -- ...but the reliable negative holds
    end)
  end)
end)
