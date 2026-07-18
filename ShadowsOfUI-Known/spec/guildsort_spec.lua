local known = require("ShadowsOfUI-Known.spec.known")

describe("ShadowsOfUI-Known ns.SortGuildCrafters", function()
  local ns
  before_each(function() ns = known.loadGuild() end)

  it("orders online crafters before offline ones", function()
    local list = ns.SortGuildCrafters({
      { name = "Zed", online = false },
      { name = "Amy", online = true },
    })
    assert.equal("Amy", list[1].name)
    assert.equal("Zed", list[2].name)
  end)

  it("breaks ties alphabetically within the same online state", function()
    local list = ns.SortGuildCrafters({
      { name = "Cara", online = true },
      { name = "Bob", online = true },
      { name = "Ada", online = true },
    })
    assert.same({ "Ada", "Bob", "Cara" }, { list[1].name, list[2].name, list[3].name })
  end)

  it("keeps every online name ahead of every offline name", function()
    local list = ns.SortGuildCrafters({
      { name = "Bob", online = false },
      { name = "Zoe", online = true },
      { name = "Ada", online = false },
      { name = "Max", online = true },
    })
    assert.same({ "Max", "Zoe", "Ada", "Bob" },
      { list[1].name, list[2].name, list[3].name, list[4].name })
  end)

  it("sorts in place and returns the same table", function()
    local input = { { name = "X", online = true } }
    assert.equal(input, ns.SortGuildCrafters(input))
  end)
end)
