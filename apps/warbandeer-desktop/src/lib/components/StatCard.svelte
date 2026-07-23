<script lang="ts">
  // Mirrors controls/StatCard.lua: caption + big mono amount, optional sub line
  // with a trend arrow. An optional `graph` snippet fills the right half.
  import type { Snippet } from "svelte";

  interface Props {
    caption: string;
    amount: string;
    amountColor?: string;
    sub?: string;
    subColor?: string;
    trend?: "up" | "down" | null;
    graph?: Snippet;
    graphBleed?: boolean; // graph area extends over the card padding to the borders
  }
  let {
    caption,
    amount,
    amountColor = "var(--text)",
    sub = "",
    subColor = "var(--faded)",
    trend = null,
    graph,
    graphBleed = false,
  }: Props = $props();
</script>

<div class="card">
  <div class="left">
    <div class="caps caption">{caption}</div>
    <div class="amount num" style:color={amountColor}>{amount}</div>
    {#if sub}
      <div class="sub" style:color={subColor}>
        {#if trend}
          <span class="trend">{trend === "up" ? "▲" : "▼"}</span>
        {/if}
        <span>{sub}</span>
      </div>
    {/if}
  </div>
  {#if graph}
    <!-- The chart fills this box via an absolute inset so its measured size can
         never feed back into the card's height. -->
    <div class="graph"><div class="fill" class:bleed={graphBleed}>{@render graph()}</div></div>
  {/if}
</div>

<style>
  .card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 10px 14px;
    display: flex;
    gap: 12px;
    min-height: 64px;
    align-items: stretch;
  }
  /* The text column keeps its natural width; the graph takes what's left, so
     tight cards squeeze the graph rather than clipping the amount. */
  .left {
    flex: 0 1 auto;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
    justify-content: center;
  }
  .graph {
    flex: 1 1 0;
    min-width: 0;
    position: relative;
  }
  .fill {
    position: absolute;
    inset: 4px 0;
  }
  /* Negative offsets mirror .card's padding, so the graph reaches the borders
     (left stays put — it must not crowd the text column). */
  .fill.bleed {
    inset: -10px -14px -10px 0;
  }
  .caption {
    font-size: 10px;
    color: var(--faded);
  }
  .amount {
    font-size: 20px;
    font-weight: 600;
    line-height: 1.1;
  }
  .sub {
    font-size: 11px;
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .trend {
    font-size: 9px;
  }
</style>
