<script lang="ts">
  // The Currencies tab: the in-game Summary view's currency columns as one grid
  // (nazumods/wow#884). A row per character, a column per currency the addon's broker
  // persists, ordered and joined to its display metadata in Rust — see currencies.rs.
  //
  // Rendering follows views/SummaryColumns.lua: quantity right-aligned, tinted with
  // ns.CappedColor when the character is capped, and ns.ZeroDash ("—") for a genuine 0. The
  // one deliberate difference is what "genuine" means. In game the dash is gated on max
  // level; here it is gated on the data, which says the same thing more directly — the
  // broker's `maxLevel = true` fields are never captured for a levelling character at all,
  // so a null cell IS the levelling case and renders blank.
  import type { Currencies, CurrencyColumn, CurrencyCell } from "../types";
  import { breakUpLargeNumbers, goldText } from "../format";
  import { classColor } from "../theme";
  import Icon from "./Icon.svelte";

  interface Props {
    data: Currencies;
  }
  let { data }: Props = $props();

  const columns = $derived(data?.columns ?? []);
  const rows = $derived(data?.rows ?? []);

  function cellText(col: CurrencyColumn, c: CurrencyCell): string {
    if (c.quantity === null) return "";
    if (col.isGold) return goldText(c.quantity);
    // A captured zero is information ("nothing banked"), not absence — so it gets the dash
    // rather than the blank an uncaptured cell gets.
    if (c.quantity === 0) return "—";
    return breakUpLargeNumbers(c.quantity);
  }

  // Everything the in-game view put in a per-cell tooltip, as the cell's title. The caps are
  // the character's own reported values, not the currency's DB2 cap, so they can differ per
  // alt (Nebulous Voidcore's season cap grows every weekly reset).
  function cellTitle(col: CurrencyColumn, c: CurrencyCell): string {
    if (c.quantity === null) return `${col.name} — never captured for this character`;
    const parts = [`${col.name}: ${breakUpLargeNumbers(c.quantity)} held`];
    if (c.max > 0) parts.push(`cap ${breakUpLargeNumbers(c.max)}`);
    if (c.weeklyMax > 0)
      parts.push(
        `earned ${breakUpLargeNumbers(c.earned)}/${breakUpLargeNumbers(c.weeklyMax)} this week`,
      );
    else if (c.earned > 0) parts.push(`earned ${breakUpLargeNumbers(c.earned)}`);
    if (c.capped) parts.push("capped");
    return parts.join(" · ");
  }
</script>

<div class="currencies">
  {#if columns.length === 0}
    <div class="state">
      The bundled currency data carries no field map — regenerate `static-data.json`.
    </div>
  {:else if rows.length === 0}
    <div class="state">No characters scanned yet.</div>
  {:else}
    <div class="scroll">
      <table>
        <thead>
          <tr>
            <th class="who">Character</th>
            {#each columns as col (col.field)}
              <th title={col.name}>
                <!-- Gold has no DB2 row, so no icon can arrive from the bundle; the
                     pseudo-name resolves to the app's own stand-in (see icons.ts). -->
                <Icon name={col.isGold ? "wb:gold" : col.icon} size={18} />
                <span class="label">{col.name}</span>
              </th>
            {/each}
          </tr>
        </thead>
        <tbody>
          {#each rows as r (r.name + (r.realm ?? ""))}
            <tr>
              <th class="who" scope="row">
                <span class="lvl num">{r.level}</span>
                <span class="name" style:color={classColor(r.classKey)}>{r.name}</span>
              </th>
              {#each columns as col, i (col.field)}
                <td
                  class="num"
                  class:capped={r.cells[i]?.capped}
                  class:zero={r.cells[i]?.quantity === 0 && !col.isGold}
                  title={r.cells[i] ? cellTitle(col, r.cells[i]) : ""}
                >
                  {r.cells[i] ? cellText(col, r.cells[i]) : ""}
                </td>
              {/each}
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

<style>
  .currencies {
    padding: 12px;
  }
  /* The grid is wider than a narrow window; it scrolls on its own rather than making the
     page scroll sideways. */
  .scroll {
    overflow-x: auto;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
  }
  table {
    border-collapse: collapse;
    font-size: 13px;
    width: 100%;
  }
  thead th {
    position: sticky;
    top: 0;
    z-index: 2;
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    padding: 8px 6px;
    vertical-align: bottom;
    font-weight: 500;
    color: var(--muted);
  }
  /* Icon over a wrapped name: the currencies' real DB2 names are long ("Untainted
     Mana-Crystals") and abbreviating them would mean hand-maintaining labels the bundle
     already provides. Naming every column also keeps the one currency whose icon has no
     image identifiable — the header would otherwise be an anonymous placeholder box. */
  thead th:not(.who) {
    display: table-cell;
    text-align: center;
    min-width: 70px;
    max-width: 88px;
  }
  .label {
    display: block;
    margin-top: 3px;
    font-size: 10px;
    line-height: 1.2;
    color: var(--faded);
  }
  /* The character column stays put while the currencies scroll under it. */
  .who {
    position: sticky;
    left: 0;
    z-index: 1;
    background: var(--surface);
    text-align: left;
    white-space: nowrap;
    font-weight: 400;
  }
  thead th.who {
    z-index: 3;
    color: var(--faded);
    font-size: 11px;
    letter-spacing: 0.06em;
    text-transform: uppercase;
  }
  .lvl {
    color: var(--faded);
    font-size: 11px;
    margin-right: 6px;
  }
  td,
  tbody th {
    padding: 3px 6px;
    border-bottom: 1px solid var(--divider);
  }
  tbody tr:last-child td,
  tbody tr:last-child th {
    border-bottom: none;
  }
  tbody tr:hover td,
  tbody tr:hover th {
    background: var(--hover);
  }
  td {
    text-align: right;
    color: var(--text);
  }
  /* ns.CappedColor — the weekly or hold cap is reached and nothing more can be earned. */
  td.capped {
    color: var(--red);
  }
  /* ns.ZeroDash — captured, but nothing banked. */
  td.zero {
    color: var(--faded);
  }
  .state {
    color: var(--faded);
    font-size: 12px;
    padding: 16px 0;
    text-align: center;
  }
</style>
