local recycle = require("Recycle.spec.recycle")

-- #1009: a manual mark on an equippable item marked every copy sharing its itemID, so marking a Normal
-- ring also sold the Mythic one looted weeks later. Equippables are now marked per copy; stackables
-- (and every mark made before per-copy marks) keep the all-copies meaning.
describe("Recycle manual sell marks", function()
  local RING, ORE = 1000, 2000
  local normal = recycle.link(RING, 14, { 6652, 1472 })
  local mythic = recycle.link(RING, 23, { 6652, 1537 })

  local ns, bagLink
  before_each(function()
    bagLink = normal
    ns = recycle.load{
      armor = { [RING] = true },
      container = {
        GetContainerItemInfo = function(_, _)
          return { itemID = RING, hyperlink = bagLink, stackCount = 1, quality = 4 }
        end,
      },
    }
  end)
  after_each(function() recycle.restore() end)

  it("sells only the marked copy of an equippable item", function()
    ns.ToggleMark(0, 1)   -- marks `normal`
    assert.is_true(ns.ShouldSell(RING, 4, normal))
    assert.is_false(ns.ShouldSell(RING, 4, mythic))
  end)

  it("does not mark the other copy as a side effect, and can mark both independently", function()
    ns.ToggleMark(0, 1)
    bagLink = mythic
    ns.ToggleMark(0, 1)
    assert.is_true(ns.ShouldSell(RING, 4, normal))
    assert.is_true(ns.ShouldSell(RING, 4, mythic))
  end)

  it("toggling the same copy again clears its mark", function()
    ns.ToggleMark(0, 1)
    ns.ToggleMark(0, 1)
    assert.is_false(ns.ShouldSell(RING, 4, normal))
    assert.is_nil(next(ns.db.copiesToSell))
  end)

  it("keeps the same copy key across a different linking level, enchant and gems", function()
    ns.ToggleMark(0, 1)
    local relinked = recycle.link(RING, 14, { 6652, 1472 }, 70)
    assert.is_true(ns.ShouldSell(RING, 4, relinked))
  end)

  it("a stackable mark still sells every stack, whatever link it carries", function()
    ns.db.itemsToSell[ORE] = true
    assert.is_true(ns.ShouldSell(ORE, 1, recycle.link(ORE, 0, {})))
    assert.is_true(ns.ShouldSell(ORE, 1, nil))
  end)

  it("marking a non-equippable item goes into itemsToSell, not the per-copy table", function()
    local ore = recycle.link(ORE, 0, {})
    local ns2 = recycle.load{
      container = { GetContainerItemInfo = function() return { itemID = ORE, hyperlink = ore, quality = 1 } end },
    }
    ns2.ToggleMark(0, 1)
    assert.is_true(ns2.db.itemsToSell[ORE])
    assert.is_nil(ns2.db.copiesToSell)
  end)

  it("reads an existing all-copies mark exactly as before (every copy), and toggling clears it", function()
    ns.db.itemsToSell[RING] = true
    assert.is_true(ns.ShouldSell(RING, 4, normal))
    assert.is_true(ns.ShouldSell(RING, 4, mythic))
    ns.ToggleMark(0, 1)
    assert.is_nil(ns.db.itemsToSell[RING])
    assert.is_false(ns.ShouldSell(RING, 4, mythic))
  end)

  it("sells unmarked grey items only when sellGrey is on", function()
    assert.is_false(ns.ShouldSell(RING, 0, normal))
    ns.db.settings.sellGrey = true
    assert.is_true(ns.ShouldSell(RING, 0, normal))
  end)
end)

-- What a per-copy mark does and does not pin down (#1009 review).
describe("Recycle per-copy marks: edges", function()
  local RING = 1000
  local link = recycle.link(RING, 14, { 6652, 1472 })
  local other = recycle.link(RING, 23, { 6652, 1537 })
  after_each(function() recycle.restore() end)

  local function load(bags, opts)
    opts = opts or {}
    local container = recycle.bags(bags)
    return recycle.load{ armor = { [RING] = true }, container = container, price = opts.price }
  end

  it("marks nothing, and says so, when an equippable has no readable link", function()
    local ns = load({ [0] = { { RING, nil } } })
    ns.ToggleMark(0, 1)
    assert.is_nil(ns.db.itemsToSell[RING])
    assert.is_nil(ns.db.copiesToSell)
    assert.equal(1, #recycle.printed)
  end)

  it("a mark is per VARIANT: two identical twins share it, and both are sold", function()
    local bags = { [0] = { { RING, link }, { RING, link }, { RING, other } } }
    local ns = load(bags)
    ns.ToggleMark(0, 1)
    assert.is_true(ns.ShouldSell(RING, 4, link))
    ns.SellItems()
    assert.is_false(bags[0][1])
    assert.is_false(bags[0][2])
    assert.is_truthy(bags[0][3])   -- the other variant stays
  end)

  it("drops a mark once its copy has been sold, so a later identical drop is kept", function()
    local bags = { [0] = { { RING, link } } }
    local ns = load(bags)
    ns.ToggleMark(0, 1)
    ns.SellItems()
    assert.is_false(bags[0][1])
    assert.is_nil(next(ns.db.copiesToSell))
    assert.is_false(ns.ShouldSell(RING, 4, link))
  end)

  it("drops a mark whose copy is no longer in the bags (upgraded, destroyed, banked)", function()
    local bags = { [0] = { { RING, other } } }
    local ns = load(bags)
    ns.db.copiesToSell = { [recycle.key(RING, 14, { 6652, 1472 })] = true, [recycle.key(RING, 23, { 6652, 1537 })] = true }
    ns.SellItems()
    assert.is_false(bags[0][1])    -- `other` was marked and present: sold
    assert.is_nil(next(ns.db.copiesToSell))
  end)

  it("keeps a mark whose copy could not be sold (no vendor value)", function()
    local bags = { [0] = { { RING, link } } }
    local ns = load(bags, { price = 0 })
    ns.ToggleMark(0, 1)
    ns.SellItems()
    assert.is_truthy(bags[0][1])
    assert.is_true(ns.ShouldSell(RING, 4, link))
  end)
end)

