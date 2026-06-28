<script lang="ts">
  // Mirrors controls/StatCard.lua: caption + big mono amount, optional sub line
  // with a trend arrow.
  interface Props {
    caption: string;
    amount: string;
    amountColor?: string;
    sub?: string;
    subColor?: string;
    trend?: "up" | "down" | null;
  }
  let {
    caption,
    amount,
    amountColor = "var(--text)",
    sub = "",
    subColor = "var(--faded)",
    trend = null,
  }: Props = $props();
</script>

<div class="card">
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

<style>
  .card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 10px 14px;
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-height: 64px;
    justify-content: center;
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
