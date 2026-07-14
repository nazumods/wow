-- Unit tests for missing.lua's report WALKER, loaded against a synthetic namespace + broker
-- set (no WoW, no LibNAddOn). These lock the ENGINE: opt-out (`missing = false`) vs. default
-- nil-check vs. custom `check`, the undeclared-field auto-flag + audit, the explicit-order
-- sort, maxLevel gating, string/list flattening, provider interleaving, and getMissingReport's
-- current-character pinning. The individual ported descriptors call live WoW APIs, so their
-- equivalence to the old hand-written checks is verified in-game, not here.

-- A synthetic namespace with just enough surface for missing.lua to load and the walker to
-- run: the broker registry the walker iterates, the provider registry ns:RegisterMissing
-- appends to, ns.wow.maxLevel (the level-cap gate) and a db for getMissingReport. Loading
-- missing.lua also registers its own bars provider (order 50) — WarbandeerBarsApi is absent,
-- so it always evaluates to nil and never affects these assertions.
local function newNS(maxLevel)
  local ns = {
    brokers = {}, brokerOrder = {}, missingProviders = {},
    wow = { maxLevel = maxLevel or 80 },
    db = { characters = {} },
  }
  function ns:RegisterMissing(p) table.insert(self.missingProviders, p) end
  function ns:registerCommand() end
  ns.Print = function() end
  _G.C_Timer = { After = function() end } -- missing.lua schedules a load-time audit nudge
  assert(loadfile("Warbandeer_Characters/missing.lua"))("Warbandeer_Characters", ns)
  return ns
end

-- Register a broker the way ns:RegisterBroker + a data file would: a name in brokerOrder and a
-- fields table whose entries may carry a `missing` declaration. Fields are added AFTER load
-- because the walker builds its entry list lazily on the first getMissingFields call.
local function addBroker(ns, name, fields)
  ns.brokers[name] = { name = name, fields = fields }
  table.insert(ns.brokerOrder, name)
end

describe("Warbandeer_Characters missing walker", function()
  it("flags a default descriptor only when the stored value is nil", function()
    local ns = newNS()
    addBroker(ns, "currency", { gold = { missing = { label = "gold", order = 10 } } })
    -- 0 is a real value (not nil) so it is NOT missing
    assert.same({}, ns.getMissingFields({ basic = { level = 80 }, currency = { gold = 0 } }))
    -- captured broker table but no gold key -> missing
    assert.same({ "gold" }, ns.getMissingFields({ basic = { level = 80 }, currency = {} }))
    -- broker never initialised for this character -> missing
    assert.same({ "gold" }, ns.getMissingFields({ basic = { level = 80 } }))
  end)

  it("never flags an opt-out (missing = false) field, and it is not undeclared", function()
    local ns = newNS()
    addBroker(ns, "b", {
      x = { missing = false },
      y = { missing = { label = "y", order = 1 } },
    })
    assert.same({ "y" }, ns.getMissingFields({ basic = { level = 80 } }))
    assert.same({}, ns:AuditMissing())
  end)

  it("auto-flags an undeclared field by name and reports it from AuditMissing", function()
    local ns = newNS()
    addBroker(ns, "b", { y = { get = function() end } }) -- no `missing` key at all
    assert.same({ "y" }, ns.getMissingFields({ basic = { level = 80 } }))
    assert.same({ "b.y" }, ns:AuditMissing())
    -- once the value is present it is no longer flagged
    assert.same({}, ns.getMissingFields({ basic = { level = 80 }, b = { y = 1 } }))
  end)

  it("only applies a maxLevel descriptor at the level cap", function()
    local ns = newNS(80)
    addBroker(ns, "b", { cap = { missing = { label = "cap thing", maxLevel = true, order = 5 } } })
    assert.same({ "cap thing" }, ns.getMissingFields({ basic = { level = 80 }, b = {} }))
    assert.same({}, ns.getMissingFields({ basic = { level = 70 }, b = {} }))
    -- no basic table at all -> treated as below cap, skipped
    assert.same({}, ns.getMissingFields({ b = {} }))
  end)

  it("runs a custom check and flattens a returned list, in order", function()
    local ns = newNS()
    addBroker(ns, "b", {
      list = { missing = { order = 1, check = function() return { "a", "b" } end } },
      one  = { missing = { order = 2, check = function() return "c" end } },
      none = { missing = { order = 3, check = function() return nil end } },
    })
    assert.same({ "a", "b", "c" }, ns.getMissingFields({ basic = { level = 80 } }))
  end)

  it("accepts a bare-function `missing` shorthand", function()
    local ns = newNS()
    addBroker(ns, "b", { z = { missing = function() return "shorthand" end } })
    assert.same({ "shorthand" }, ns.getMissingFields({ basic = { level = 80 } }))
  end)

  it("orders labels by explicit `order`, interleaving providers with fields", function()
    local ns = newNS()
    addBroker(ns, "b", { thirty = { missing = { label = "thirty", order = 30 } } })
    ns:RegisterMissing{ order = 10, check = function() return "ten" end }
    ns:RegisterMissing{ order = 20, check = function() return "twenty" end }
    assert.same({ "ten", "twenty", "thirty" },
      ns.getMissingFields({ basic = { level = 80 }, b = {} }))
  end)

  it("pins the current character to the top and sorts the rest alphabetically", function()
    local ns = newNS()
    ns.currentPlayer = "Zed"
    addBroker(ns, "b", { g = { missing = { label = "g", order = 1 } } })
    ns.db.characters = {
      Abe = { name = "Abe", basic = { level = 80 } },
      Zed = { name = "Zed", basic = { level = 80 } },
      Moe = { name = "Moe", basic = { level = 80 } },
    }
    local report = ns:getMissingReport()
    assert.same({ "Zed - missing g", "Abe - missing g", "Moe - missing g" }, report)
  end)

  it("omits a character with complete data from the report", function()
    local ns = newNS()
    ns.currentPlayer = "Zed"
    addBroker(ns, "b", { g = { missing = { label = "g", order = 1 } } })
    ns.db.characters = {
      Zed = { name = "Zed", basic = { level = 80 } },        -- missing g
      Abe = { name = "Abe", basic = { level = 80 }, b = { g = 1 } }, -- complete
    }
    assert.same({ "Zed - missing g" }, ns:getMissingReport())
  end)
end)
