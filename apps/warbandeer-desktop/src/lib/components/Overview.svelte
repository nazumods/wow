<script lang="ts">
  // Mirrors views/Overview.lua: a 3-card stat strip over a 3-column grid
  // (Reputations | Achievements | Top Characters).
  import type { Overview } from "../types";
  import { breakUpLargeNumbers, goldText, hoursText, copperToGold } from "../format";
  import { ilvlColor } from "../theme";
  import StatCard from "./StatCard.svelte";
  import Sparkline from "./Sparkline.svelte";
  import ActivityGrid from "./ActivityGrid.svelte";
  import FactionBars from "./FactionBars.svelte";
  import Achievements from "./Achievements.svelte";
  import TopCharacters from "./TopCharacters.svelte";

  interface Props {
    data: Overview;
  }
  let { data }: Props = $props();

  let s = $derived(data.stats);

  // Weekly-gold sub-line + trend, matching the addon's wealth card.
  let madeGold = $derived(copperToGold(s.weeklyGoldMadeCopper));
  let madeSub = $derived(
    madeGold === 0
      ? ""
      : `${madeGold > 0 ? "+" : ""}${breakUpLargeNumbers(madeGold)}g this week`,
  );
  let trend = $derived<"up" | "down" | null>(
    madeGold === 0 ? null : madeGold > 0 ? "up" : "down",
  );
  let trendColor = $derived(madeGold >= 0 ? "var(--green)" : "var(--red)");

  let playtimeSub = $derived(
    `${hoursText(s.patchPlaytimeSecs)} this patch · ${s.charCount} chars`,
  );

  // Wealth trend: closed week-end values + live wealth (see OverviewStats).
  // With no closed weeks yet there's only the live point — nothing to draw.
  let wealthSeries = $derived(s.wealthHistoryCopper ?? []);
  const weekLabel = (i: number, n: number) =>
    i === n - 1 ? "now" : `${n - 1 - i} wk ago`;
</script>

{#snippet wealthGraph()}
  <Sparkline
    values={wealthSeries}
    color="var(--gold)"
    format={goldText}
    label={weekLabel}
  />
{/snippet}

{#snippet playtimeGraph()}
  <ActivityGrid byDay={s.playtimeByDay} />
{/snippet}

<div class="overview">
  <div class="grid">
    <!-- column 0: Reputations -->
    <section class="col">
      <StatCard
        caption="Total Warband Wealth"
        amount={goldText(s.wealthCopper)}
        amountColor="var(--gold)"
        sub={madeSub}
        {trend}
        subColor={trendColor}
        graph={wealthSeries.length >= 2 ? wealthGraph : undefined}
      />
      <div class="caps head">Reputations</div>
      <div class="module">
        <FactionBars factions={data.reputations} />
      </div>
    </section>

    <!-- column 1: Achievements -->
    <section class="col">
      <StatCard
        caption="Total Playtime"
        amount={hoursText(s.totalPlaytimeSecs)}
        sub={playtimeSub}
        graph={Object.keys(s.playtimeByDay ?? {}).length > 0 ? playtimeGraph : undefined}
        graphBleed
      />
      <div class="caps head">Achievements</div>
      <div class="module">
        <Achievements />
      </div>
    </section>

    <!-- column 2: Top Characters -->
    <section class="col">
      <StatCard
        caption="Top Item Level"
        amount={String(s.topIlvl)}
        amountColor={ilvlColor(s.topIlvl)}
      />
      <div class="caps head">Top Characters</div>
      <div class="module">
        <TopCharacters rows={data.topCharacters} />
      </div>
    </section>
  </div>
</div>

<style>
  .overview {
    padding: 12px;
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(240px, 1fr));
    gap: 16px;
    align-items: start;
  }
  .col {
    display: flex;
    flex-direction: column;
    gap: 8px;
    min-width: 0;
  }
  .head {
    margin-top: 4px;
  }
  .module {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 12px;
  }
</style>
