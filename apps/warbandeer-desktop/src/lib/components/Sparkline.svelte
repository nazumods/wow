<script lang="ts">
  // Single-series sparkline for stat cards: 2px line over a soft area fill,
  // hover reveals the nearest point. No axes or legend — the card gives context.
  interface Props {
    values: number[]; // oldest first; the last point is "now"
    color?: string;
    format?: (v: number) => string; // hover value text
    label?: (i: number, n: number) => string; // hover caption, e.g. "3 wk ago"
  }
  let {
    values,
    color = "var(--text)",
    format = (v) => String(Math.round(v)),
    label = () => "",
  }: Props = $props();

  let w = $state(0);
  let h = $state(0);
  let hover = $state(-1);

  const PAD = 4; // keeps the stroke and hover dot inside the box

  let pts = $derived.by(() => {
    const n = values.length;
    if (n < 2 || w <= 0 || h <= 0) return [];
    const min = Math.min(...values);
    const span = Math.max(...values) - min || 1; // flat series → centered line
    return values.map((v, i) => ({
      x: PAD + (i * (w - 2 * PAD)) / (n - 1),
      y: PAD + (1 - (v - min) / span) * (h - 2 * PAD),
    }));
  });
  let line = $derived(pts.map((p, i) => `${i ? "L" : "M"}${p.x},${p.y}`).join(" "));
  let area = $derived(
    pts.length ? `${line} L${pts[pts.length - 1].x},${h} L${pts[0].x},${h} Z` : "",
  );

  function move(e: PointerEvent) {
    if (!pts.length) return;
    // clientX vs the svg's own rect: offsetX would be relative to whichever
    // child path the pointer happens to be over.
    const x = e.clientX - (e.currentTarget as Element).getBoundingClientRect().left;
    const step = (w - 2 * PAD) / (values.length - 1);
    hover = Math.max(0, Math.min(values.length - 1, Math.round((x - PAD) / step)));
  }
</script>

{#if values.length >= 2}
  <div class="spark" bind:clientWidth={w} bind:clientHeight={h}>
    {#if pts.length}
      <svg
        width={w}
        height={h}
        role="img"
        aria-label="Trend over the last {values.length} weeks"
        onpointermove={move}
        onpointerleave={() => (hover = -1)}
      >
        <path d={area} fill={color} fill-opacity="0.1" />
        <path
          d={line}
          fill="none"
          stroke={color}
          stroke-width="2"
          stroke-linejoin="round"
          stroke-linecap="round"
        />
        {#if hover >= 0}
          <circle cx={pts[hover].x} cy={pts[hover].y} r="3" fill={color} />
        {/if}
      </svg>
      {#if hover >= 0}
        <div class="chart-tip" style:left="{Math.min(Math.max(pts[hover].x, 44), w - 44)}px">
          <span class="num">{format(values[hover])}</span>
          <span class="when">{label(hover, values.length)}</span>
        </div>
      {/if}
    {/if}
  </div>
{/if}

<style>
  .spark {
    position: relative;
    width: 100%;
    height: 100%;
    min-height: 32px;
  }
  svg {
    display: block;
  }
</style>
