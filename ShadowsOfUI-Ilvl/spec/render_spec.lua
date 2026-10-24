-- Loads ShadowsOfUI-Ilvl/render.lua against a fake environment: C_Item is stubbed (the
-- upgrade-info answer is per test) and ns carries the flavor flag the real addon gets
-- from LibNAddOn. Path is relative to the AddOns root.
local function load(isForever, upgradeInfo)
  local calls = { upgrade = 0 }
  local env = {
    C_Item = {
      GetItemUpgradeInfo = function(link)
        calls.upgrade = calls.upgrade + 1
        calls.lastLink = link
        return upgradeInfo
      end,
      GetItemInfoInstant = function() end,
      GetItemQualityColor = function() return 1, 1, 1 end,
    },
  }
  env._G = env
  setmetatable(env, { __index = _G })
  local ns = { flavor = { isForever = isForever } }
  local chunk = assert(loadfile("ShadowsOfUI-Ilvl/render.lua"))
  setfenv(chunk, env)
  chunk("ShadowsOfUI-Ilvl", ns)
  return ns, calls
end

local ONRIGHT = { "LEFT", "RIGHT", 6, 0, "LEFT" }
local ONLEFT  = { "RIGHT", "LEFT", -6, 0, "RIGHT" }
local ABOVE   = { "BOTTOM", "TOP", 0, 3, "CENTER" }

local WEAPON_ROW = { "MainHand", "SecondaryHand", "Ranged" }
local LEFT_COLUMN = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }
local RIGHT_COLUMN = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }

describe("ShadowsOfUI-Ilvl TrackFromLink", function()
  it("TrackFromLink: nil upgrade info -> nil", function()
    local ns = load(true, nil)
    assert.is_nil(ns.TrackFromLink("|Hitem:1|h[x]|h"))
  end)

  it("TrackFromLink: currentLevel 0 (Forever's empty C_ItemUpgrade) -> nil", function()
    local ns = load(true, { trackString = "Champion", currentLevel = 0 })
    assert.is_nil(ns.TrackFromLink("|Hitem:1|h[x]|h"))
  end)

  it("TrackFromLink: no trackString -> nil", function()
    local ns = load(true, { currentLevel = 2 })
    assert.is_nil(ns.TrackFromLink("|Hitem:1|h[x]|h"))
  end)

  -- #1082: the letter is the first CHARACTER, not the first byte — a one-byte slice of a
  -- Cyrillic/CJK track name is invalid UTF-8.
  it("TrackFromLink: takes the first character of a multi-byte track name", function()
    local ns = load(false, { trackString = "Герой", currentLevel = 3 })
    assert.equal("Г3", ns.TrackFromLink("|Hitem:1|h[x]|h"))
    ns = load(false, { trackString = "英雄", currentLevel = 6 })
    assert.equal("英6", ns.TrackFromLink("|Hitem:1|h[x]|h"))
  end)

  it("TrackFromLink: Champion level 2 -> \"C2\"", function()
    local ns = load(false, { trackString = "Champion", currentLevel = 2 })
    assert.equals("C2", ns.TrackFromLink("|Hitem:1|h[x]|h"))
  end)

  it("TrackFromLink: nil link -> nil, GetItemUpgradeInfo not called", function()
    local ns, calls = load(false, { trackString = "Champion", currentLevel = 2 })
    assert.is_nil(ns.TrackFromLink(nil))
    assert.equals(0, calls.upgrade)
  end)
end)

describe("ShadowsOfUI-Ilvl inset positions", function()
  it("Retail: weapon row beside the icons exactly as before (MainHand ONLEFT, SecondaryHand ONRIGHT)", function()
    local pos = load(false).InsetPositions
    for _, prefix in ipairs({ "Character", "Inspect" }) do
      assert.same(ONLEFT, pos[prefix .. "MainHandSlot"])
      assert.same(ONRIGHT, pos[prefix .. "SecondaryHandSlot"])
    end
  end)

  it("Retail: every pre-existing slot keeps its position", function()
    local pos = load(false).InsetPositions
    for _, prefix in ipairs({ "Character", "Inspect" }) do
      for _, slot in ipairs(LEFT_COLUMN) do
        assert.same(ONRIGHT, pos[prefix .. slot .. "Slot"], prefix .. slot)
      end
      for _, slot in ipairs(RIGHT_COLUMN) do
        assert.same(ONLEFT, pos[prefix .. slot .. "Slot"], prefix .. slot)
      end
    end
  end)

  it("Forever: the weapon row's six names sit above the icon", function()
    local pos = load(true).InsetPositions
    for _, prefix in ipairs({ "Character", "Inspect" }) do
      for _, slot in ipairs(WEAPON_ROW) do
        assert.same(ABOVE, pos[prefix .. slot .. "Slot"], prefix .. slot)
      end
    end
  end)

  it("Forever: the side columns are unchanged", function()
    local pos = load(true).InsetPositions
    for _, prefix in ipairs({ "Character", "Inspect" }) do
      for _, slot in ipairs(LEFT_COLUMN) do
        assert.same(ONRIGHT, pos[prefix .. slot .. "Slot"], prefix .. slot)
      end
      for _, slot in ipairs(RIGHT_COLUMN) do
        assert.same(ONLEFT, pos[prefix .. slot .. "Slot"], prefix .. slot)
      end
    end
  end)

  it("both flavors list the Ranged slots; neither lists Ammo", function()
    for _, isForever in ipairs({ true, false }) do
      local pos = load(isForever).InsetPositions
      assert.is_truthy(pos.CharacterRangedSlot, tostring(isForever))
      assert.is_truthy(pos.InspectRangedSlot, tostring(isForever))
      assert.is_nil(pos.CharacterAmmoSlot, tostring(isForever))
      assert.is_nil(pos.InspectAmmoSlot, tostring(isForever))
    end
  end)

  it("loading render.lua sets ns.InsetPositions for the detected flavor", function()
    assert.same(ABOVE, load(true).InsetPositions.CharacterMainHandSlot)
    assert.same(ONLEFT, load(false).InsetPositions.CharacterMainHandSlot)
  end)
end)
