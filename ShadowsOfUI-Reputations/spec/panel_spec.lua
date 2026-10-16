local reputations = require("ShadowsOfUI-Reputations.spec.reputations")

local function has(lines, needle)
  for _, l in ipairs(lines) do
    if l:find(needle, 1, true) then return true end
  end
  return false
end

describe("ShadowsOfUI-Reputations panel hooks", function()
  it("Retail: appends to an owned tooltip", function()
    local w = reputations.load({ forever = false })
    w.enter()
    assert.is_true(w.tooltip.shown)
    assert.equal(w.row, w.tooltip.owner)
    assert.is_true(has(w.tooltip.lines, "Blizzard tooltip"))
    assert.is_true(has(w.tooltip.lines, "Standing across your warband"))
  end)

  it("Retail: an unowned row shows nothing", function()
    local w = reputations.load({ forever = false, blizzardOpens = false }) -- e.g. a Paragon row
    w.enter()
    assert.is_false(w.tooltip.shown)
    assert.is_nil(w.tooltip.owner)
    assert.same({}, w.tooltip.lines)
  end)

  it("Forever: an unowned row gets the addon's own tooltip with the faction name and standings", function()
    local w = reputations.load({ forever = true })
    w.enter()
    assert.is_true(w.tooltip.shown)
    assert.equal(w.row, w.tooltip.owner)
    assert.equal("Faction 2640", w.tooltip.lines[1])
    assert.is_true(has(w.tooltip.lines, "Standing across your warband"))
  end)

  it("Forever: a selected row gets none", function()
    local w = reputations.load({ forever = true, selected = true })
    w.enter()
    assert.is_false(w.tooltip.shown)
    assert.is_nil(w.tooltip.owner)
  end)

  it("Forever: no standings -> no tooltip", function()
    local w = reputations.load({ forever = true, standings = false })
    w.enter()
    assert.is_false(w.tooltip.shown)
    assert.equal(1, w.tooltip.hides)
  end)

  it("OnLeave hides only the addon's own tooltip", function()
    -- Forever: the tooltip the addon opened is hidden when the row is left ...
    local f = reputations.load({ forever = true })
    f.enter()
    f.leave()
    assert.is_false(f.tooltip.shown)

    -- ... but one something else owns is left alone ...
    local g = reputations.load({ forever = true })
    g.enter()
    g.tooltip.owner = {}   -- another frame took GameTooltip meanwhile
    g.tooltip.shown = true
    g.leave()
    assert.is_true(g.tooltip.shown)

    -- ... and Retail's own tooltip (the addon only appended to it) is never hidden by us.
    local r = reputations.load({ forever = false })
    r.enter()
    r.leave()
    assert.is_true(r.tooltip.shown)
    assert.equal(0, r.tooltip.hides)
  end)
end)
