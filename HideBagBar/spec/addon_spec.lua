-- Loads HideBagBar/addon.lua against a fake environment: CreateFrame hands back a frame
-- that records its OnEvent script, and each Blizzard bag-bar frame is a stub that records
-- SetShown. Path is relative to the AddOns root.
local HIDDEN = {
  "MainMenuBarBackpackButton", "BagBarExpandToggle", "CharacterBag0Slot", "CharacterBag1Slot",
  "CharacterBag2Slot", "CharacterBag3Slot", "CharacterReagentBag0Slot",
}
-- Forever's bag bar adds a key ring button; roshne decided it stays visible (2026-10-15).
local KEY_RING = "KeyRingButton"

local function with_key_ring()
  local all = { unpack(HIDDEN) }
  all[#all + 1] = KEY_RING
  return all
end

local function stub()
  local f = { shown = true }
  function f:SetShown(v) self.shown = v end
  return f
end

-- `present`: the frame names that exist on this client; the rest are nil, as on a client
-- whose bag bar lacks them. Returns the loaded OnEvent handler and the frames by name.
local function load(present, manager)
  local env = { frames = {} }
  env.MainMenuBarBagManager = manager
  env.hooksecurefunc = function(tbl, name, hook)
    local orig = tbl[name]
    tbl[name] = function(...) orig(...); hook(...) end
  end
  env._G = env
  for _, name in ipairs(present) do
    env.frames[name] = stub()
    env[name] = env.frames[name]
  end
  env.CreateFrame = function()
    local f = { RegisterEvent = function() end }
    function f:SetScript(_, fn) env.onEvent = fn end
    return f
  end
  setmetatable(env, { __index = _G })
  local chunk = assert(loadfile("HideBagBar/addon.lua"))
  setfenv(chunk, env)
  chunk("HideBagBar")
  return env
end

describe("HideBagBar", function()
  it("hides every listed frame", function()
    local env = load(HIDDEN)
    env.onEvent({}, "ADDON_LOADED", "HideBagBar")
    for _, name in ipairs(HIDDEN) do
      assert.is_false(env.frames[name].shown, name)
    end
  end)

  it("a missing frame does not stop the later ones", function()
    local present = {}
    for _, name in ipairs(HIDDEN) do
      if name ~= "BagBarExpandToggle" then present[#present + 1] = name end
    end
    local env = load(present)
    env.onEvent({}, "ADDON_LOADED", "HideBagBar")
    for _, name in ipairs(present) do
      assert.is_false(env.frames[name].shown, name)
    end
  end)

  it("leaves KeyRingButton shown when it exists", function()
    local env = load(with_key_ring())
    env.onEvent({}, "ADDON_LOADED", "HideBagBar")
    assert.is_true(env.frames[KEY_RING].shown)
    for _, name in ipairs(HIDDEN) do
      assert.is_false(env.frames[name].shown, name)
    end
  end)

  it("re-hides the slots when Blizzard re-shows them via OnExpandBarChanged", function()
    local manager = {}
    local env
    function manager.OnExpandBarChanged()
      for _, f in pairs(env.frames) do f:SetShown(true) end
    end
    env = load(HIDDEN, manager)
    env.onEvent({}, "ADDON_LOADED", "HideBagBar")
    manager.OnExpandBarChanged()
    for _, name in ipairs(HIDDEN) do
      assert.is_false(env.frames[name].shown, name)
    end
  end)

  it("loads without error when MainMenuBarBagManager is absent", function()
    local env = load(HIDDEN)
    assert.has_no.errors(function() env.onEvent({}, "ADDON_LOADED", "HideBagBar") end)
  end)

  it("does nothing for another addon's ADDON_LOADED", function()
    local env = load(with_key_ring())
    env.onEvent({}, "ADDON_LOADED", "SomeOtherAddon")
    for _, name in ipairs(with_key_ring()) do
      assert.is_true(env.frames[name].shown, name)
    end
  end)
end)
