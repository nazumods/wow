<script lang="ts">
  // GitHub-style activity boxes for stat cards: weeks as columns, Mon–Sun rows,
  // cell intensity = that day's value relative to the window's max. Hover
  // reveals the day. No axes or legend — the card gives context.
  interface Props {
    byDay: Record<string, number>; // "YYYY-MM-DD" (local day) → seconds
    weeks?: number;
    color?: string; // sequential hue; intensity comes from opacity steps
  }
  let { byDay, weeks = 12, color = "var(--green)" }: Props = $props();

  let w = $state(0);
  let h = $state(0);
  let hover = $state(-1);

  const GAP = 1;
  const OPACITY = [0, 0.25, 0.45, 0.7, 1]; // index = level

  function dayKey(d: Date): string {
    const p = (n: number) => String(n).padStart(2, "0");
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
  }

  // Monday-aligned window of `weeks` columns ending today (last column partial).
  let days = $derived.by(() => {
    const today = new Date();
    const weekday = (today.getDay() + 6) % 7; // Mon=0 … Sun=6
    const count = (weeks - 1) * 7 + weekday + 1;
    return Array.from({ length: count }, (_, i) => {
      const d = new Date(today.getFullYear(), today.getMonth(), today.getDate() - (count - 1 - i));
      return { date: d, secs: byDay[dayKey(d)] ?? 0 };
    });
  });
  let max = $derived(days.reduce((m, d) => Math.max(m, d.secs), 0));

  // Square cells sized by whichever dimension is tighter; grid hugs the right
  // edge (newest week outermost), centered vertically.
  let cell = $derived(
    Math.max(2, Math.min(Math.floor((h - 6 * GAP) / 7), Math.floor((w - (weeks - 1) * GAP) / weeks))),
  );
  let x0 = $derived(w - (weeks * (cell + GAP) - GAP));
  let y0 = $derived((h - (7 * (cell + GAP) - GAP)) / 2);

  // The oldest ~1.5 columns dissolve toward the left, so the grid reads as a
  // window onto history rather than ending in a hard edge.
  let fade = $derived(
    `linear-gradient(90deg, transparent ${x0}px, #000 ${x0 + 2.5 * (cell + GAP)}px)`,
  );

  function level(secs: number): number {
    if (secs <= 0 || max <= 0) return 0;
    return Math.min(4, Math.max(1, Math.ceil((secs / max) * 4)));
  }

  function move(e: PointerEvent) {
    const r = (e.currentTarget as Element).getBoundingClientRect();
    const col = Math.floor((e.clientX - r.left - x0) / (cell + GAP));
    const row = Math.floor((e.clientY - r.top - y0) / (cell + GAP));
    const i = col * 7 + row;
    hover = col >= 0 && row >= 0 && row < 7 && i < days.length ? i : -1;
  }

  function hoursLabel(secs: number): string {
    if (secs < 60) return "0h";
    const hrs = Math.floor(secs / 3600);
    const min = Math.round((secs % 3600) / 60);
    return hrs > 0 ? `${hrs}h ${min}m` : `${min}m`;
  }

  function whenLabel(d: Date): string {
    const today = new Date();
    if (dayKey(d) === dayKey(today)) return "today";
    return d.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" });
  }
</script>

<div class="boxes" bind:clientWidth={w} bind:clientHeight={h}>
  {#if w > 0 && h > 0}
    <svg
      width={w}
      height={h}
      role="img"
      aria-label="Hours played per day over the last {weeks} weeks"
      style:mask-image={fade}
      style:-webkit-mask-image={fade}
      onpointermove={move}
      onpointerleave={() => (hover = -1)}
    >
      {#each days as d, i (i)}
        {@const lv = level(d.secs)}
        <rect
          x={x0 + Math.floor(i / 7) * (cell + GAP)}
          y={y0 + (i % 7) * (cell + GAP)}
          width={cell}
          height={cell}
          rx="1"
          fill={lv === 0 ? "rgba(255, 255, 255, 0.07)" : color}
          fill-opacity={lv === 0 ? 1 : OPACITY[lv]}
          stroke={i === hover ? "var(--text)" : "none"}
          stroke-width="1"
        />
      {/each}
    </svg>
    {#if hover >= 0}
      <div
        class="chart-tip"
        style:left="{Math.min(Math.max(x0 + Math.floor(hover / 7) * (cell + GAP) + cell / 2, 52), w - 52)}px"
      >
        <span class="num">{hoursLabel(days[hover].secs)}</span>
        <span class="when">{whenLabel(days[hover].date)}</span>
      </div>
    {/if}
  {/if}
</div>

<style>
  .boxes {
    position: relative;
    width: 100%;
    height: 100%;
    min-height: 32px;
  }
  svg {
    display: block;
  }
</style>
