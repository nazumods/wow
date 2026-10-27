// Run each named check in turn; a throw is logged and swallowed so it cannot stop the others.
export async function runIsolated(checks: [name: string, run: () => Promise<void>][]): Promise<void> {
  for (const [name, run] of checks) {
    try {
      await run();
    } catch (err) {
      console.error(`[tick:${name}]`, err);
    }
  }
}
