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
