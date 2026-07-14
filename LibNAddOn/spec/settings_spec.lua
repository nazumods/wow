-- ns.getSettingsSubcategory is the get-or-create that stops a per-addon Changelog
-- button (and any other caller) from minting a duplicate subcategory line under a
-- shared parent. The real Settings framework only runs in-game, so load settings.lua
-- standalone against a stubbed `Settings` (mirroring money_spec). The stub models the
-- one property under test: RegisterVerticalLayoutSubcategory is NOT idempotent — each
-- call appends another subcategory — and GetSubcategories/GetName let the lookup find
-- an existing one.

describe("LibNAddOn ns.getSettingsSubcategory", function()
  local getSettingsSubcategory, getSettingsParent, created

  -- A minimal category: its name plus the array of subcategories the framework would
  -- append to. Methods ignore `self` (the closures capture what they need).
  local function makeCategory(name)
    local subs = {}
    return {
      GetName = function() return name end,
      GetSubcategories = function() return subs end,
      subs = subs,
    }
  end

  before_each(function()
    created = {} -- names passed to RegisterVerticalLayoutSubcategory, in order
    _G.Settings = {
      RegisterVerticalLayoutCategory = function(name) return makeCategory(name) end,
      RegisterAddOnCategory = function() end,
      RegisterVerticalLayoutSubcategory = function(parent, name)
        local sub = makeCategory(name)
        table.insert(parent.subs, sub) -- what a real registration does
        table.insert(created, name)
        return sub
      end,
    }
    local ns = {}
    assert(loadfile("LibNAddOn/settings.lua"))("LibNAddOn", ns)
    getSettingsSubcategory = ns.getSettingsSubcategory
    getSettingsParent = ns.getSettingsParent
  end)

  after_each(function()
    _G.Settings = nil -- undo the stub
  end)

  it("registers a subcategory the first time", function()
    local c = getSettingsSubcategory("Shadows of UI", "Collectible Tints")
    assert.equal("Collectible Tints", c:GetName())
    assert.same({ "Collectible Tints" }, created)
  end)

  it("reuses the same subcategory on a repeat call — no duplicate line", function()
    local first = getSettingsSubcategory("Shadows of UI", "Collectible Tints")
    local second = getSettingsSubcategory("Shadows of UI", "Collectible Tints")
    assert.equal(first, second) -- same object
    assert.same({ "Collectible Tints" }, created) -- registered once, not twice
  end)

  it("registers distinct subcategories for distinct titles under one parent", function()
    getSettingsSubcategory("Shadows of UI", "Collectible Tints")
    getSettingsSubcategory("Shadows of UI", "Item Level")
    assert.same({ "Collectible Tints", "Item Level" }, created)
  end)

  it("reuses a subcategory registered by another path (the actual fix)", function()
    -- Simulate the addon's own subcategory already registered under the parent (e.g.
    -- by declarative ns:RegisterSettings) — getSettingsSubcategory must find and reuse
    -- it rather than adding a second "Recipe Learners" line.
    local parent = getSettingsParent("Shadows of UI")
    table.insert(parent.subs, makeCategory("Recipe Learners"))
    local c = getSettingsSubcategory("Shadows of UI", "Recipe Learners")
    assert.equal("Recipe Learners", c:GetName())
    assert.same({}, created) -- reused; nothing newly registered
  end)
end)
