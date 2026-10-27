local questxp = require("ShadowsOfUI-QuestXP.spec.questxp")

describe("ShadowsOfUI-QuestXP GetRewardPercent", function()
  it("is the reward as a whole percent of the level's XP", function()
    local ns = questxp.load({ rewardXP = 25000, maxXP = 100000 })
    assert.equals(25, ns.GetRewardPercent())
  end)

  it("rounds to the nearest percent", function()
    local ns, st = questxp.load({ rewardXP = 1499, maxXP = 100000 })
    assert.equals(1, ns.GetRewardPercent())     -- 1.499
    st.rewardXP = 1500
    assert.equals(2, ns.GetRewardPercent())     -- 1.5 rounds up
  end)

  it("is nil at max level, even with an XP reward", function()
    local ns = questxp.load({ maxLevel = true, rewardXP = 25000 })
    assert.is_nil(ns.GetRewardPercent())
  end)

  it("is nil with no XP reward", function()
    local ns, st = questxp.load({ rewardXP = nil })
    assert.is_nil(ns.GetRewardPercent())
    st.rewardXP = 0
    assert.is_nil(ns.GetRewardPercent())
    st.rewardXP = -5
    assert.is_nil(ns.GetRewardPercent())
  end)

  it("is nil when the level has no XP total (avoids dividing by zero)", function()
    local ns = questxp.load({ rewardXP = 100, maxXP = 0 })
    assert.is_nil(ns.GetRewardPercent())
  end)

  it("is 0 (not nil) for a real reward under half a percent", function()
    local ns = questxp.load({ rewardXP = 400, maxXP = 100000 })
    assert.equals(0, ns.GetRewardPercent())
  end)
end)

describe("ShadowsOfUI-QuestXP XP text hook", function()
  it("appends the percent in grey to the quest's XP reward text", function()
    local _, _, fs = questxp.load({ rewardXP = 25000, maxXP = 100000 })
    fs:SetText("12,345 XP")
    assert.equals("12,345 XP", fs.texts[1])
    assert.equals("12,345 XP <(25%)>", fs.texts[2])
  end)

  it("shows '<1%' for a real reward that rounds to 0, never '(0%)'", function()
    local _, _, fs = questxp.load({ rewardXP = 400, maxXP = 100000 })
    fs:SetText("400 XP")
    assert.equals("400 XP <(<1%)>", fs.texts[2])
  end)

  it("appends exactly once: its own SetText must not re-trigger the hook", function()
    local _, _, fs = questxp.load({ rewardXP = 25000, maxXP = 100000 })
    fs:SetText("1 XP")
    assert.equals(2, #fs.texts)
  end)

  it("leaves the text alone when there is nothing to show", function()
    local _, _, fs = questxp.load({ maxLevel = true, rewardXP = 25000 })
    fs:SetText("1 XP")
    assert.equals(1, #fs.texts)
  end)

  it("ignores a nil text", function()
    local _, _, fs = questxp.load({ rewardXP = 25000 })
    assert.has_no.errors(function() fs:SetText(nil) end)
    assert.equals(1, fs.calls)   -- just the caller's own SetText; the hook added none
  end)
end)
