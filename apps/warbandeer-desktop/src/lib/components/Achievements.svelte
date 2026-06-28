<script lang="ts">
  // Mirrors the third Overview column (views/overview/Achievements.lua). Achievement
  // completion is live game state the addon reads from the achievement API and does
  // not persist to SavedVariables, so it can't be reconstructed offline. The column
  // is kept for layout parity with a clear note; a future addon broker could cache
  // the per-expansion checklist to populate it.
</script>

<div class="placeholder">
  <p>Achievement completion isn't stored in the addon's saved data.</p>
  <p class="hint">
    This column needs live game state. Caching the per-expansion checklist in the
    addon would let the desktop app fill it in.
  </p>
</div>

<style>
  .placeholder {
    color: var(--faded);
    font-size: 12px;
    line-height: 1.5;
    border: 1px dashed var(--border);
    border-radius: 8px;
    padding: 12px;
  }
  .placeholder p {
    margin: 0 0 8px;
  }
  .hint {
    color: var(--faded);
    opacity: 0.8;
  }
</style>
