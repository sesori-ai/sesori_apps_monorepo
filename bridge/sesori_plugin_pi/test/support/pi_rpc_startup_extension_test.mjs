import assert from "node:assert/strict";
import fs from "node:fs";
import { syncBuiltinESMExports } from "node:module";
import { PassThrough } from "node:stream";
import { test } from "node:test";
import { pathToFileURL } from "node:url";

const { default: install } = await import(pathToFileURL(process.argv[2]).href);
const tick = () => new Promise(resolve => setImmediate(resolve));

async function fixture(run, { mode = "rpc", nativeInput = false } = {}) {
  const descriptor = Object.getOwnPropertyDescriptor(process, "stdin");
  const input = new PassThrough();
  Object.defineProperty(process, "stdin", { value: input, configurable: true });
  if (nativeInput) input.on("data", () => {});
  const requests = [];
  let startup;
  const originalOutput = fs.writeSync;
  fs.writeSync = (fd, chunk) => {
    assert.equal(fd, 1);
    requests.push(JSON.parse(chunk));
    return Buffer.byteLength(chunk);
  };
  syncBuiltinESMExports();
  install({ on: (event, callback) => {
    assert.equal(event, "session_start");
    startup = callback;
  } });
  const ui = Object.fromEntries(["select", "confirm", "input", "editor"].map(method => [
    method, () => Promise.resolve(`native-${method}`)
  ]));
  const originals = { ...ui };
  try {
    startup({}, { mode, ui });
    const reply = (request, fields) => input.write(JSON.stringify({
      type: "extension_ui_response", id: request.id, ...fields
    }) + "\n");
    await run({ input, ui, originals, requests, reply });
  } finally {
    input.destroy();
    Object.defineProperty(process, "stdin", descriptor);
    fs.writeSync = originalOutput;
    syncBuiltinESMExports();
  }
}

test("all startup dialog kinds resolve only from the matching reply", async () => {
  await fixture(async ({ ui, requests, reply }) => {
    const choices = ui.select("Fixture server", ["Deny", "Allow"]);
    const confirmation = ui.confirm("Fixture approval", "Confirm fixture action");
    const text = ui.input("Fixture input", "value");
    const editor = ui.editor("Fixture editor", "initial");
    assert.deepEqual(requests.map(r => r.method), ["select", "confirm", "input", "editor"]);
    assert.equal(new Set(requests.map(r => r.id)).size, 4);
    assert.deepEqual(requests[0].options, ["Deny", "Allow"]);
    assert.equal(requests[1].message, "Confirm fixture action");
    assert.equal(requests[3].prefill, "initial");
    reply(requests[3], { value: "edited" });
    reply(requests[0], { value: "Deny" });
    reply(requests[2], { value: "typed" });
    reply(requests[1], { confirmed: false });
    assert.deepEqual(await Promise.all([choices, confirmation, text, editor]), ["Deny", false, "typed", "edited"]);
  });
});

test("cancellation, timeout, and abort retain native dialog defaults", async () => {
  await fixture(async ({ ui, requests, reply }) => {
    const cancelled = ui.select("Fixture", ["Deny", "Allow"]);
    reply(requests.at(-1), { cancelled: true });
    assert.equal(await cancelled, undefined);
    assert.equal(await ui.confirm("Fixture", "Fixture", { timeout: 5 }), false);
    const controller = new AbortController();
    const aborted = ui.input("Fixture", "Fixture", { signal: controller.signal });
    controller.abort();
    assert.equal(await aborted, undefined);
    const count = requests.length;
    assert.equal(await ui.select("Fixture", [], { signal: controller.signal }), undefined);
    assert.equal(requests.length, count);
  });
});

test("native handoff preserves command order, LF framing, and partial UTF-8 bytes", async () => {
  await fixture(async ({ input, ui, originals, requests, reply }) => {
    const first = Buffer.from('{"id":"1","type":"get_state"}\r\n');
    const second = Buffer.from('{"id":"2","type":"prompt","message":"café\u2028☕"}\n');
    const split = second.indexOf(Buffer.from("é")) + 1;
    const dialog = ui.select("Fixture", ["Deny", "Allow"]);
    input.write(first);
    input.write(second.subarray(0, split));
    // Complete a fragmented command before its interleaved dialog response.
    input.write(second.subarray(split));
    reply(requests.at(-1), { cancelled: true });
    assert.equal(await dialog, undefined);
    const third = Buffer.from('{"id":"3","type":"prompt","message":"☕"}\n');
    const thirdSplit = third.indexOf(Buffer.from("☕")) + 1;
    input.write(third.subarray(0, thirdSplit));
    const native = [];
    input.on("data", chunk => native.push(chunk));
    await tick();
    input.write(third.subarray(thirdSplit));
    await tick();
    assert.deepEqual(Buffer.concat(native), Buffer.concat([first, second, third]));
    assert.deepEqual(ui, originals);
    assert.equal(input.listenerCount("data"), 1);
    assert.equal(input.listenerCount("newListener"), 0);
    assert.equal(await ui.select(), "native-select");
  });
});

test("readers from a fixed Pi runtime and non-RPC contexts are untouched", async () => {
  for (const options of [{ nativeInput: true }, { mode: "print" }]) {
    await fixture(async ({ input, ui, originals, requests }) => {
      assert.deepEqual(ui, originals);
      assert.deepEqual(requests, []);
      assert.equal(input.listenerCount("newListener"), 0);
      assert.equal(input.listenerCount("data"), options.nativeInput ? 1 : 0);
    }, options);
  }
});
