<script lang="ts">
  // Asked only for dual-crafting characters, where there's no automatic priority
  // between the two professions — the user picks which one is the sort identity.
  // Ported from ProfessionChoiceDialog.xaml(.cs) in the standalone app.
  import type { ResolvedCharacter } from "../types";

  interface Props {
    characters: ResolvedCharacter[];
    initialPrimary: (c: ResolvedCharacter) => string | undefined;
    onConfirm: (choices: Map<string, string>) => void;
    onCancel: () => void;
  }
  let { characters, initialPrimary, onConfirm, onCancel }: Props = $props();

  // realmGuid -> chosen profession name. A plain object, not a Map — $state's
  // reactivity for a mutated Map's .set() calls isn't guaranteed the way plain
  // object/array proxying is (svelte/reactivity's SvelteMap exists for that; a
  // plain object sidesteps the question entirely). Defaults to profession1 unless
  // a remembered choice points at profession2 (mirrors FirstChosen's default-true).
  let picks = $state<Record<string, string>>(
    Object.fromEntries(
      characters.map((c): [string, string] => {
        const remembered = initialPrimary(c);
        return [c.realmGuid, remembered === c.profession2 ? c.profession2 : c.profession1];
      }),
    ),
  );

  function confirm() {
    onConfirm(new Map(Object.entries(picks)));
  }
</script>

<div class="overlay" role="dialog" aria-modal="true">
  <div class="dialog">
    <h2>Which profession should each character sort under?</h2>
    <p class="hint">These characters have two crafting professions — pick the one that leads.</p>

    <div class="list">
      {#each characters as c (c.realmGuid)}
        <div class="row">
          <span class="name">{c.name}</span>
          <div class="choices">
            <label>
              <input type="radio" name={c.realmGuid} checked={picks[c.realmGuid] === c.profession1}
                onchange={() => (picks[c.realmGuid] = c.profession1)} />
              {c.profession1}
            </label>
            <label>
              <input type="radio" name={c.realmGuid} checked={picks[c.realmGuid] === c.profession2}
                onchange={() => (picks[c.realmGuid] = c.profession2)} />
              {c.profession2}
            </label>
          </div>
        </div>
      {/each}
    </div>

    <div class="actions">
      <button class="secondary" onclick={onCancel}>Cancel</button>
      <button class="primary" onclick={confirm}>OK</button>
    </div>
  </div>
</div>

<style>
  .overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.55);
    display: grid;
    place-items: center;
    z-index: 100;
  }
  .dialog {
    background: var(--window);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 20px;
    width: min(480px, 90vw);
    max-height: 80vh;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  h2 {
    font-family: var(--font-display);
    font-size: 15px;
    margin: 0;
  }
  .hint {
    color: var(--faded);
    font-size: 12px;
    margin: 0;
  }
  .list {
    overflow: auto;
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 4px 0;
  }
  .row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 8px 10px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 6px;
  }
  .name {
    font-weight: 600;
    white-space: nowrap;
  }
  .choices {
    display: flex;
    gap: 14px;
    font-size: 12px;
  }
  .choices label {
    display: flex;
    align-items: center;
    gap: 4px;
    cursor: pointer;
  }
  .actions {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    margin-top: 4px;
  }
  button {
    border-radius: 6px;
    padding: 6px 16px;
    cursor: pointer;
    font-size: 13px;
    border: 1px solid var(--border);
  }
  .secondary {
    background: transparent;
    color: var(--muted);
  }
  .secondary:hover {
    background: var(--hover);
  }
  .primary {
    background: var(--gold);
    color: #000;
    border-color: var(--gold);
    font-weight: 600;
  }
  .primary:hover {
    filter: brightness(1.08);
  }
</style>
