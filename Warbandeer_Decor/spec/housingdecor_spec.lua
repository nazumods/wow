local hd = require("Warbandeer_Decor.spec.loader")

describe("Warbandeer_Decor", function()
  describe("NormalizeEntry -- pure count/bonus logic", function()
    local ns
    before_each(function() ns = hd.load() end)

    it("returns nil for a nil entry", function()
      assert.is_nil(ns.NormalizeEntry(nil))
    end)

    it("treats an all-zero (or empty) entry as unowned and clean", function()
      local d = ns.NormalizeEntry({})
      assert.is_false(d.owned)
      assert.equals(0, d.stored)
      assert.equals(0, d.total)
      assert.equals(0, d.bonus)
      assert.is_false(d.bonusAvailable)
    end)

    it("sums stored + redeemable, then adds placed for the total", function()
      local d = ns.NormalizeEntry({ totalNumStored = 2, remainingRedeemable = 1, totalNumPlaced = 3 })
      assert.equals(3, d.stored)   -- 2 + 1
      assert.equals(6, d.total)    -- 3 stored + 3 placed
      assert.is_true(d.owned)
    end)

    it("counts placed-only decor as owned with zero stored", function()
      local d = ns.NormalizeEntry({ totalNumPlaced = 2 })
      assert.is_true(d.owned)
      assert.equals(0, d.stored)
      assert.equals(2, d.total)
    end)

    it("marks the first-acquisition bonus available only while unowned", function()
      local unowned = ns.NormalizeEntry({ firstAcquisitionBonus = 50 })
      assert.equals(50, unowned.bonus)
      assert.is_true(unowned.bonusAvailable)

      local owned = ns.NormalizeEntry({ firstAcquisitionBonus = 50, totalNumStored = 1 })
      assert.equals(50, owned.bonus)
      assert.is_false(owned.bonusAvailable)
    end)
  end)

  describe("DedupeVariants -- decor recordIDs in first-seen order", function()
    local ns
    before_each(function() ns = hd.load() end)

    it("returns an empty list for nil", function()
      assert.same({}, ns.DedupeVariants(nil))
    end)

    it("keeps one recordID per decor entry, dropping rooms and dupes", function()
      local variants = {
        { entryType = 1, recordID = 10 },  -- decor
        { entryType = 1, recordID = 10 },  -- dye variant of the same record
        { entryType = 2, recordID = 20 },  -- a room -- dropped
        { entryType = 1, recordID = 30 },  -- decor
        { entryType = 1, recordID = 10 },  -- decor dupe again
      }
      assert.same({ 10, 30 }, ns.DedupeVariants(variants))
    end)
  end)

  describe("wanted model -- keyed by recordID", function()
    local ns
    before_each(function() ns = hd.load() end)

    it("flags, reads, counts, and toggles", function()
      assert.is_false(ns:IsWanted(5))
      ns:SetWanted(5, true)
      assert.is_true(ns:IsWanted(5))
      assert.equals(1, ns:WantedCount())
      assert.is_false(ns:ToggleWanted(5))  -- flips off
      assert.equals(0, ns:WantedCount())
      assert.is_true(ns:ToggleWanted(5))   -- flips back on
    end)

    it("clears the key when set false (no empty-key leak)", function()
      ns:SetWanted(7, true)
      ns:SetWanted(7, false)
      assert.equals(0, ns:WantedCount())
      assert.is_nil(ns.db.wanted[7])
    end)

    it("fires ratings-changed listeners on toggle", function()
      local fired = 0
      ns:OnRatingsChanged(function() fired = fired + 1 end)
      ns:ToggleWanted(9)
      assert.equals(1, fired)
    end)
  end)

  describe("WantedListText -- the copyable wanted block", function()
    local ns
    before_each(function() ns = hd.load() end)

    -- A snapshot with an owned entry, an unowned+sourced entry, and one with no blurb.
    local ENTRIES = {
      { recordID = 10, name = "Oak Chair",   owned = true,  sourceText = "Sold by Barkeep Kelly" },
      { recordID = 20, name = "Iron Sconce", owned = false, sourceText = "Drops in Blackrock" },
      { recordID = 30, name = "Plain Rug",   owned = false },
    }
    local function wants(set) return function(id) return set[id] == true end end

    it("names each wanted row with its owned marker and source blurb", function()
      local body, named = ns.WantedListText(ENTRIES, wants({ [10] = true, [20] = true }), 2)
      assert.equals(2, named)
      assert.equals("2 wanted decor:", body:match("^[^\n]+"))
      assert.is_truthy(body:find("Oak Chair", 1, true))
      assert.is_truthy(body:find("Sold by Barkeep Kelly", 1, true))
      assert.is_truthy(body:find("Iron Sconce  (not owned)", 1, true))
      assert.is_truthy(body:find("\n    Drops in Blackrock", 1, true)) -- source indented beneath
      assert.is_nil(body:find("Oak Chair  (not owned)", 1, true))      -- owned: no marker
    end)

    it("omits the indented source line for an entry with no sourceText", function()
      local body = ns.WantedListText(ENTRIES, wants({ [30] = true }), 1)
      assert.is_truthy(body:find("Plain Rug", 1, true))
      assert.is_nil(body:find("Plain Rug\n    ", 1, true))
    end)

    it("treats an empty-string source blurb as no source (no dangling indent)", function()
      -- owned == true so the row is the bare name: a mutation dropping the `~= ""`
      -- guard would append "\n    " (an indented blank line) and trip this.
      local entries = { { recordID = 40, name = "Bare Shelf", owned = true, sourceText = "" } }
      local body = ns.WantedListText(entries, wants({ [40] = true }), 1)
      assert.is_truthy(body:find("Bare Shelf", 1, true))
      assert.is_nil(body:find("Bare Shelf\n    ", 1, true))
    end)

    it("footers the count when some wanted ids aren't in the current scan", function()
      local body, named = ns.WantedListText(ENTRIES, wants({ [10] = true }), 3)
      assert.equals(1, named)
      assert.is_truthy(body:find("3 wanted decor (2 not in the current scan", 1, true))
    end)
  end)

  describe("Scan -- the persisted collected/total tally", function()
    -- Three decor: two owned (stored / placed) and one not.
    local VARIANTS = {
      { entryType = 1, recordID = 10 },
      { entryType = 1, recordID = 20 },
      { entryType = 1, recordID = 30 },
    }
    local function stock(records)
      records[10] = { name = "Stored",   totalNumStored = 1 }
      records[20] = { name = "Unowned" }
      records[30] = { name = "Placed",   totalNumPlaced = 2 }
    end

    it("writes the fresh tally once the catalog is primed", function()
      local ns, records = hd.loadScan()
      stock(records)
      hd.prime(ns, VARIANTS)

      ns:Scan()
      assert.equals(3, #ns._entries)
      assert.equals(2, ns.db.collected)
      assert.equals(3, ns.db.total)
    end)

    it("keeps the last good tally when the catalog hasn't primed yet", function()
      -- A cold session: the searcher is nil until onLogin creates it, so the first
      -- scans read nothing. That must not be reported as "you own nothing".
      local ns = hd.loadScan({ wanted = {}, collected = 120, total = 400 })

      ns:Scan()
      assert.same({}, ns._entries)
      assert.equals(120, ns.db.collected)
      assert.equals(400, ns.db.total)
    end)

    it("keeps the tally when a later scan reads an empty catalog", function()
      local ns, records = hd.loadScan()
      stock(records)
      hd.prime(ns, VARIANTS)
      ns:Scan()

      ns._searcher = nil   -- the catalog drops out from under a later scan
      ns:Scan()
      assert.same({}, ns._entries)   -- the live snapshot still clears (IsScanned depends on it)
      assert.equals(2, ns.db.collected)
      assert.equals(3, ns.db.total)
    end)
  end)
end)
