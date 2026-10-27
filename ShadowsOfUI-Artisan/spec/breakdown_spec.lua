local artisan = require("ShadowsOfUI-Artisan.spec.artisan")
local toon, TAILORING, MINING = artisan.toon, artisan.TAILORING, artisan.MINING

local function names(list)
  local out = {}
  for _, e in ipairs(list) do out[#out + 1] = e.name end
  return out
end

describe("ShadowsOfUI-Artisan BuildBreakdown", function()
  it("returns nil for a skill line with no mapped currency", function()
    local ns = artisan.load({ toons = {} })
    assert.is_nil(ns.BuildBreakdown(999999))
  end)

  it("returns nil when the Warbandeer API is not there", function()
    local ns = artisan.load({ noApi = true })
    assert.is_nil(ns.BuildBreakdown(TAILORING))
  end)

  it("lists only characters that have the profession", function()
    local ns = artisan.load({ current = "Me", live = 0, toons = {
      toon("Me", { primary = TAILORING }),
      toon("Miner", { primary = MINING }),
    } })
    assert.same({ "Me" }, names(ns.BuildBreakdown(TAILORING)))
  end)

  it("finds the profession in any of the four slots", function()
    local ns = artisan.load({ current = "Me", live = 0, toons = {
      toon("A", { primary = TAILORING }),
      toon("B", { secondary = TAILORING }),
      toon("C", { fishing = TAILORING }),
      toon("D", { cooking = TAILORING }),
    } })
    assert.equals(4, #ns.BuildBreakdown(TAILORING))
  end)

  it("tolerates a character with no profession data at all", function()
    local ns = artisan.load({ current = "Me", live = 0, toons = {
      { name = "Bare", classKey = "Mage" },
      { name = "NoProfs", classKey = "Mage", basic = {} },
      toon("Me", { primary = TAILORING }),
    } })
    assert.same({ "Me" }, names(ns.BuildBreakdown(TAILORING)))
  end)

  it("reads the logged-in character's amount live, ignoring its stale cache", function()
    local ns = artisan.load({ current = "Me", live = 120, toons = {
      toon("Me", { primary = TAILORING }, { [TAILORING] = 5 }),
    } })
    local e = ns.BuildBreakdown(TAILORING)[1]
    assert.equals(120, e.quantity)
    assert.is_true(e.isCurrent)
  end)

  it("reads alts from the Warbandeer_Characters cache", function()
    local ns = artisan.load({ current = "Me", live = 0, toons = {
      toon("Me", { primary = TAILORING }),
      toon("Alt", { primary = TAILORING }, { [TAILORING] = 75 }),
    } })
    local list = ns.BuildBreakdown(TAILORING)
    assert.equals("Alt", list[1].name)
    assert.equals(75, list[1].quantity)
    assert.is_false(list[1].isCurrent)
  end)

  it("an alt that has never logged in since the broker shipped counts as 0, not nil", function()
    local ns = artisan.load({ current = "Me", live = 10, toons = {
      toon("Me", { primary = TAILORING }),
      toon("Fresh", { primary = TAILORING }),                       -- no artisanCurrency at all
      toon("Other", { primary = TAILORING }, { [MINING] = 40 }),    -- cache for a different skill line
    } })
    local byName = {}
    for _, e in ipairs(ns.BuildBreakdown(TAILORING)) do byName[e.name] = e.quantity end
    assert.equals(0, byName.Fresh)
    assert.equals(0, byName.Other)
  end)

  it("the live read is 0 when GetCurrencyInfo answers nothing", function()
    local ns = artisan.load({ current = "Me", toons = { toon("Me", { primary = TAILORING }) } })
    assert.equals(0, ns.BuildBreakdown(TAILORING)[1].quantity)
  end)

  describe("ordering", function()
    local function sorted(intent, toons)
      local ns = artisan.load({ current = "Nobody", intent = intent, toons = toons })
      return names(ns.BuildBreakdown(TAILORING))
    end

    it("main, then secondary, then everyone else", function()
      local toons = {
        toon("Other", { primary = TAILORING }, { [TAILORING] = 900 }),
        toon("Second", { primary = TAILORING }, { [TAILORING] = 50 }),
        toon("Main", { primary = TAILORING }, { [TAILORING] = 10 }),
      }
      local intent = { Main = { [TAILORING] = "main" }, Second = { [TAILORING] = "secondary" } }
      assert.same({ "Main", "Second", "Other" }, sorted(intent, toons))
    end)

    it("within a rank, higher quantity first", function()
      local toons = {
        toon("Low", { primary = TAILORING }, { [TAILORING] = 10 }),
        toon("High", { primary = TAILORING }, { [TAILORING] = 99 }),
      }
      assert.same({ "High", "Low" }, sorted(nil, toons))
    end)

    it("ties break alphabetically", function()
      local toons = {
        toon("Zed", { primary = TAILORING }, { [TAILORING] = 5 }),
        toon("Amy", { primary = TAILORING }, { [TAILORING] = 5 }),
      }
      assert.same({ "Amy", "Zed" }, sorted(nil, toons))
    end)

    it("an intent set for a different profession does not rank this one", function()
      local toons = {
        toon("MinerMain", { primary = TAILORING }, { [TAILORING] = 1 }),
        toon("Other", { primary = TAILORING }, { [TAILORING] = 2 }),
      }
      local intent = { MinerMain = { [MINING] = "main" } }
      assert.same({ "Other", "MinerMain" }, sorted(intent, toons))
    end)

    it("with no Warbandeer installed everyone ranks equal (3)", function()
      local ns = artisan.load({ current = "Nobody", toons = { toon("A", { primary = TAILORING }) } })
      assert.equals(3, ns.BuildBreakdown(TAILORING)[1].rank)
    end)

    it("an unrecognised intent value falls to rank 3", function()
      local intent = { A = { [TAILORING] = "gatherer" } }
      local ns = artisan.load({ current = "Nobody", intent = intent, toons = { toon("A", { primary = TAILORING }) } })
      assert.equals(3, ns.BuildBreakdown(TAILORING)[1].rank)
    end)
  end)
end)
