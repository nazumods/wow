-- globals/actionbars.lua hangs off ns.wow; load it standalone against a minimal ns.
-- ns.wow.classifyBarRects is pure geometry (no WoW API), so it's directly testable —
-- the live-frame reader ns.wow.ReadActionBars stays in-game-tested.

describe("LibNAddOn ns.wow.classifyBarRects", function()
  local classify

  before_each(function()
    local ns = {}
    assert(loadfile("LibNAddOn/globals/actionbars.lua"))("LibNAddOn", ns)
    classify = ns.wow.classifyBarRects
  end)

  -- Build a button rect at (x, y) with size (w, h); y grows upward like UI coords.
  local function rect(x, y, w, h) return { left = x, right = x + w, bottom = y, top = y + h } end

  -- A grid of `cols`×`rows` buttons, 36px each, spaced 40px, bottom-left at origin.
  local function grid(cols, rows)
    local rects = {}
    for r = 0, rows - 1 do
      for c = 0, cols - 1 do rects[#rects + 1] = rect(c * 40, r * 40, 36, 36) end
    end
    return rects
  end

  it("returns nil for no buttons", function()
    assert.is_nil(classify({}))
  end)

  it("classifies a single-row horizontal bar", function()
    local info = classify(grid(12, 1))
    assert.equal(0, info.orientation)
    assert.equal(12, info.numIcons)
    assert.equal(1, info.numRows)
  end)

  it("reports the bounding-box screen left/top as x/y", function()
    local info = classify({ rect(100, 50, 36, 36), rect(140, 50, 36, 36) })
    assert.equal(100, info.x)   -- leftmost left edge
    assert.equal(86, info.y)    -- top = bottom(50) + height(36)
  end)

  it("classifies a single-column vertical bar", function()
    local info = classify(grid(1, 12))
    assert.equal(1, info.orientation)
    assert.equal(12, info.numIcons)
    assert.equal(1, info.numRows)  -- one column
  end)

  it("counts rows for a wide two-row horizontal bar", function()
    local info = classify(grid(6, 2))   -- 6 wide (240) > 2 tall (80) → horizontal
    assert.equal(0, info.orientation)
    assert.equal(12, info.numIcons)
    assert.equal(2, info.numRows)
  end)

  it("counts columns for a tall three-column vertical bar", function()
    local info = classify(grid(3, 4))   -- 3 wide (120) < 4 tall (160) → vertical
    assert.equal(1, info.orientation)
    assert.equal(12, info.numIcons)
    assert.equal(3, info.numRows)  -- stacks along the short axis = columns
  end)

  it("treats a single button as a one-stack horizontal bar", function()
    local info = classify(grid(1, 1))
    assert.equal(0, info.orientation)  -- square: not taller than wide
    assert.equal(1, info.numIcons)
    assert.equal(1, info.numRows)
  end)
end)

-- ns.wow.actionSlotOf reads a button's paged slot from either the LibActionButton
-- state fields or a Blizzard button's plain .action — no WoW API, so it's testable
-- with plain fake button tables.
describe("LibNAddOn ns.wow.actionSlotOf", function()
  local slotOf

  before_each(function()
    local ns = {}
    assert(loadfile("LibNAddOn/globals/actionbars.lua"))("LibNAddOn", ns)
    slotOf = ns.wow.actionSlotOf
  end)

  it("reads a LibActionButton action button's paged slot", function()
    assert.equal(42, slotOf({ _state_type = "action", _state_action = 42 }))
  end)

  it("ignores a LibActionButton button in a non-action state", function()
    assert.is_nil(slotOf({ _state_type = "pet", _state_action = 3 }))
  end)

  it("ignores an action-state button with no numeric slot", function()
    assert.is_nil(slotOf({ _state_type = "action", _state_action = nil }))
  end)

  it("reads a Blizzard button's .action slot", function()
    assert.equal(7, slotOf({ action = 7 }))
  end)

  it("ignores a Blizzard button with a non-numeric action", function()
    assert.is_nil(slotOf({ action = "nope" }))
  end)

  it("returns nil for a non-action button", function()
    assert.is_nil(slotOf({}))
  end)
end)

-- ns.wow.collectActionButtons gathers buttons from LibActionButton (if present) plus
-- the Blizzard default bars by name. Scriptable via _G globals + a fake LibStub.
describe("LibNAddOn ns.wow.collectActionButtons", function()
  local collect
  local created

  before_each(function()
    local ns = {}
    assert(loadfile("LibNAddOn/globals/actionbars.lua"))("LibNAddOn", ns)
    collect = ns.wow.collectActionButtons
    created = {}
  end)

  after_each(function()
    _G.LibStub = nil
    for name in pairs(created) do _G[name] = nil end
  end)

  local function setGlobal(name, val) _G[name] = val; created[name] = true end

  local function idSet(buttons)
    local found = {}
    for _, b in ipairs(buttons) do found[b.id] = true end
    return found
  end

  it("returns Blizzard default-bar buttons when no LibActionButton is present", function()
    _G.LibStub = function() return nil end
    setGlobal("ActionButton1", { id = "ab1" })
    setGlobal("MultiBarBottomLeftButton3", { id = "mbl3" })
    local found = idSet(collect())
    assert.is_true(found.ab1)
    assert.is_true(found.mbl3)
  end)

  it("includes LibActionButton buttons plus the Blizzard fallback", function()
    local labA, labB = { id = "labA" }, { id = "labB" }
    local fakeLAB = { GetAllButtons = function() return { [labA] = true, [labB] = true } end }
    _G.LibStub = function(name) return name == "LibActionButton-1.0" and fakeLAB or nil end
    setGlobal("ActionButton1", { id = "ab1" })
    local found = idSet(collect())
    assert.is_true(found.labA)
    assert.is_true(found.labB)
    assert.is_true(found.ab1)
  end)
end)
