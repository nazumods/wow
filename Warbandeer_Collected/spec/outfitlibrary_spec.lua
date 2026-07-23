local collected = require("Warbandeer_Collected.spec.collected")

-- The outfit library (#655) — our own account-wide store, needed because the game's custom sets
-- are per-character. Pure Lua over `ns.db` plus the codec, so unlike the rest of the outfit chain
-- it can be tested without the client.

-- An outfit list with a recognisable appearance in one slot, so a round-trip can be asserted on
-- something more specific than "it came back non-nil".
---@param head number
---@return table[]
local function lookWith(ns, head)
  local list = ns.EmptyOutfitList()
  list[INVSLOT_HEAD].appearanceID = head
  return list
end

describe("outfit library", function()
  local ns
  before_each(function() ns = collected.load() end)

  describe("SaveLibraryOutfit", function()
    it("stores the look as its /customset encoding", function()
      assert.is_true(ns.SaveLibraryOutfit("mog", lookWith(ns, 7019)))
      local entry = ns.LibraryOutfit("mog")
      assert.equal("mog", entry.name)
      -- Stored as the wire string, not the table: that's what makes each entry its own export.
      assert.equal(ns.EncodeOutfit(lookWith(ns, 7019)), entry.look)
    end)

    it("round-trips the look back through LibraryOutfitList", function()
      ns.SaveLibraryOutfit("mog", lookWith(ns, 7019))
      local list = ns.LibraryOutfitList("mog")
      assert.equal(7019, list[INVSLOT_HEAD].appearanceID)
    end)

    it("replaces a same-named entry in place rather than appending", function()
      ns.SaveLibraryOutfit("a", lookWith(ns, 1))
      ns.SaveLibraryOutfit("b", lookWith(ns, 2))
      ns.SaveLibraryOutfit("a", lookWith(ns, 99))
      assert.equal(2, #ns.LibraryOutfits())
      -- Still first: re-saving must not reorder the library under the user.
      assert.equal("a", ns.LibraryOutfits()[1].name)
      assert.equal(99, ns.LibraryOutfitList("a")[INVSLOT_HEAD].appearanceID)
    end)

    it("keeps insertion order", function()
      for _, n in ipairs({ "one", "two", "three" }) do ns.SaveLibraryOutfit(n, ns.EmptyOutfitList()) end
      local names = {}
      for i, o in ipairs(ns.LibraryOutfits()) do names[i] = o.name end
      assert.same({ "one", "two", "three" }, names)
    end)

    it("rejects an empty or whitespace-only name", function()
      local ok, err = ns.SaveLibraryOutfit("", ns.EmptyOutfitList())
      assert.is_false(ok)
      assert.equal("a name is required", err)
      assert.is_false((ns.SaveLibraryOutfit("   ", ns.EmptyOutfitList())))
      assert.equal(0, #ns.LibraryOutfits())
    end)

    it("trims surrounding whitespace so ' x ' and 'x' are one entry", function()
      ns.SaveLibraryOutfit("  mog  ", lookWith(ns, 5))
      assert.equal("mog", ns.LibraryOutfits()[1].name)
      ns.SaveLibraryOutfit("mog", lookWith(ns, 6))
      assert.equal(1, #ns.LibraryOutfits())
    end)
  end)

  describe("provenance", function()
    local META = { char = "Triandra-Silvermoon", class = "DRUID", forClass = "WARRIOR", armor = "Plate" }

    it("stores the fields the caller collected", function()
      ns.SaveLibraryOutfit("mog", ns.EmptyOutfitList(), META)
      local entry = ns.LibraryOutfit("mog")
      assert.equal("Triandra-Silvermoon", entry.char)
      assert.equal("DRUID", entry.class)
      assert.equal("WARRIOR", entry.forClass)   -- the SET's class, not the saver's
      assert.equal("Plate", entry.armor)
    end)

    it("overwrites provenance when the look is replaced", function()
      -- The entry now holds a different look, so keeping the old attribution would be a lie.
      ns.SaveLibraryOutfit("mog", ns.EmptyOutfitList(), META)
      ns.SaveLibraryOutfit("mog", lookWith(ns, 7019), { char = "Other-Realm", class = "MAGE" })
      local entry = ns.LibraryOutfit("mog")
      assert.equal("Other-Realm", entry.char)
      assert.equal("MAGE", entry.class)
      assert.is_nil(entry.forClass)   -- absent in the new meta, so cleared rather than inherited
      assert.is_nil(entry.armor)
    end)

    it("saves without provenance when none is given", function()
      -- The command path and any caller that can't determine it must still work.
      assert.is_true(ns.SaveLibraryOutfit("mog", ns.EmptyOutfitList()))
      assert.is_nil(ns.LibraryOutfit("mog").char)
    end)

    it("survives a rename", function()
      ns.SaveLibraryOutfit("mog", ns.EmptyOutfitList(), META)
      ns.RenameLibraryOutfit("mog", "renamed")
      assert.equal("Triandra-Silvermoon", ns.LibraryOutfit("renamed").char)
    end)
  end)

  describe("LibraryOutfit", function()
    it("returns the entry and its index", function()
      ns.SaveLibraryOutfit("a", ns.EmptyOutfitList())
      ns.SaveLibraryOutfit("b", ns.EmptyOutfitList())
      local entry, index = ns.LibraryOutfit("b")
      assert.equal("b", entry.name)
      assert.equal(2, index)
    end)

    it("is nil for an unknown or empty name", function()
      assert.is_nil(ns.LibraryOutfit("nope"))
      assert.is_nil(ns.LibraryOutfit(""))
    end)
  end)

  describe("LibraryOutfitList", function()
    it("errors rather than returning a list for an unknown name", function()
      local list, err = ns.LibraryOutfitList("nope")
      assert.is_nil(list)
      assert.is_truthy(err:find("nope", 1, true))
    end)

    it("surfaces the decoder's error for a corrupt stored string", function()
      -- A hand-edited SavedVariables file shouldn't dress the model from half an outfit.
      ns.SaveLibraryOutfit("bad", ns.EmptyOutfitList())
      ns.LibraryOutfit("bad").look = "v1 1,2,3"
      local list, err = ns.LibraryOutfitList("bad")
      assert.is_nil(list)
      assert.is_string(err)
    end)
  end)

  describe("RenameLibraryOutfit", function()
    it("renames in place, keeping position and look", function()
      ns.SaveLibraryOutfit("a", lookWith(ns, 42))
      ns.SaveLibraryOutfit("b", ns.EmptyOutfitList())
      assert.is_true(ns.RenameLibraryOutfit("a", "renamed"))
      assert.equal("renamed", ns.LibraryOutfits()[1].name)
      assert.equal(42, ns.LibraryOutfitList("renamed")[INVSLOT_HEAD].appearanceID)
      assert.is_nil(ns.LibraryOutfit("a"))
    end)

    it("allows a look to keep its own name", function()
      -- Re-committing an untouched name field must not read as a collision.
      ns.SaveLibraryOutfit("mog", ns.EmptyOutfitList())
      assert.is_true(ns.RenameLibraryOutfit("mog", "mog"))
    end)

    it("rejects a name another look already holds", function()
      ns.SaveLibraryOutfit("a", ns.EmptyOutfitList())
      ns.SaveLibraryOutfit("b", ns.EmptyOutfitList())
      local ok, err = ns.RenameLibraryOutfit("a", "b")
      assert.is_false(ok)
      assert.is_truthy(err:find("already in the library", 1, true))
      assert.equal("a", ns.LibraryOutfits()[1].name)
    end)

    it("rejects an empty new name", function()
      ns.SaveLibraryOutfit("a", ns.EmptyOutfitList())
      local ok, err = ns.RenameLibraryOutfit("a", "  ")
      assert.is_false(ok)
      assert.equal("a name is required", err)
    end)

    it("reports an unknown source name", function()
      local ok, err = ns.RenameLibraryOutfit("nope", "x")
      assert.is_false(ok)
      assert.is_truthy(err:find("nope", 1, true))
    end)
  end)

  describe("DeleteLibraryOutfit", function()
    it("removes the entry and closes the gap", function()
      for _, n in ipairs({ "one", "two", "three" }) do ns.SaveLibraryOutfit(n, ns.EmptyOutfitList()) end
      assert.is_true(ns.DeleteLibraryOutfit("two"))
      local names = {}
      for i, o in ipairs(ns.LibraryOutfits()) do names[i] = o.name end
      assert.same({ "one", "three" }, names)
    end)

    it("is false for an unknown name", function()
      assert.is_false(ns.DeleteLibraryOutfit("nope"))
    end)
  end)

  -- The library window's filter strip (#662). Saved through the real save path so the entries
  -- carry provenance exactly as the store writes it.
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
