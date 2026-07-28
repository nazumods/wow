---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local GetInspectList = C_TransmogCollection.GetInspectItemTransmogInfoList

-- **A targeted player's look, as a `/customset v1` string** (#819) — a new PRODUCER for the
-- interchange pipeline that already existed, not a new format. The codec is outfitcodec.lua, the
-- wire-shaping rule is `ns.ShareableOutfit` (outfitshare.lua), and the receiving half —
-- uncollected sources, validation, dressing the preview — has been solved since #643.
--
-- **Why this is in-game and not a Discord round-trip.** #819 was originally framed as
-- addon → desktop → bot → Blizzard REST → chat. It needs none of that:
-- `GetInspectItemTransmogInfoList` is what Blizzard's own inspect "View" button reads
-- (`Blizzard_InspectUI/InspectPaperDollFrame.lua:197`), and it returns `ItemTransmogInfo[]` densely
-- indexed by inventory slot id — which is exactly the shape `ns.EncodeOutfit` already takes. The
-- REST route survives only for characters that CAN'T be inspected (#820): it is snapshot-on-logout,
-- so it is stale for anyone currently standing in front of you, and #556's outbox lands on logout
-- or `/reload`, meaning two reloads to answer a question the client already knows.
--
-- The one asynchronous part is the inspect handshake itself: `CanInspect` → `NotifyInspect` →
-- `INSPECT_READY` (payload `inspecteeGUID`) → read → `ClearInspectPlayer`.

---@class Warbandeer_Collected
---@field GrabTargetOutfit fun()

-- **The wait and the timeout are ONE mechanism.** `ns.Retry` (retry.lua) already caps a
-- "try again while data streams" tail, so the poll below doubles as the deadline: 20 attempts a
-- quarter-second apart is ~5s, long enough for a server round-trip and short enough that a target
-- who walked out of range is reported rather than waited on forever. `INSPECT_READY` short-circuits
-- it by polling immediately, so the normal path resolves on the event and the timer is only the
-- tail. Not `ns.delay`: LibNAddOn keeps one timer per addon, and the room's own retries run
-- alongside this while a look is being read.
local RETRY_KEY = "inspectOutfit"
local TRIES, DELAY = 20, 0.25

-- Who we asked about, and the GUID to match `INSPECT_READY` against. nil when nothing is in flight,
-- which is what every entry point below tests rather than keeping a separate "busy" flag.
local _pending

---Hand the inspect slot back, unless something else is using it.
---
---Blizzard's own `InspectFrame_OnHide` guards the same call with the same question, because
---`ClearInspectPlayer` is global state: releasing it while the inspect window (or the inspected
---talent tree) is open blanks a frame the user is reading. That is #819's "don't fight the Blizzard
---inspect frame". Both frames live in load-on-demand addons, so both may simply not exist.
local function release()
  if InspectFrame and InspectFrame:IsShown() then return end
  if PlayerSpellsFrame and PlayerSpellsFrame:IsInspecting() then return end
  ClearInspectPlayer()
end

---Turn the read list into the two surfaces, and stand down.
---
---**The list goes through `ns.ShareableOutfit` like every other outfit we put on the wire (#666).**
---A slot the target renders bare comes back as `appearanceID = 0`, and `0` means "no transmog —
---show the wearer's own gear", not "this slot is bare". Encoded as-is, a target with no cloak would
---arrive wearing the RECIPIENT's cloak. The two weapon slots have no hide visual, so a missing
---off-hand still can't be expressed — the documented limit of the format, not of this path.
---@param list table[]  as returned by GetInspectItemTransmogInfoList
local function finish(list)
  local who = _pending.who
  _pending = nil
  ns.CancelRetry(ns, RETRY_KEY)
  release()

  local shared = ns.ShareableOutfit(list, nil, ns.HideVisual)
  local str = ns.EncodeOutfit(shared)
  local title = ("%s's look"):format(who)
  -- The same body shape `DressingRoom:ExportOutfit` writes: the string first, so it is at the top of
  -- the pre-selected text, then the per-slot listing to eyeball it against.
  local body = { str, "", ns.OutfitSummary(shared) }
  -- **The note ExportOutfit carries, and here it is the NORMAL case rather than the rare one**: the
  -- target's items were never in this client's cache, so the listing comes back mostly
  -- `(name pending)` while `GetSourceInfo` streams them. Only the listing is affected — the string
  -- above it is complete either way, since an appearance id needs no item data to be an id.
  if ns.OutfitIssues(shared).pending then
    body[#body + 1] = ""
    body[#body + 1] = "NOTE: some item data is still loading — re-run to re-check."
  end
  ui.ShowCopyWindow(title, table.concat(body, "\n"))
  ns.Print(("Read %s's look — the /customset string is in the copy window."):format(who))

  -- Dressing the preview goes through the room's ordinary import path rather than applying the list
  -- directly, so there stays exactly ONE way a look enters the room from a string (#643). It also
  -- round-trips what we just handed the user through the decoder, which is a free check that the
  -- string in the copy window IS the look on the model. Nothing opens the room: a slash command that
  -- threw a window up would be doing more than it was asked.
  local room = ns.OpenDressingRoom()
  if room then room:ImportOutfit(str, title) end
end

---Try to read the inspected list, scheduling another attempt while the budget lasts.
local function poll()
  if not _pending then return end
  -- Declared `MayReturnNothing`, and an empty table is the same "not yet" as a nil one — the data
  -- streams in after the handshake, so both are ordinary states rather than failures.
  local list = GetInspectList()
  if list and next(list) then return finish(list) end
  if ns.Retry(ns, RETRY_KEY, { again = poll, tries = TRIES, delay = DELAY }) then return end

  local who = _pending.who
  _pending = nil
  release()
  ns.Print(("Never got inspect data for %s — get closer and try again."):format(who))
end

---Read the targeted player's transmog and hand it over as a `/customset v1` string.
---
---Every refusal is named. The three checked up front are the ones the client can answer instantly;
---being out of range is NOT among them (`CanInspect` doesn't test it), so it surfaces as the poll's
---timeout, which is why that message names distance.
function ns.GrabTargetOutfit()
  if not UnitExists("target") then
    ns.Print("No target — target the player whose look you want.")
    return
  end
  if not UnitIsPlayer("target") then
    ns.Print("Your target isn't a player — only players have a transmog to read.")
    return
  end
  -- No `showError`: Blizzard's second argument raises its own UI error, and this path already says
  -- what went wrong in the same voice as the rest of the command surface.
  if not CanInspect("target") then
    ns.Print(("Can't inspect %s."):format(GetUnitName("target", true) or "that target"))
    return
  end

  -- A fresh ask gets the full budget back; a previous one that timed out has spent it.
  ns.ResetRetry(ns, RETRY_KEY)
  -- `GetUnitName(unit, true)` rather than `UnitName` — it carries the realm suffix for a
  -- cross-realm player, which is the only thing that tells two same-named targets apart in chat.
  _pending = { guid = UnitGUID("target"), who = GetUnitName("target", true) }
  NotifyInspect("target")
  -- Immediately, not only on the event: the data is often already cached for someone recently
  -- inspected, and a miss here is what arms the timeout.
  poll()
end

-- Matched on the GUID, exactly as every Blizzard consumer does (`InspectFrame_OnEvent`,
-- `InspectGuildFrame`): the event fires for whoever the client last inspected, which need not be who
-- we asked about if another addon inspected someone in between.
ns:registerEvent("INSPECT_READY", function(_, inspecteeGUID)
  if _pending and inspecteeGUID == _pending.guid then poll() end
end)
