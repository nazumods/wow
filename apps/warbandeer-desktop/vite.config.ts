import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";

// Tauri serves the dev frontend on a fixed port and expects a stable build dir.
// https://v2.tauri.app/start/frontend/vite/
const host = process.env.TAURI_DEV_HOST;

export default defineConfig({
  plugins: [svelte()],
  clearScreen: false,
  resolve: {
    alias: {
      // The shared Bot Ops module (apps/bot-ops), maintained once and vendored into
      // roshne/wow-companion. Kept as an alias so the cross-app boundary is explicit.
      "@bot-ops": fileURLToPath(new URL("../bot-ops/ts/index.ts", import.meta.url)),
    },
    // The module carries its own @tauri-apps/api (it has to resolve standalone), so without this
    // a second copy would be bundled alongside this app's.
    dedupe: ["@tauri-apps/api"],
  },
  server: {
    port: 1420,
    strictPort: true,
    host: host || false,
    hmr: host ? { protocol: "ws", host, port: 1421 } : undefined,
    // @bot-ops resolves above this app's dir, which the dev server would otherwise refuse to serve.
    fs: { allow: [".."] },
    watch: {
      // src-tauri is watched by the Rust toolchain, not Vite.
      ignored: ["**/src-tauri/**"],
    },
  },
});
