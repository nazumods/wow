local quests = require("ShadowsOfUI-Quests.spec.quests")

describe("ShadowsOfUI-Quests AppendQuestStatus", function()
  local function run(status, current)
    local ns = quests.load({ status = status, current = current })
    local tip = quests.tooltip()
    local appended = ns.AppendQuestStatus(tip, 1)
    return appended, tip.lines
  end

  it("adds nothing when no character is tracked on the quest", function()
    local appended, lines = run(nil, "Me")
    assert.is_false(appended)
    assert.same({}, lines)
  end)

  it("lists other characters on and done with the quest, one line each", function()
    local appended, lines = run({
      active = { { name = "Amy", classKey = "Mage" }, { name = "Bob", classKey = "Mage" } },
      completed = { { name = "Cat", classKey = "Mage" } },
    }, "Me")
    assert.is_true(appended)
    assert.same({ "Also on this quest: Amy, Bob", "Completed by: Cat" }, lines)
  end)

  it("never lists the current character (you already know your own status)", function()
    local _, lines = run({
      active = { { name = "Me", classKey = "Mage" }, { name = "Amy", classKey = "Mage" } },
      completed = { { name = "Me", classKey = "Mage" }, { name = "Cat", classKey = "Mage" } },
    }, "Me")
    assert.same({ "Also on this quest: Amy", "Completed by: Cat" }, lines)
  end)

  it("when only the current character is on it, there is nothing to say", function()
    local appended, lines = run({ active = { { name = "Me", classKey = "Mage" } }, completed = {} }, "Me")
    assert.is_false(appended)
    assert.same({}, lines)
  end)

  it("omits a block whose list is empty after self-exclusion", function()
    local _, lines = run({
      active = { { name = "Me", classKey = "Mage" } },
      completed = { { name = "Cat", classKey = "Mage" } },
    }, "Me")
    assert.same({ "Completed by: Cat" }, lines)
  end)

  it("shows six names in full", function()
    local _, lines = run({ active = quests.entries("A", 6), completed = {} }, "Me")
    assert.equals("Also on this quest: A1, A2, A3, A4, A5, A6", lines[1])
  end)

  it("collapses past six into '+N more'", function()
    local _, lines = run({ active = quests.entries("A", 9), completed = {} }, "Me")
    assert.equals("Also on this quest: A1, A2, A3, A4, A5, A6, +3 more", lines[1])
  end)

  it("the cap counts others only: the current character does not use up a slot or the tally", function()
    local active = quests.entries("A", 7)
    table.insert(active, 3, { name = "Me", classKey = "Mage" })
    local _, lines = run({ active = active, completed = {} }, "Me")
    assert.equals("Also on this quest: A1, A2, A3, A4, A5, A6, +1 more", lines[1])
  end)

  it("caps each list independently", function()
    local _, lines = run({ active = quests.entries("A", 8), completed = quests.entries("C", 7) }, "Me")
    assert.is_truthy(lines[1]:find("+2 more", 1, true))
    assert.is_truthy(lines[2]:find("+1 more", 1, true))
  end)
end)
