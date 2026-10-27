local cb = require("ShadowsOfUI-Castbar.spec.castbar")

-- UnitCastingInfo: name, text, tex, startMS, endMS, isTradeSkill, castID, notInterruptible
-- UnitChannelInfo: name, text, tex, startMS, endMS, isTradeSkill, notInterruptible
local function cast(name, startMS, endMS, notInterruptible)
  return { name, name .. " text", "tex:" .. name, startMS, endMS, false, 1, notInterruptible }
end
local function channel(name, startMS, endMS, notInterruptible)
  return { name, name .. " text", "tex:" .. name, startMS, endMS, false, notInterruptible }
end

describe("ShadowsOfUI-Castbar CastBar:Refresh", function()
  local CastBar, state, bar
  before_each(function()
    CastBar, state = cb.load()
    bar = cb.newBar(CastBar)
  end)

  it("does nothing while Edit Mode or the settings preview owns the bar", function()
    state.casting = cast("Fireball", 1000, 3000)
    CastBar.Refresh(cb.newBar(CastBar, { _editMode = true }))
    local b = cb.newBar(CastBar, { _preview = true })
    CastBar.Refresh(b)
    assert.same({}, b.log)
  end)

  it("hides and stops updates when the bar is disabled", function()
    state.casting = cast("Fireball", 1000, 3000)
    bar._enabled = false
    CastBar.Refresh(bar)
    assert.is_true(cb.logged(bar, "Hide"))
    assert.is_true(cb.logged(bar, "stopUpdates"))
    assert.is_false(cb.logged(bar, "Show"))
  end)

  it("hides when the unit is neither casting nor channelling", function()
    CastBar.Refresh(bar)
    assert.is_true(cb.logged(bar, "Hide"))
    assert.is_true(cb.logged(bar, "stopUpdates"))
    assert.is_false(cb.logged(bar, "Show"))
  end)

  it("paints a readable cast: name, icon, range, show, start updates, one immediate tick", function()
    state.casting = cast("Fireball", 1000, 3000)
    CastBar.Refresh(bar)
    assert.equals("Fireball text", bar.name)
    assert.equals("tex:Fireball", bar.iconTex)
    assert.same({ 1000, 3000 }, bar.range)
    assert.is_false(bar._channel)
    assert.is_false(bar._secretTime)
    assert.equals(3000, bar._endMS)
    assert.is_true(cb.logged(bar, "Show"))
    assert.is_true(cb.logged(bar, "startUpdates"))
    assert.is_true(cb.logged(bar, "onUpdate"))
  end)

  it("falls back to the spell name when the cast has no display text", function()
    state.casting = { "Fireball", nil, "tex", 1, 2, false, 1, false }
    CastBar.Refresh(bar)
    assert.equals("Fireball", bar.name)
  end)

  it("reads a channel when nothing is casting, with the interruptible flag in its own slot", function()
    state.channel = channel("Drain", 1000, 5000, true)
    CastBar.Refresh(bar)
    assert.is_true(bar._channel)
    assert.equals("Drain text", bar.name)
    assert.same({ 1000, 5000 }, bar.range)
    assert.equals(120, bar.color)   -- CHANNEL green, even though notInterruptible is true
  end)

  it("a cast wins over a simultaneous channel read", function()
    state.casting = cast("Fireball", 1, 2)
    state.channel = channel("Drain", 3, 4)
    CastBar.Refresh(bar)
    assert.equals("Fireball text", bar.name)
    assert.is_false(bar._channel)
  end)

  describe("secret cast timing (enemy target/focus)", function()
    it("passes the secret start/end straight to the StatusBar without arithmetic", function()
      local secret = cb.secret
      state.secretValues[secret] = true
      state.casting = cast("Fireball", secret, secret, secret)
      assert.has_no.errors(function() CastBar.Refresh(bar) end)
      assert.is_true(bar._secretTime)
      assert.equals(secret, bar.range[1])
      assert.equals(secret, bar.range[2])
      assert.is_true(cb.logged(bar, "Show"))
    end)

    it("blanks the time text, since the remaining time cannot be computed", function()
      state.secretValues[cb.secret] = true
      bar.time = "stale"
      state.casting = cast("Fireball", cb.secret, cb.secret, false)
      CastBar.Refresh(bar)
      assert.equals("", bar.time)
    end)

    it("keeps the time text for a readable (own/friendly) cast", function()
      bar.time = "stale"
      state.casting = cast("Fireball", 1000, 3000)
      CastBar.Refresh(bar)
      assert.equals("stale", bar.time)   -- Refresh leaves it; onUpdate writes it
    end)

    it("treats the timing as readable where canaccessvalue does not exist (Forever)", function()
      CastBar, state = cb.load({ canaccess = false })
      bar = cb.newBar(CastBar)
      state.casting = cast("Fireball", 1000, 3000, true)
      CastBar.Refresh(bar)
      assert.is_false(bar._secretTime)
    end)
  end)
end)

describe("ShadowsOfUI-Castbar CastBar:applyColor", function()
  local CastBar, state, bar
  before_each(function()
    CastBar, state = cb.load()
    bar = cb.newBar(CastBar)
  end)

  it("normal cast is the amber fill", function()
    bar._channel = false
    bar:applyColor(false)
    assert.equals(255, bar.color)
  end)

  it("a readable non-interruptible cast is greyed", function()
    bar._channel = false
    bar:applyColor(true)
    assert.equals(150, bar.color)
  end)

  it("a secret interruptible flag is never tested: the cast stays amber", function()
    state.secretValues[cb.secret] = true
    bar._channel = false
    assert.has_no.errors(function() bar:applyColor(cb.secret) end)
    assert.equals(255, bar.color)
  end)

  it("a channel is green regardless of the flag", function()
    bar._channel = true
    bar:applyColor(true)
    assert.equals(120, bar.color)
  end)

  it("without canaccessvalue (Forever) a non-interruptible cast is never greyed", function()
    CastBar, state = cb.load({ canaccess = false })
    bar = cb.newBar(CastBar, { _channel = false })
    bar:applyColor(true)
    assert.equals(255, bar.color)
  end)
end)

describe("ShadowsOfUI-Castbar CastBar:onUpdate", function()
  local CastBar, state, bar
  before_each(function()
    CastBar, state = cb.load()
    bar = cb.newBar(CastBar)
  end)

  it("feeds the clock in ms to the native fill and shows the remaining seconds", function()
    state.time = 100
    bar._endMS = 103500
    CastBar.onUpdate(bar)
    assert.equals(100000, bar.value)
    assert.equals("3.5", bar.time)
  end)

  it("clamps the remaining time at zero", function()
    state.time = 100
    bar._endMS = 99000
    CastBar.onUpdate(bar)
    assert.equals("0.0", bar.time)
  end)

  it("leaves the time text alone when the timing is secret", function()
    bar._secretTime, bar._endMS = true, cb.secret
    bar.time = ""
    assert.has_no.errors(function() CastBar.onUpdate(bar) end)
    assert.equals("", bar.time)
    assert.equals(100000, bar.value)
  end)

  it("sizes from the text size: height = size + 10, width = 10 x height", function()
    local w, h = CastBar.dims(12)
    assert.equals(22, h)
    assert.equals(220, w)
    w, h = CastBar.dims(22)
    assert.equals(32, h)
    assert.equals(320, w)
  end)
end)
