local collected = require("Warbandeer_Collected.spec.collected")

-- The library window's filter strip (#662) — the rule that decides which saved looks a set of
-- facets shows. Split out of outfitlibrary_spec.lua alongside the module itself, which left the
-- store file when it gained the change notification (#727).

-- An outfit list with a recognisable appearance in one slot, so the entries a filter is run over
-- are distinguishable from each other.
---@param head number
---@return table[]
local function lookWith(ns, head)
  local list = ns.EmptyOutfitList()
  list[INVSLOT_HEAD].appearanceID = head
  return list
end

describe("outfit filtering", function()
  -- Seeded through the real save path so the entries carry provenance exactly as the store writes
  -- it.
  describe("FilterOutfits", function()
    ---@return table ns
    local function seeded()
      local n = collected.load()
      n.SaveLibraryOutfit("Rootwarden", lookWith(n, 1),
        { char = "Triandra-Silvermoon", class = "DRUID", forClass = "DRUID", armor = "Leather" })
      n.SaveLibraryOutfit("Bladedancer", lookWith(n, 2),
        { char = "Keshan-Silvermoon", class = "ROGUE", forClass = "ROGUE", armor = "Leather" })
      n.SaveLibraryOutfit("Ironhold", lookWith(n, 3),
        { char = "Triandra-Silvermoon", class = "DRUID", forClass = "WARRIOR", armor = "Plate" })
      n.SaveLibraryOutfit("Weapons only", lookWith(n, 4),
        { char = "Keshan-Silvermoon", class = "ROGUE", forClass = "ROGUE", armor = "Any" })
      -- The pre-#655 entry: saved before provenance existed, so every field but the name is nil.
      n.SaveLibraryOutfit("Ancient", lookWith(n, 5))
      return n
    end

    ---@param list table[]
    ---@return string[]
    local function names(list)
      local out = {}
      for i, o in ipairs(list) do out[i] = o.name end
      return out
    end

    ---@param n table
    ---@param filter table?
    ---@return string[]
    local function filtered(n, filter)
      return names(n.FilterOutfits(n.LibraryOutfits(), filter))
    end

    it("returns everything for no filter at all", function()
      local n = seeded()
      assert.equal(5, #n.FilterOutfits(n.LibraryOutfits()))
      assert.equal(5, #n.FilterOutfits(n.LibraryOutfits(), {}))
    end)

    -- The reported use case: one leather look wanted on a rogue, a druid AND a demon hunter.
    -- Class would scatter those three; armour is what groups them.
    it("filters by armour type", function()
      assert.same({ "Rootwarden", "Bladedancer", "Weapons only", "Ancient" },
        filtered(seeded(), { armor = "Leather" }))
    end)

    it("treats \"Any\" as no armour filter at all", function()
      assert.equal(5, #seeded().FilterOutfits(seeded().LibraryOutfits(), { armor = "Any" }))
    end)

    it("filters by class, keying on forClass rather than the saver's class", function()
      -- "Ironhold" is a WARRIOR look saved by a DRUID: it belongs to the Warrior filter, and the
      -- Druid filter must not claim it just because a Druid saved it.
      assert.same({ "Ironhold", "Ancient" }, filtered(seeded(), { class = "WARRIOR" }))
      assert.same({ "Rootwarden", "Ancient" }, filtered(seeded(), { class = "DRUID" }))
    end)

    it("searches the look's name", function()
      assert.same({ "Rootwarden" }, filtered(seeded(), { search = "root" }))
    end)

    it("searches the saving character's name", function()
      assert.same({ "Bladedancer", "Weapons only" }, filtered(seeded(), { search = "keshan" }))
    end)

    it("searches case-insensitively and ignores surrounding whitespace", function()
      assert.same({ "Rootwarden" }, filtered(seeded(), { search = "  ROOTWARD  " }))
    end)

    it("treats an all-whitespace search as no search", function()
      assert.equal(5, #seeded().FilterOutfits(seeded().LibraryOutfits(), { search = "   " }))
    end)

    -- A name or term with pattern punctuation must match literally, not as a Lua pattern.
    it("matches a search term literally rather than as a pattern", function()
      local n = collected.load()
      n.SaveLibraryOutfit("100% plate", lookWith(n, 1))
      n.SaveLibraryOutfit("all plate", lookWith(n, 2))
      assert.same({ "100% plate" }, filtered(n, { search = "100%" }))
    end)

    it("composes the dimensions", function()
      assert.same({ "Rootwarden", "Ancient" },
        filtered(seeded(), { armor = "Leather", class = "DRUID" }))
      assert.same({ "Bladedancer" },
        filtered(seeded(), { armor = "Leather", class = "ROGUE", search = "blade" }))
    end)

    it("returns empty when nothing matches", function()
      assert.same({}, filtered(seeded(), { search = "nothing by this name" }))
    end)

    -- The criterion that matters most (#662): a filter that hid un-attributed looks would make
    -- everything saved before #655 disappear from the only list that shows it.
    it("never filters out an entry that predates provenance", function()
      local n = seeded()
      for _, filter in ipairs({
        { armor = "Cloth" }, { armor = "Leather" }, { armor = "Mail" }, { armor = "Plate" },
        { class = "WARRIOR" }, { class = "PRIEST" },
        { armor = "Plate", class = "PALADIN" },
      }) do
        local found = false
        for _, o in ipairs(n.FilterOutfits(n.LibraryOutfits(), filter)) do
          if o.name == "Ancient" then found = true end
        end
        assert.is_true(found, "an entry with no provenance must survive every facet filter")
      end
    end)

    -- …but search is a positive query, not a facet: a look with no character recorded genuinely
    -- doesn't match a character search, and pretending otherwise would make that search useless.
    it("does not make a provenance-less entry match every search term", function()
      -- Every entry with a character recorded, and pointedly not "Ancient", which has none.
      assert.same({ "Rootwarden", "Bladedancer", "Ironhold", "Weapons only" },
        filtered(seeded(), { search = "silvermoon" }))
    end)

    it("returns the stored entries themselves, not copies", function()
      local n = seeded()
      assert.equal(n.LibraryOutfit("Rootwarden"), n.FilterOutfits(n.LibraryOutfits(), { search = "root" })[1])
    end)
  end)

  describe("LibraryFacets", function()
    it("names each forClass present exactly once, sorted", function()
      local n = collected.load()
      n.SaveLibraryOutfit("a", lookWith(n, 1), { forClass = "WARRIOR" })
      n.SaveLibraryOutfit("b", lookWith(n, 2), { forClass = "DRUID" })
      n.SaveLibraryOutfit("c", lookWith(n, 3), { forClass = "WARRIOR" })
      assert.same({ "DRUID", "WARRIOR" }, n.LibraryFacets(n.LibraryOutfits()))
    end)

    -- An entry with no forClass is unknown, not a class of its own — and it passes every class
    -- filter anyway, so it needs no option in the dropdown.
    it("ignores entries with no forClass", function()
      local n = collected.load()
      n.SaveLibraryOutfit("a", lookWith(n, 1), { forClass = "MAGE" })
      n.SaveLibraryOutfit("b", lookWith(n, 2))
      assert.same({ "MAGE" }, n.LibraryFacets(n.LibraryOutfits()))
    end)

    it("is empty for an empty library", function()
      assert.same({}, collected.load().LibraryFacets({}))
    end)
  end)
end)
