<script lang="ts">
  // Mirrors views/overview/TopAlts.lua: the top character per class, sorted by
  // (level desc, ilvl desc, name), with class-colored names and tier-colored ilvl.
  // The raid set-completion columns (RF/N/H/M) depend on the Collected addon DB and
  // are a planned follow-up.
  import type { TopCharacter } from "../types";
  import { classColor, ilvlColor } from "../theme";

  interface Props {
    rows: TopCharacter[];
  }
  let { rows }: Props = $props();
</script>

<table class="top">
  <tbody>
    {#each rows as c (c.classKey)}
      <tr>
        <td class="lvl num">{c.level}</td>
        <td class="name" style:color={classColor(c.classKey)}>{c.name}</td>
        <td class="ilvl num" style:color={ilvlColor(c.ilvl)}>{c.ilvl}</td>
      </tr>
    {/each}
    {#if rows.length === 0}
      <tr><td colspan="3" class="empty">No characters scanned yet.</td></tr>
    {/if}
  </tbody>
</table>

<style>
  .top {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
  }
  td {
    padding: 3px 6px;
    border-bottom: 1px solid var(--divider);
    white-space: nowrap;
  }
  tr:last-child td {
    border-bottom: none;
  }
  .lvl {
    width: 28px;
    color: var(--text);
    text-align: left;
  }
  .name {
    width: 100%;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .ilvl {
    text-align: right;
    font-weight: 600;
  }
  .empty {
    color: var(--faded);
    text-align: center;
    border-bottom: none;
  }
</style>
