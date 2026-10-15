-- Loads HideBagBar/addon.lua against a fake environment: CreateFrame hands back a frame
-- that records its OnEvent script, and each Blizzard bag-bar frame is a stub that records
-- SetShown. Path is relative to the AddOns root.
local ALL = {
  "MainMenuBarBackpackButton", "BagBarExpandToggle", "CharacterBag0Slot", "CharacterBag1Slot",
  "CharacterBag2Slot", "CharacterBag3Slot", "CharacterReagentBag0Slot", "KeyRingButton",
}

local function stub()
  local f = { shown = true }
  function f:SetShown(v) self.shown = v end
  return f
end

-- `present`: the frame names that exist on this client; the rest are nil, as on a client
-- whose bag bar lacks them. Returns the loaded OnEvent handler and the frames by name.
local function load(present)
  local env = { frames = {} }
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
    local env = load({ unpack(ALL, 1, 7) })
    env.onEvent({}, "ADDON_LOADED", "HideBagBar")
    for i = 1, 7 do
      assert.is_false(env.frames[ALL[i]].shown, ALL[i])
    end
  end)

  it("a missing frame does not stop the later ones", function()
    local present = {}
    for _, name in ipairs(ALL) do
      if name ~= "BagBarExpandToggle" then present[#present + 1] = name end
    end
    local env = load(present)
    env.onEvent({}, "ADDON_LOADED", "HideBagBar")
    for _, name in ipairs(present) do
      assert.is_false(env.frames[name].shown, name)
    end
  end)

  it("hides KeyRingButton when it exists", function()
    local env = load(ALL)
    env.onEvent({}, "ADDON_LOADED", "HideBagBar")
    assert.is_false(env.frames.KeyRingButton.shown)
  end)

  it("does nothing for another addon's ADDON_LOADED", function()
    local env = load(ALL)
    env.onEvent({}, "ADDON_LOADED", "SomeOtherAddon")
    for _, name in ipairs(ALL) do
      assert.is_true(env.frames[name].shown, name)
    end
  end)
end)
