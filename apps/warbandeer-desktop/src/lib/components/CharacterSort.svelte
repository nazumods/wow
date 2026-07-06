<script lang="ts">
  // Reorders the WoW character-select list by editing character-list-order.txt while
  // WoW is closed — ported from the standalone WarbandeerCharacterSort app (see its
  // MainViewModel.cs for the reference flow this mirrors).
  import type { ResolvedCharacter, OrderLine } from "../types";
  import {
    listOrderAccounts,
    getCharacterOrder,
    saveCharacterOrder,
    getRememberedOrder,
    rememberCharacterOrder,
  } from "../api";
  import {
    applySort,
    applyRememberedOrder,
    applyLocked,
    assignPositions,
    gapRanksFromOrder,
    isAmbiguous,
    professionPrimaryMap,
    rememberPrimary,
    validPrimaryFor,
    type SortMode,
  } from "../sort";
  import { classColor, ilvlColor } from "../theme";
  import ProfessionChoiceDialog from "./ProfessionChoiceDialog.svelte";

  const SORT_LABELS: Record<SortMode, string> = {
    alphaAsc: "Name A-Z",
    alphaDesc: "Name Z-A",
    levelDesc: "Level (high-low)",
    levelAsc: "Level (low-high)",
    ilvlDesc: "iLvl (high-low)",
    ilvlAsc: "iLvl (low-high)",
    classRole: "Class",
    profession: "Profession",
    memory: "Remembered Order",
  };

  let accounts = $state<string[]>([]);
  let selectedAccount = $state<string | null>(null);
  let characters = $state<ResolvedCharacter[]>([]);
  let unresolvedCount = $state(0);
  let dbVersion = $state<number | null>(null);
  let activeSortMode = $state<SortMode | null>(null);
  let statusMessage = $state("Pick an account to begin.");
  let error = $state<string | null>(null);
  let loading = $state(false);
  let saving = $state(false);
  let confirmingSave = $state(false);
  let hasLoaded = $state(false);

  // Dialog state: characters currently being asked about, and what to do once answered.
  let dialogItems = $state<ResolvedCharacter[] | null>(null);
  let dialogMode = $state<"sort" | "edit">("sort");
  let pendingSortMode = $state<SortMode | null>(null);

  // The account's remembered order, if one's been saved — null means nothing to preview yet.
  let rememberedOrder = $state<OrderLine[] | null>(null);

  // realmGuid set of characters pinned to their current slot — sorts skip over them.
  // Reassigned wholesale on every toggle rather than mutated in place, for the same
  // reactivity-certainty reason as ProfessionChoiceDialog's `picks`.
  let lockedGuids = $state<Set<string>>(new Set());

  function toggleLock(realmGuid: string) {
    const next = new Set(lockedGuids);
    if (next.has(realmGuid)) next.delete(realmGuid);
    else next.add(realmGuid);
    lockedGuids = next;
  }

  // Ranks ("this many characters precede it") of every empty-slot row currently shown —
  // seeded once at load from the file's real gaps and otherwise left alone by lock/unlock
  // toggles or manual moves, exactly like a character's presence in `characters` doesn't
  // depend on whether it's locked. Only collapses to locked-only at the moment a sort (or
  // Remembered Order) actually runs — the same moment unlocked characters get resorted.
  let gaps = $state<Set<number>>(new Set());

  // Subset of `gaps` the user has locked: these survive a sort and get written to disk as
  // a deliberate vacancy; everything else in `gaps` is just "currently shown" and will be
  // squeezed out the next time a sort runs.
  let lockedGapRanks = $state<Set<number>>(new Set());

  function toggleGapLock(rank: number) {
    const next = new Set(lockedGapRanks);
    if (next.has(rank)) next.delete(rank);
    else next.add(rank);
    lockedGapRanks = next;
  }

  /** One representative rank per contiguous run of missing raw slot numbers. A multi-wide
   * gap (two+ consecutive deleted characters) collapses to a single shown row — a known
   * simplification, since a rank can only reserve one number. */
  function naturalGapRanks(sortedCharacters: readonly ResolvedCharacter[]): Set<number> {
    const ranks = new Set<number>();
    let prevSlot = 0;
    sortedCharacters.forEach((c, i) => {
      if (c.position > prevSlot + 1) ranks.add(i);
      prevSlot = c.position;
    });
    return ranks;
  }

  // `insertBefore` is this row's target rank if something is dropped on it — for a
  // character row that's how many characters precede it (== its index); for an empty-slot
  // row it's the same count. `slot` is the number shown in the Slot # column, always the
  // prospective one Save to WoW would actually write.
  type DisplayRow =
    | { kind: "character"; c: ResolvedCharacter; insertBefore: number; slot: number }
    | { kind: "empty"; slot: number; insertBefore: number; locked: boolean };

  let displayRows = $derived.by((): DisplayRow[] => {
    const assigned = assignPositions(characters, gaps);
    const rows: DisplayRow[] = [];
    let count = 0;
    for (const slot of assigned) {
      if (slot.c) {
        rows.push({ kind: "character", c: slot.c, insertBefore: count, slot: slot.position });
        count++;
      } else {
        rows.push({ kind: "empty", slot: slot.position, insertBefore: count, locked: lockedGapRanks.has(count) });
      }
    }
    return rows;
  });

  type EmptyRow = Extract<DisplayRow, { kind: "empty" }>;

  // Drag-and-drop reorder — a plain variable, not $state, since it's only read/written
  // synchronously within a single drag gesture; no reactive UI depends on its value
  // between dragstart and drop.
  let dragging: { kind: "character"; guid: string } | EmptyRow | null = null;

  function dragStartCharacter(guid: string) {
    dragging = { kind: "character", guid };
  }

  function dragStartEmpty(row: EmptyRow) {
    dragging = row;
  }

  function dropOn(row: DisplayRow) {
    const d = dragging;
    dragging = null;
    if (!d) return;

    if (d.kind === "character") {
      const fromIndex = characters.findIndex((c) => c.realmGuid === d.guid);
      if (fromIndex === -1) return;

      const copy = [...characters];
      const [item] = copy.splice(fromIndex, 1);
      // Removing the item shifts everything after it left by one, so a target past the
      // removal point needs the same adjustment before inserting.
      const target = row.insertBefore > fromIndex ? row.insertBefore - 1 : row.insertBefore;
      copy.splice(target, 0, item);
      characters = copy;
      activeSortMode = null; // manual reorder — no sort button describes the list anymore
      return;
    }

    moveGapTo(d.insertBefore, row);
  }

  /** Moves a gap's rank to land at `target` — ranks are plain 0..N reservation slots, not
   * array indices, so no splice-style shift adjustment is needed like a character move.
   * Dropping "onto" a row means landing just before it (matching character drag-drop),
   * *except* when the target is the character immediately after the gap — that character
   * shares the gap's own current rank, so using it as-is would be a no-op; land after that
   * character instead so the drop still does something. Keeps `lockedGapRanks` in sync if
   * the moved gap was locked. */
  function moveGapTo(fromRank: number, target: DisplayRow) {
    const toRank =
      target.insertBefore === fromRank && target.kind === "character"
        ? target.insertBefore + 1
        : target.insertBefore;
    if (fromRank === toRank) return;
    const wasLocked = lockedGapRanks.has(fromRank);

    const nextGaps = new Set(gaps);
    nextGaps.delete(fromRank);
    nextGaps.add(toRank);
    gaps = nextGaps;

    if (wasLocked) {
      const nextLocked = new Set(lockedGapRanks);
      nextLocked.delete(fromRank);
      nextLocked.add(toRank);
      lockedGapRanks = nextLocked;
    }
    statusMessage = "Moved the empty slot.";
  }

  async function loadAccounts() {
    loading = true;
    error = null;
    try {
      accounts = await listOrderAccounts();
      if (accounts.length === 0) {
        statusMessage = "No WoW account found. Set WOW_DIR if your install is elsewhere.";
      } else {
        selectedAccount ??= accounts[0];
        await loadAccount();
      }
    } catch (e) {
      error = String(e);
    } finally {
      loading = false;
    }
  }

  async function loadAccount() {
    if (!selectedAccount) return;
    loading = true;
    error = null;
    try {
      const payload = await getCharacterOrder(selectedAccount);
      characters = [...payload.characters].sort((a, b) => a.position - b.position);
      unresolvedCount = payload.unresolvedCount;
      dbVersion = payload.dbVersion;
      rememberedOrder = await getRememberedOrder(selectedAccount);
      lockedGuids = new Set();
      lockedGapRanks = new Set();
      gaps = naturalGapRanks(characters);
      hasLoaded = true;
      activeSortMode = null; // freshly-loaded file order, not one of our sorts
      statusMessage =
        unresolvedCount === 0
          ? `Loaded ${characters.length} characters for ${selectedAccount}.`
          : `Loaded ${characters.length} characters for ${selectedAccount} ` +
            `(${unresolvedCount} not yet in Warbandeer's data — they'll need a login before they can be identified).`;
    } catch (e) {
      error = String(e);
    } finally {
      loading = false;
    }
  }

  // Name and Level each collapse their two directions into one toggle button: a click
  // applies `first`, clicking again while already on it flips to `second` (and back).
  function toggleSort(first: SortMode, second: SortMode) {
    sortBy(activeSortMode === first ? second : first);
  }

  const isNameSort = $derived(activeSortMode === "alphaAsc" || activeSortMode === "alphaDesc");
  const isLevelSort = $derived(activeSortMode === "levelDesc" || activeSortMode === "levelAsc");
  const isIlvlSort = $derived(activeSortMode === "ilvlDesc" || activeSortMode === "ilvlAsc");
  // Label names the currently-applied direction once active (so it matches the status line
  // and the actual order); while inactive it shows the default the first click applies.
  // Clicking an already-active toggle flips to the other direction.
  const nameLabel = $derived(activeSortMode === "alphaDesc" ? "Name Z–A" : "Name A–Z");
  const levelLabel = $derived(activeSortMode === "levelAsc" ? "Level low–high" : "Level high–low");
  const ilvlLabel = $derived(activeSortMode === "ilvlAsc" ? "iLvl low–high" : "iLvl high–low");

  function performSort(mode: SortMode) {
    const map = professionPrimaryMap(characters);
    characters = applyLocked(characters, lockedGuids, (unlocked) => applySort(unlocked, mode, map));
    gaps = new Set(lockedGapRanks); // a sort squeezes out any gap that isn't locked
    activeSortMode = mode;
    const lockedNote = lockedGuids.size > 0 ? ` (${lockedGuids.size} locked in place)` : "";
    statusMessage = `Previewing "${SORT_LABELS[mode]}" order${lockedNote} — click "Save to WoW" to write it, or pick another sort.`;
  }

  function sortBy(mode: SortMode) {
    if (mode === "memory") {
      const remembered = rememberedOrder;
      if (!remembered) return;
      characters = applyLocked(characters, lockedGuids, (unlocked) =>
        applyRememberedOrder(unlocked, remembered),
      );
      // Restore the empty slots the order was remembered with — locked, so they persist
      // through later sorts and get written back on Save to WoW just as they were saved.
      const restoredGaps = gapRanksFromOrder(remembered);
      gaps = new Set(restoredGaps);
      lockedGapRanks = new Set(restoredGaps);
      activeSortMode = mode;
      statusMessage = `Previewing your remembered order — click "Save to WoW" to write it.`;
      return;
    }
    if (mode === "profession") {
      const needsChoice = characters
        .filter((c) => !lockedGuids.has(c.realmGuid))
        .filter(isAmbiguous)
        .filter((c) => validPrimaryFor(c.realmGuid, c.profession1, c.profession2) === undefined);
      if (needsChoice.length > 0) {
        dialogItems = needsChoice;
        dialogMode = "sort";
        pendingSortMode = mode;
        return;
      }
    }
    performSort(mode);
  }

  /** Snapshots whatever order is currently shown (a preview or a manual reorder) as the
   * account's remembered order — stays until this is called again. */
  async function rememberOrder() {
    if (!selectedAccount) return;
    try {
      // Snapshot the same gap-aware numbering Save to WoW would write, so a locked empty
      // slot is recorded in the memory file as a real skipped number.
      const ordered: OrderLine[] = currentOrderLines();
      await rememberCharacterOrder(selectedAccount, ordered);
      rememberedOrder = ordered;
      statusMessage = "Remembered this order — it stays as an option until you remember a new one.";
    } catch (e) {
      error = String(e);
    }
  }

  /** The current layout as order-file lines, with every *shown* empty slot recorded as a
   * skipped position number — what-you-see-is-what-you-write. Shared by Remember this order
   * and Save to WoW so both agree. Uses `gaps` (all displayed blanks), not `lockedGapRanks`:
   * locking only governs whether a blank survives a *sort*, not whether it's written. */
  function currentOrderLines(): OrderLine[] {
    return assignPositions(characters, gaps)
      .filter((slot) => slot.c !== null)
      .map((slot) => ({ flag: slot.c!.flag, realmGuid: slot.c!.realmGuid, position: slot.position }));
  }

  function editProfessionChoices() {
    const ambiguous = characters.filter(isAmbiguous);
    if (ambiguous.length === 0) {
      statusMessage = "No characters with two crafting professions to choose for.";
      return;
    }
    dialogItems = ambiguous;
    dialogMode = "edit";
  }

  function onDialogConfirm(choices: Map<string, string>) {
    for (const [realmGuid, primary] of choices) {
      const c = characters.find((c) => c.realmGuid === realmGuid);
      if (c) rememberPrimary(realmGuid, c.profession1, c.profession2, primary);
    }
    dialogItems = null;
    if (dialogMode === "sort" && pendingSortMode) {
      performSort(pendingSortMode);
    } else if (dialogMode === "edit") {
      performSort("profession");
    }
    pendingSortMode = null;
  }

  function onDialogCancel() {
    dialogItems = null;
    pendingSortMode = null;
  }

  function move(c: ResolvedCharacter, delta: number) {
    const index = characters.indexOf(c);
    const newIndex = index + delta;
    if (index < 0 || newIndex < 0 || newIndex >= characters.length) return;
    const copy = [...characters];
    const [item] = copy.splice(index, 1);
    copy.splice(newIndex, 0, item);
    characters = copy;
    activeSortMode = null; // manual reorder — no sort button describes the list anymore
  }

  async function save() {
    if (!selectedAccount) return;
    confirmingSave = false;
    saving = true;
    error = null;
    try {
      const backupPath = await saveCharacterOrder(selectedAccount, currentOrderLines());
      statusMessage = `Saved. Backup written to ${backupPath}. Restart WoW (or go to character select) to see the new order.`;
    } catch (e) {
      error = String(e);
    } finally {
      saving = false;
    }
  }

  loadAccounts();
</script>

<div class="sort">
  <div class="toolbar">
    <label class="account-picker">
      <span class="caps">Account</span>
      <select bind:value={selectedAccount} onchange={loadAccount} disabled={loading}>
        {#each accounts as a (a)}
          <option value={a}>{a}</option>
        {/each}
      </select>
    </label>

    <div class="sort-buttons">
      {#if rememberedOrder}
        <button class:active={activeSortMode === "memory"} onclick={() => sortBy("memory")}>
          {SORT_LABELS.memory}
        </button>
      {/if}
      <button
        onclick={rememberOrder}
        disabled={characters.length === 0}
        title="Save the order currently shown as a persistent option, replacing any previously remembered order"
      >
        Remember this order
      </button>
    </div>

    {#if confirmingSave}
      <div class="confirm-bar">
        <span>Overwrite character-list-order.txt for "{selectedAccount}"? A backup is made first.</span>
        <button class="secondary" onclick={() => (confirmingSave = false)}>Cancel</button>
        <button class="primary" onclick={save} disabled={saving}>Yes, save</button>
      </div>
    {:else}
      <button
        class="save primary"
        onclick={() => (confirmingSave = true)}
        disabled={saving || !selectedAccount || characters.length === 0}
      >
        Save to WoW
      </button>
    {/if}
  </div>

  <div class="sort-buttons">
    <button
      class:active={isNameSort}
      onclick={() => toggleSort("alphaAsc", "alphaDesc")}
      title="Sort by name — click again to reverse"
    >
      {nameLabel}
    </button>
    <button
      class:active={isLevelSort}
      onclick={() => toggleSort("levelDesc", "levelAsc")}
      title="Sort by level — click again to reverse"
    >
      {levelLabel}
    </button>
    <button
      class:active={isIlvlSort}
      onclick={() => toggleSort("ilvlDesc", "ilvlAsc")}
      title="Sort by item level — click again to reverse"
    >
      {ilvlLabel}
    </button>
    <button class:active={activeSortMode === "classRole"} onclick={() => sortBy("classRole")}>
      {SORT_LABELS.classRole}
    </button>
    <button class:active={activeSortMode === "profession"} onclick={() => sortBy("profession")}>
      {SORT_LABELS.profession}
    </button>
    <button onclick={editProfessionChoices} title="Change which profession a dual-crafter sorts under">
      Prof choices…
    </button>
  </div>

  <p class="status" class:err={!!error}>{error ?? statusMessage}</p>

  {#if hasLoaded}
    <table class="chars">
      <thead>
        <tr>
          <th class="handle"></th>
          <th class="lock" title="Locked characters keep their position — sorts go around them">Lock</th>
          <th></th>
          <th class="num slot">Slot #</th>
          <th>Name</th>
          <th>Realm</th>
          <th class="num">Lvl</th>
          <th>Spec</th>
          <th>Class</th>
          <th class="num">iLvl</th>
          <th>Prof 1</th>
          <th>Prof 2</th>
          <th class="spacer"></th>
        </tr>
      </thead>
      <tbody>
        {#each displayRows as row, i (row.kind === "character" ? row.c.realmGuid : `empty-${row.insertBefore}-${row.slot}`)}
          {#if row.kind === "empty"}
            <tr class="empty-slot" ondragover={(e) => e.preventDefault()} ondrop={() => dropOn(row)}>
              <td class="handle">
                <span
                  class="handle-grip"
                  role="button"
                  tabindex="0"
                  draggable="true"
                  ondragstart={() => dragStartEmpty(row)}
                  title="Drag the empty slot to reorder"
                >⠿</span>
              </td>
              <td class="lock">
                <input
                  type="checkbox"
                  checked={row.locked}
                  onchange={() => toggleGapLock(row.insertBefore)}
                  title="Keep this empty slot through a sort (it's saved/remembered either way)"
                />
              </td>
              <td class="move">
                <button
                  disabled={i === 0}
                  onclick={() => moveGapTo(row.insertBefore, displayRows[i - 1])}
                  title="Move up"
                >^</button>
                <button
                  disabled={i === displayRows.length - 1}
                  onclick={() => moveGapTo(row.insertBefore, displayRows[i + 1])}
                  title="Move down"
                >v</button>
              </td>
              <td class="num slot">{row.slot}</td>
              <td colspan="9" class="empty-label">(empty)</td>
            </tr>
          {:else}
            {@const c = row.c}
            <tr
              class:unresolved={c.classId === 0}
              ondragover={(e) => e.preventDefault()}
              ondrop={() => dropOn(row)}
            >
              <td class="handle">
                <span
                  class="handle-grip"
                  role="button"
                  tabindex="0"
                  draggable="true"
                  ondragstart={() => dragStartCharacter(c.realmGuid)}
                  title="Drag {c.name} to reorder"
                >⠿</span>
              </td>
              <td class="lock">
                <input
                  type="checkbox"
                  checked={lockedGuids.has(c.realmGuid)}
                  onchange={() => toggleLock(c.realmGuid)}
                  title="Lock {c.name} to this position"
                />
              </td>
              <td class="move">
                <button disabled={characters.indexOf(c) === 0} onclick={() => move(c, -1)} title="Move up">^</button>
                <button
                  disabled={characters.indexOf(c) === characters.length - 1}
                  onclick={() => move(c, 1)}
                  title="Move down"
                >v</button>
              </td>
              <td class="num slot">{row.slot}</td>
              <td style:color={c.classId !== 0 ? classColor(c.classKey) : undefined}>{c.name}</td>
              <td>{c.realm}</td>
              <td class="num">{c.level || ""}</td>
              <td>{c.spec}</td>
              <td>{c.className}</td>
              <td class="num" style:color={c.itemLevel > 0 ? ilvlColor(c.itemLevel) : undefined}>
                {c.itemLevel > 0 ? c.itemLevel : ""}
              </td>
              <td>{c.profession1}</td>
              <td>{c.profession2}</td>
              <td class="spacer"></td>
            </tr>
          {/if}
        {/each}
      </tbody>
    </table>
  {/if}

  {#if dialogItems}
    <ProfessionChoiceDialog
      characters={dialogItems}
      initialPrimary={(c) => validPrimaryFor(c.realmGuid, c.profession1, c.profession2)}
      onConfirm={onDialogConfirm}
      onCancel={onDialogCancel}
    />
  {/if}
</div>

<style>
  .sort {
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .toolbar {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 12px;
  }
  .account-picker {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .account-picker select {
    background: var(--surface);
    color: var(--text);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 4px 8px;
    font-size: 12px;
  }
  .sort-buttons {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  .sort-buttons button {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 6px;
    color: var(--muted);
    padding: 4px 10px;
    font-size: 12px;
    cursor: pointer;
  }
  .sort-buttons button:hover {
    background: var(--hover);
  }
  .sort-buttons button.active {
    background: var(--selected);
    color: var(--text);
    border-color: var(--gold);
  }
  .save {
    margin-left: auto;
  }
  .confirm-bar {
    margin-left: auto;
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
    color: var(--muted);
  }
  button.primary {
    background: var(--gold);
    color: #000;
    border: 1px solid var(--gold);
    border-radius: 6px;
    padding: 5px 14px;
    font-weight: 600;
    cursor: pointer;
    font-size: 12px;
  }
  button.primary:disabled {
    opacity: 0.5;
    cursor: default;
  }
  button.secondary {
    background: transparent;
    color: var(--muted);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 5px 12px;
    cursor: pointer;
    font-size: 12px;
  }
  .status {
    color: var(--faded);
    font-size: 12px;
    margin: 0;
  }
  .status.err {
    color: var(--red);
  }
  .chars {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
  }
  .chars th {
    text-align: left;
    color: var(--muted);
    font-weight: 600;
    padding: 5px 12px;
    border-bottom: 1px solid var(--divider);
    white-space: nowrap;
  }
  .chars td {
    padding: 5px 12px;
    border-bottom: 1px solid var(--divider);
    white-space: nowrap;
  }
  .chars .num {
    text-align: center;
    font-family: var(--font-mono);
    font-variant-numeric: tabular-nums;
  }
  /* Trailing column soaks up the extra table width so every real column hugs its content
     (autosized) while the row dividers still span the full width. */
  .chars .spacer {
    width: 100%;
    padding: 0;
  }
  .chars tr.unresolved {
    color: var(--faded);
    font-style: italic;
  }
  .chars tr.empty-slot {
    color: var(--faded);
  }
  .chars .empty-label {
    font-style: italic;
  }
  th.handle,
  td.handle {
    width: 1%;
    text-align: center;
  }
  .handle-grip {
    display: inline-block;
    cursor: grab;
    color: var(--muted);
    font-size: 14px;
    padding: 2px 4px;
  }
  .handle-grip:active {
    cursor: grabbing;
  }
  th.lock,
  td.lock {
    width: 1%;
    text-align: center;
  }
  th.slot,
  td.slot {
    width: 1%;
  }
  .move {
    display: flex;
    gap: 2px;
  }
  .move button {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 4px;
    color: var(--muted);
    width: 20px;
    height: 20px;
    line-height: 1;
    cursor: pointer;
    font-size: 11px;
  }
  .move button:disabled {
    opacity: 0.3;
    cursor: default;
  }
  .move button:not(:disabled):hover {
    background: var(--hover);
  }
</style>
