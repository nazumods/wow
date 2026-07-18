local po = require("ShadowsOfUI-PostOffice.spec.postoffice")

describe("ShadowsOfUI-PostOffice doNotWant", function()
  describe("ResolveDeleteIndex -- which letter a confirmed delete removes", function()
    local ns
    before_each(function() ns = po.load() end)

    -- An inbox is modelled as an array of opaque fingerprint strings (indices 1..#list);
    -- repeated strings model letters that share a fingerprint (identical AH expiries, etc).
    local function fpFrom(list)
      return function(i) return list[i] end, #list
    end

    it("deletes exactly the clicked index when the fingerprint is unique", function()
      local at, n = fpFrom({ "a", "b", "c" })
      assert.equals(2, ns.ResolveDeleteIndex("b", 2, n, at))
    end)

    it("deletes the clicked letter, not a lower-indexed twin, when fingerprints collide", function()
      -- indices 1 and 3 both carry fingerprint "cloth"; the user clicked index 3. The old
      -- first-match scan destroyed index 1 (the regression); the captured index fixes that.
      local at, n = fpFrom({ "cloth", "gold", "cloth" })
      assert.equals(3, ns.ResolveDeleteIndex("cloth", 3, n, at))
    end)

    it("deletes the clicked letter, not a higher-indexed twin, when fingerprints collide", function()
      local at, n = fpFrom({ "cloth", "gold", "cloth" })
      assert.equals(1, ns.ResolveDeleteIndex("cloth", 1, n, at))
    end)

    it("falls back to the first fingerprint match when the captured index has shifted", function()
      -- Mail arrived at the front mid-confirm: the clicked "cloth" that was at index 3 is now at
      -- index 4, and the captured index 3 holds a different letter ("gold") -- so the direct hit
      -- misses and the scan re-resolves to the first surviving "cloth".
      local at, n = fpFrom({ "new", "cloth", "gold", "cloth" })
      assert.equals(2, ns.ResolveDeleteIndex("cloth", 3, n, at))
    end)

    it("ignores a captured index that now points past a shrunk inbox", function()
      -- The inbox shrank to one letter; the captured index 3 is out of range, so we scan.
      local at, n = fpFrom({ "cloth" })
      assert.equals(1, ns.ResolveDeleteIndex("cloth", 3, n, at))
    end)

    it("returns nil (deletes nothing) when the letter is gone and nothing shares its fingerprint", function()
      local at, n = fpFrom({ "x", "y", "z" })
      assert.is_nil(ns.ResolveDeleteIndex("cloth", 2, n, at))
    end)

    it("scans from index 1 when no index was captured", function()
      local at, n = fpFrom({ "a", "cloth", "cloth" })
      assert.equals(2, ns.ResolveDeleteIndex("cloth", nil, n, at))
    end)
  end)
end)
