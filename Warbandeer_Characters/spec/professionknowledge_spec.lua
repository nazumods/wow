local wbchar = require("Warbandeer_Characters.spec.wbchar")

-- Build an isCompleted(questID) checker from a set of "completed" quest IDs.
local function checker(...)
  local done = {}
  for _, id in ipairs({ ... }) do done[id] = true end
  return function(q) return done[q] == true end
end

-- A synthetic profession row exercising all four source kinds.
local function entry()
  return {
    treatise    = { 100 },
    weeklyQuest = { 200, 201 },   -- any-of: counts once
    treasure    = { 300, 301 },   -- counts each
    gathering   = { 400, 401, 402 },
  }
end

describe("Warbandeer_Characters ns.SummarizeProfessionKnowledge", function()
  local ns
  before_each(function() ns = wbchar.load() end)

  it("reports nothing done when no quest is flagged", function()
    local s = ns.SummarizeProfessionKnowledge(entry(), checker())
    assert.same({ done = 0, total = 1 }, s.treatise)
    assert.same({ done = 0, total = 1 }, s.weeklyQuest)
    assert.same({ done = 0, total = 2 }, s.treasure)
    assert.same({ done = 0, total = 3 }, s.gathering)
    assert.equal(0, s.done)
    assert.equal(7, s.total)
  end)

  it("treats a boolean source (treatise) as 0/1", function()
    local s = ns.SummarizeProfessionKnowledge(entry(), checker(100))
    assert.same({ done = 1, total = 1 }, s.treatise)
    assert.equal(1, s.done)
  end)

  it("counts a weekly quest as done when ANY of its any-of options is flagged, capped at 1", function()
    assert.same({ done = 1, total = 1 }, ns.SummarizeProfessionKnowledge(entry(), checker(201)).weeklyQuest)
    -- both options flagged still counts once
    assert.same({ done = 1, total = 1 }, ns.SummarizeProfessionKnowledge(entry(), checker(200, 201)).weeklyQuest)
  end)

  it("counts each completed quest for count sources (treasure/gathering)", function()
    local s = ns.SummarizeProfessionKnowledge(entry(), checker(300, 301, 400, 402))
    assert.same({ done = 2, total = 2 }, s.treasure)
    assert.same({ done = 2, total = 3 }, s.gathering)
  end)

  it("aggregates done/total across every present source", function()
    local s = ns.SummarizeProfessionKnowledge(entry(), checker(100, 201, 300, 400, 401, 402))
    -- treatise 1 + weeklyQuest 1 + treasure 1 + gathering 3
    assert.equal(6, s.done)
    assert.equal(7, s.total)
  end)

  it("omits sources the profession does not have", function()
    local s = ns.SummarizeProfessionKnowledge({ treatise = { 1 }, weeklyQuest = { 2 } }, checker(1, 2))
    assert.is_nil(s.treasure)
    assert.is_nil(s.gathering)
    assert.equal(2, s.done)
    assert.equal(2, s.total)
  end)
end)

describe("Warbandeer_Characters ns.MergeProfessionKnowledge", function()
  local ns
  before_each(function() ns = wbchar.load() end)

  it("returns the fresh summary unchanged when there is no stored value", function()
    local fresh = ns.SummarizeProfessionKnowledge(entry(), checker(100))
    assert.equal(fresh, ns.MergeProfessionKnowledge(fresh, nil))
  end)

  it("keeps the higher stored per-source done (guards a transient all-false read)", function()
    local stored = ns.SummarizeProfessionKnowledge(entry(), checker(100, 300, 301))  -- treatise + 2 treasure
    local fresh  = ns.SummarizeProfessionKnowledge(entry(), checker())               -- transient: nothing reads done
    local merged = ns.MergeProfessionKnowledge(fresh, stored)
    assert.equal(1, merged.treatise.done)
    assert.equal(2, merged.treasure.done)
    assert.equal(3, merged.done)   -- 1 treatise + 2 treasure, recomputed
    assert.equal(7, merged.total)
  end)

  it("advances to fresh progress when it exceeds the stored value", function()
    local stored = ns.SummarizeProfessionKnowledge(entry(), checker(300))            -- 1 treasure
    local fresh  = ns.SummarizeProfessionKnowledge(entry(), checker(300, 301))       -- 2 treasure
    local merged = ns.MergeProfessionKnowledge(fresh, stored)
    assert.equal(2, merged.treasure.done)
    assert.equal(2, merged.done)
  end)
end)

describe("Warbandeer_Characters ns.ProfessionKnowledge catalog integrity", function()
  local ns
  before_each(function() ns = wbchar.load() end)

  it("covers all 11 Midnight primary professions with a treatise and weekly quest", function()
    local n = 0
    for skillID, row in pairs(ns.ProfessionKnowledge) do
      n = n + 1
      assert.is_number(skillID)
      assert.is_table(row.treatise, "profession " .. skillID .. " missing treatise")
      assert.equal(1, #row.treatise, "treatise should be a single quest for " .. skillID)
      assert.is_table(row.weeklyQuest, "profession " .. skillID .. " missing weeklyQuest")
      assert.is_true(#row.weeklyQuest > 0)
    end
    assert.equal(11, n)
  end)

  it("only uses known source keys, each a non-empty list of positive integer quest IDs", function()
    local known = {}
    for _, k in ipairs(ns.ProfessionKnowledgeSources) do known[k] = true end
    for skillID, row in pairs(ns.ProfessionKnowledge) do
      for key, quests in pairs(row) do
        assert.is_true(known[key], "unknown source key '" .. key .. "' for " .. skillID)
        assert.is_true(#quests > 0)
        for _, q in ipairs(quests) do
          assert.is_number(q)
          assert.is_true(q > 0 and q == math.floor(q))
        end
      end
    end
  end)

  it("has no quest ID shared across professions or sources", function()
    local seen = {}
    for skillID, row in pairs(ns.ProfessionKnowledge) do
      for _, quests in pairs(row) do
        for _, q in ipairs(quests) do
          assert.is_nil(seen[q], "duplicate quest id " .. q .. " (also in skill " .. tostring(seen[q]) .. ")")
          seen[q] = skillID
        end
      end
    end
  end)
end)
