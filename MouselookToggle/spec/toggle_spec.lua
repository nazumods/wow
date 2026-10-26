local ml = require("MouselookToggle.spec.mouselook")

describe("MouselookToggle keybind", function()
  local w
  before_each(function() w = ml.load() end)

  it("starts mouselook when idle", function()
    w.toggle()
    assert.equals(1, w.count("MouselookStart"))
    assert.is_true(w.state.looking)
  end)

  it("arms the centering CVars a frame late, height as a fraction of the screen", function()
    w.toggle()
    assert.same({ "MouselookStart" }, w.state.calls)   -- nothing live while mouselook is starting
    w.state.flush()
    assert.same({ "SetTemporaryCVar", "CursorCenteredYPos", 0.5 }, w.state.calls[2])
    assert.same({ "SetTemporaryCVar", "CursorFreelookCentering", 1 }, w.state.calls[3])
  end)

  it("uses the saved reticle height", function()
    w.ns.db.reticleHeight = 70
    w.toggle()
    w.state.flush()
    assert.same({ "SetTemporaryCVar", "CursorCenteredYPos", 0.7 }, w.state.calls[2])
  end)

  it("does not arm the CVars if mouselook ended before the deferred frame", function()
    w.toggle()
    w.state.looking = false
    w.state.flush()
    assert.equals(1, #w.state.calls)
  end)

  it("a second press stops mouselook and restores the CVars", function()
    w.toggle()
    w.state.flush()
    w.toggle()
    assert.equals(1, w.count("MouselookStop"))
    assert.equals(1, w.count("RestoreCVars"))
    assert.is_false(w.state.looking)
  end)

  it("a press after un-toggling does not arm stale CVars", function()
    w.toggle()
    w.toggle()   -- stopped before the deferred frame ran
    w.state.flush()
    for _, c in ipairs(w.state.calls) do assert.is_not.equals("table", type(c)) end
  end)

  it("ignores the keybind while a mouse button is held (would leave the character auto-running)", function()
    w.state.buttons.RightButton = true
    w.toggle()
    w.state.buttons.RightButton, w.state.buttons.LeftButton = nil, true
    w.toggle()
    assert.same({}, w.state.calls)
  end)

  it("ignores the keybind mid-click even while already mouselooking", function()
    w.toggle()
    w.state.buttons.LeftButton = true
    w.toggle()
    assert.equals(0, w.count("MouselookStop"))
    assert.is_true(w.state.looking)
  end)
end)

describe("MouselookToggle reticle", function()
  local w
  before_each(function() w = ml.load() end)

  it("is hidden and idle when not mouselooking", function()
    w.tick()
    assert.is_false(w.crosshair.shown)
  end)

  it("toggled mouselook shows the reticle immediately", function()
    w.toggle()
    w.tick(0.1)
    assert.is_true(w.crosshair.shown)
  end)

  it("fades in over FADE_TIME, then holds full alpha", function()
    w.toggle()
    w.tick(0)
    assert.equals(0, w.crosshair.alpha)
    w.tick(0.1)
    assert.is_true(math.abs(w.crosshair.alpha - 0.5) < 1e-9)
    w.tick(1)
    assert.equals(1, w.crosshair.alpha)
  end)

  it("held (non-toggled) freelook debounces: hidden until SHOW_DELAY has elapsed", function()
    w.state.looking = true
    w.tick(0)
    assert.is_false(w.crosshair.shown)
    w.tick(0.2)
    assert.is_false(w.crosshair.shown)
    w.tick(0.2)   -- 0.4s held > 0.3s delay
    assert.is_true(w.crosshair.shown)
  end)

  it("held freelook never shows the reticle when 'show during held' is off", function()
    w.ns.db.showHeld = false
    w.state.looking = true
    w.tick(0)
    w.tick(5)
    assert.is_false(w.crosshair.shown)
  end)

  it("hides again when mouselook ends", function()
    w.toggle()
    w.tick(1)
    w.state.looking = false
    w.tick(0.1)
    assert.is_false(w.crosshair.shown)
  end)

  it("follows the cursor position", function()
    w.toggle()
    w.tick(1)
    assert.same({ "CENTER", _G.UIParent, "BOTTOMLEFT", 400, 300 }, w.reticle.point)
  end)

  describe("right-click cancel of toggled mouselook", function()
    local function toggled()
      w.toggle()
      w.state.flush()
      w.tick(0.1)
    end

    it("cancels on the right button's release edge, restoring the CVars", function()
      toggled()
      w.state.buttons.RightButton = true
      w.tick(0.1)                          -- held: not yet
      assert.is_true(w.state.looking)
      w.state.buttons.RightButton = nil
      w.tick(0.1)                          -- released: cancel
      assert.is_false(w.state.looking)
      assert.equals(1, w.count("MouselookStop"))
      assert.equals(1, w.count("RestoreCVars"))
      assert.is_false(w.crosshair.shown)
    end)

    it("does not cancel while the right button is merely held", function()
      toggled()
      w.state.buttons.RightButton = true
      w.tick(0.1)
      w.tick(0.1)
      assert.is_true(w.state.looking)
    end)

    it("does not cancel on release while the left button is also down (would auto-run)", function()
      toggled()
      w.state.buttons.RightButton, w.state.buttons.LeftButton = true, true
      w.tick(0.1)
      w.state.buttons.RightButton = nil
      w.tick(0.1)
      assert.is_true(w.state.looking)
      assert.equals(0, w.count("MouselookStop"))
    end)

    it("a right-click on held (non-toggled) freelook is the client's own business: no cancel", function()
      w.state.looking = true
      w.state.buttons.RightButton = true
      w.tick(0.1)
      w.state.buttons.RightButton = nil
      w.tick(0.1)
      assert.equals(0, w.count("MouselookStop"))
    end)

    it("restores the CVars when toggled mouselook ends some other way", function()
      toggled()
      w.state.looking = false
      w.tick(0.1)
      assert.equals(1, w.count("RestoreCVars"))
      w.tick(0.1)
      assert.equals(1, w.count("RestoreCVars"))   -- only once
    end)
  end)
end)

describe("MouselookToggle MigrateDB", function()
  it("seeds defaults without overwriting saved values", function()
    local w = ml.load()
    w.ns.db = { reticleHeight = 30, showHeld = false }
    w.ns:MigrateDB()
    assert.equals(30, w.ns.db.reticleHeight)
    assert.is_false(w.ns.db.showHeld)
    w.ns.db = {}
    w.ns:MigrateDB()
    assert.equals(50, w.ns.db.reticleHeight)
    assert.is_true(w.ns.db.showHeld)
    assert.equals(1, w.ns.db.version)
  end)
end)
