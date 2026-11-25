import assert from "node:assert/strict";
import fs from "node:fs";
import http from "node:http";
import { syncBuiltinESMExports } from "node:module";
import { PassThrough } from "node:stream";
import { test } from "node:test";
import { pathToFileURL } from "node:url";

const { default: install } = await import(pathToFileURL(process.argv[2]).href);
const tick = () => new Promise(resolve => setImmediate(resolve));
const sesoriLaunchKey = Symbol.for("sesori.mcp.launch");
const sesoriKeys = ["SESORI_MCP_URL", "SESORI_MCP_TOKEN", "SESORI_MCP_SERVER", "SESORI_SKILLS_ROOT"];

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

async function withSesoriServer(answer, run) {
  const requests = [];
  const server = http.createServer(async (request, response) => {
    let body = "";
    for await (const chunk of request) body += chunk;
    const message = JSON.parse(body);
    requests.push({ headers: request.headers, message });
    const { status = 200, result, error } = answer(message);
    response.writeHead(status, { "content-type": "application/json" });
    response.end(JSON.stringify({ jsonrpc: "2.0", id: message.id, result, error }));
  });
  await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
  delete globalThis[sesoriLaunchKey];
  Object.assign(process.env, {
    SESORI_MCP_URL: `http://127.0.0.1:${server.address().port}/mcp`,
    SESORI_MCP_TOKEN: "fixture-token",
    SESORI_MCP_SERVER: "sesori_bridge",
    SESORI_SKILLS_ROOT: "/data/agent-skills/skills",
  });
  const tools = [];
  const handlers = {};
  let active = ["read", "bash"];
  const pi = {
    on: (event, handler) => { handlers[event] = handler; },
    registerTool: tool => tools.push(tool),
    getAllTools: () => [{ name: "read" }, { name: "bash" }, { name: "tool_search" }],
    getActiveTools: () => active,
    setActiveTools: names => { active = names; },
  };
  const load = () => install(pi);
  try {
    await load();
    await run({ tools, requests, load, handlers, active: () => active });
  } finally {
    for (const key of sesoriKeys) delete process.env[key];
    delete globalThis[sesoriLaunchKey];
    await new Promise(resolve => server.close(resolve));
  }
}

const fixtureTool = {
  name: "get_task",
  title: "Get task",
  description: "Fixture description",
  inputSchema: { type: "object", properties: { task_id: { type: "string" } } },
  annotations: { readOnlyHint: true },
};

test("Sesori tools are registered under Pi's MCP names and forward calls", async () => {
  await withSesoriServer(message => ({
    initialize: { result: { instructions: "Fixture instructions." } },
    "tools/list": { result: { tools: [fixtureTool] } },
  })[message.method] ?? { result: { content: [{ type: "text", text: "Unknown task" }], isError: true } },
  async ({ tools, requests, load, handlers, active }) => {
    assert.equal(tools.length, 1);
    for (const key of sesoriKeys) assert.equal(process.env[key], undefined);
    const [tool] = tools;
    assert.equal(tool.name, "mcp__sesori_bridge__get_task");
    assert.equal(tool.label, "Get task");
    assert.equal(tool.description, "Fixture description");
    assert.deepEqual(tool.parameters, fixtureTool.inputSchema);
    assert.deepEqual(tool.annotations, { readOnlyHint: true });
    assert.equal(tool.exposure, "deferred");
    handlers.session_start({}, { mode: "rpc" });
    assert.deepEqual(active(), ["read", "bash", "tool_search"]);
    assert.deepEqual(handlers.resources_discover({}), { skillPaths: ["/data/agent-skills/skills"] });
    const sections = {};
    assert.equal(handlers.before_agent_start({ systemPromptOptions: { sections } }), undefined);
    assert.match(sections.sesori, /^Fixture instructions\.\n\n.*mcp__sesori_bridge__<tool>.*tool_search/);
    assert.deepEqual(
      handlers.before_agent_start({ systemPrompt: "Base." }),
      { systemPrompt: `Base.\n\n${sections.sesori}` },
    );
    const result = await tool.execute("call-1", { task_id: "task" }, undefined);
    assert.deepEqual(result, { content: [{ type: "text", text: "Unknown task" }], details: {}, isError: true });
    assert.deepEqual(requests.map(r => r.message.method), ["initialize", "tools/list", "tools/call"]);
    assert.deepEqual(requests[2].message.params, { name: "get_task", arguments: { task_id: "task" } });
    for (const { headers } of requests) {
      assert.equal(headers.authorization, "Bearer fixture-token");
      assert.equal(headers["content-type"], "application/json");
      assert.equal(headers.origin, undefined);
    }
    // A /reload loads the file again after the environment was cleared.
    await load();
    assert.deepEqual(tools.map(t => t.name), ["mcp__sesori_bridge__get_task", "mcp__sesori_bridge__get_task"]);
    assert.equal(requests.at(-1).headers.authorization, "Bearer fixture-token");
  });
});

test("a refused tool list leaves Pi without Sesori tools and still starts", async () => {
  const errors = [];
  const originalError = console.error;
  console.error = line => errors.push(line);
  try {
    await withSesoriServer(() => ({ status: 401 }), async ({ tools }) => {
      assert.deepEqual(tools, []);
    });
  } finally {
    console.error = originalError;
  }
  assert.equal(errors.length, 1);
  assert.match(errors[0], /sesori_bridge tools are unavailable: HTTP 401/);
  assert.doesNotMatch(errors[0], /fixture-token/);
});

test("a launch without Sesori tools registers none", async () => {
  delete globalThis[sesoriLaunchKey];
  const tools = [];
  await install({ on: () => {}, registerTool: tool => tools.push(tool) });
  assert.deepEqual(tools, []);
});
