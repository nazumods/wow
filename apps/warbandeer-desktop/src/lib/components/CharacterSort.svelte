<script lang="ts">
  // Reorders the WoW character-select list by editing character-list-order.txt while
  // WoW is closed — ported from the standalone WarbandeerCharacterSort app (see its
  // MainViewModel.cs for the reference flow this mirrors).
  import type { ResolvedCharacter, OrderLine } from "../types";
  import { listOrderAccounts, getCharacterOrder, saveCharacterOrder } from "../api";
  import {
    applySort,
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
    classRole: "Class",
    profession: "Profession",
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

  function performSort(mode: SortMode) {
    const map = professionPrimaryMap(characters);
    characters = applySort(characters, mode, map);
    activeSortMode = mode;
    statusMessage = `Previewing "${SORT_LABELS[mode]}" order — click "Save to WoW" to write it, or pick another sort.`;
  }

  function sortBy(mode: SortMode) {
    if (mode === "profession") {
      const needsChoice = characters
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
      const ordered: OrderLine[] = characters.map((c) => ({ flag: c.flag, realmGuid: c.realmGuid }));
      const backupPath = await saveCharacterOrder(selectedAccount, ordered);
      const backupName = backupPath.split(/[\\/]/).pop();
      statusMessage = `Saved. Backup written to ${backupName}. Restart WoW (or go to character select) to see the new order.`;
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
      {#each Object.entries(SORT_LABELS) as [mode, label] (mode)}
        <button class:active={activeSortMode === mode} onclick={() => sortBy(mode as SortMode)}>
          {label}
        </button>
      {/each}
      <button onclick={editProfessionChoices} title="Change which profession a dual-crafter sorts under">
        Prof choices…
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

  <p class="status" class:err={!!error}>{error ?? statusMessage}</p>

  {#if hasLoaded}
    <table class="chars">
      <thead>
        <tr>
          <th></th>
          <th>Name</th>
          <th>Realm</th>
          <th>Class</th>
          <th class="num">Lvl</th>
          <th>Role</th>
          <th class="num">iLvl</th>
          <th>Prof 1</th>
          <th>Prof 2</th>
        </tr>
      </thead>
      <tbody>
        {#each characters as c, i (c.realmGuid)}
          <tr class:unresolved={c.classId === 0}>
            <td class="move">
              <button disabled={i === 0} onclick={() => move(c, -1)} title="Move up">^</button>
              <button disabled={i === characters.length - 1} onclick={() => move(c, 1)} title="Move down">v</button>
            </td>
            <td style:color={c.classId !== 0 ? classColor(c.classKey) : undefined}>{c.name}</td>
            <td>{c.realm}</td>
            <td>{c.className}</td>
            <td class="num">{c.level || ""}</td>
            <td>{c.role}</td>
            <td class="num" style:color={c.itemLevel > 0 ? ilvlColor(c.itemLevel) : undefined}>
              {c.itemLevel > 0 ? c.itemLevel : ""}
            </td>
            <td>{c.profession1}</td>
            <td>{c.profession2}</td>
          </tr>
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
    font-size: 12px;
  }
  .chars th {
    text-align: left;
    color: var(--muted);
    font-weight: 600;
    padding: 4px 8px;
    border-bottom: 1px solid var(--divider);
  }
  .chars td {
    padding: 4px 8px;
    border-bottom: 1px solid var(--divider);
    white-space: nowrap;
  }
  .chars .num {
    text-align: right;
    font-family: var(--font-mono);
    font-variant-numeric: tabular-nums;
  }
  .chars tr.unresolved {
    color: var(--faded);
    font-style: italic;
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
