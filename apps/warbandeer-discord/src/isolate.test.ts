import { expect, spyOn, test } from "bun:test";
import { runIsolated } from "./isolate";

test("a throwing check does not stop the ones after it", async () => {
  const spy = spyOn(console, "error").mockImplementation(() => {});
  const ran: string[] = [];
  await runIsolated([
    ["a", async () => void ran.push("a")],
    ["b", async () => { throw new RangeError("boom"); }],
    ["c", async () => void ran.push("c")],
  ]);
  expect(ran).toEqual(["a", "c"]);
  expect(spy).toHaveBeenCalledTimes(1);
  spy.mockRestore();
});
