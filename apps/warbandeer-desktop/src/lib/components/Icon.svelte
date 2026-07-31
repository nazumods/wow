<script lang="ts">
  // One game icon, resolved from the bare name the static-data bundle carries
  // (nazumods/wow#842). Shared by every icon-bearing surface rather than reimplemented per
  // column — currencies want exactly this primitive the moment they get a column of their own.
  //
  // Reserves its box in ALL cases, including "no icon": rows sit in a flex line beside their
  // text, and letting the icon collapse would ragged the whole column wherever the bundle has
  // no image. That is common, not exceptional — most currencies carry no icon in DB2 at all.
  import { iconUrl } from "../icons";

  interface Props {
    /** Bare icon name, or null when the bundle has none for this row. */
    name: string | null;
    /** Rendered edge length in px. The packed images are 36x36, so anything up to 36 is a
     *  downscale and stays sharp on HiDPI. */
    size?: number;
    /** Decorative by default: these sit beside their own label, so announcing them again
     *  would just repeat it to a screen reader. */
    alt?: string;
  }
  let { name, size = 14, alt = "" }: Props = $props();

  const url = $derived(iconUrl(name));

  // Tracks the URL that failed rather than a boolean, so a row recycled onto a different icon
  // clears the failure by itself instead of needing an effect to reset it. The 404 case is
  // real: a few referenced names have no image at the source and are packed empty.
  let failedUrl = $state<string | null>(null);
  const src = $derived(url !== null && url !== failedUrl ? url : null);
</script>

{#if src}
  <img
    class="icon"
    {src}
    {alt}
    width={size}
    height={size}
    style="--size: {size}px"
    onerror={() => (failedUrl = url)}
  />
{:else}
  <span class="icon placeholder" style="--size: {size}px" aria-hidden="true"></span>
{/if}

<style>
  .icon {
    width: var(--size);
    height: var(--size);
    flex-shrink: 0;
    border-radius: 2px;
    /* Blizzard's icon art is drawn to the edge, and the raw square reads as heavy next to
       11-12px text; a hairline seats it in the row the way the in-game frames do. */
    box-shadow: inset 0 0 0 1px var(--border);
  }
  .placeholder {
    display: inline-block;
    background: var(--border);
    opacity: 0.4;
  }
</style>
