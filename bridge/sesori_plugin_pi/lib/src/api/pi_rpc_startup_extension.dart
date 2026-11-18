import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

const String _sesoriMcpUrlVariable = "SESORI_MCP_URL";
const String _sesoriMcpTokenVariable = "SESORI_MCP_TOKEN";
const String _sesoriMcpServerVariable = "SESORI_MCP_SERVER";

/// The environment that lets [piRpcStartupExtensionSource] give one Pi process
/// Sesori's MCP tools. The token stays out of argv, which other local users can
/// read, and the extension removes it from the environment the agent's own
/// commands inherit.
Map<String, String> piSesoriMcpEnvironment({required SesoriMcpLaunch launch}) => {
  _sesoriMcpUrlVariable: launch.url,
  _sesoriMcpTokenVariable: launch.token,
  _sesoriMcpServerVariable: launch.serverName,
};

/// Loaded before user extensions. It owns two startup concerns:
///
/// - Startup dialogs. Pi 1.0.4 awaits `session_start` before attaching its
///   stdin reader, so a startup dialog otherwise waits forever or lets Node
///   exit, even when Sesori replies. Native RPC owns all later input and UI.
/// - Sesori's MCP tools, when the launch environment carries them. Each tool
///   the server lists is registered with `pi.registerTool` under Pi's own MCP
///   name, `mcp__<server>__<tool>`, and each call is forwarded to the server.
///   `pi.registerMcpServer` is avoided because an MCP-replacing extension such
///   as pi-mcp-adapter makes it fail. Nothing reaches Pi's configuration, so a
///   session resumed outside Sesori has no Sesori tools.
const piRpcStartupExtensionSource =
    '''
import { randomUUID } from "node:crypto";
import { writeSync } from "node:fs";
'''
    '''
const sesoriMcpEnvironment = {
  url: "$_sesoriMcpUrlVariable",
  token: "$_sesoriMcpTokenVariable",
  server: "$_sesoriMcpServerVariable",
};
'''
    r'''

export default async function (pi) {
  // Pi redirects process.stdout.write from extensions to diagnostic stderr.
  const output = frame => writeSync(1, JSON.stringify(frame) + "\n");
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "rpc" || process.stdin.listenerCount("data") !== 0) return;

    const ui = ctx.ui;
    const originals = Object.fromEntries(
      ["select", "confirm", "input", "editor"].map(name => [name, ui[name]])
    );
    const pending = new Map();
    const queued = [];
    // Retain bytes, including an incomplete UTF-8 character, for native RPC.
    let input = Buffer.alloc(0);

    const dialog = (request, opts, fallback, parse) => {
      if (opts?.signal?.aborted) return Promise.resolve(fallback);
      const id = randomUUID();
      return new Promise(resolve => {
        let timer;
        const finish = value => {
          pending.delete(id);
          clearTimeout(timer);
          opts?.signal?.removeEventListener("abort", cancel);
          resolve(value);
        };
        const cancel = () => finish(fallback);
        pending.set(id, reply => finish(reply.cancelled ? fallback : parse(reply)));
        opts?.signal?.addEventListener("abort", cancel, { once: true });
        if (opts?.timeout) timer = setTimeout(cancel, opts.timeout);
        output({
          type: "extension_ui_request", id, ...request, timeout: opts?.timeout
        });
      });
    };

    ui.select = (title, options, opts) =>
      dialog({ method: "select", title, options }, opts, undefined, r => r.value);
    ui.confirm = (title, message, opts) =>
      dialog({ method: "confirm", title, message }, opts, false, r => r.confirmed);
    ui.input = (title, placeholder, opts) =>
      dialog({ method: "input", title, placeholder }, opts, undefined, r => r.value);
    ui.editor = (title, prefill) =>
      dialog({ method: "editor", title, prefill }, undefined, undefined, r => r.value);

    const onData = chunk => {
      input = Buffer.concat([input, Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)]);
      let index;
      while ((index = input.indexOf(10)) >= 0) {
        const record = input.subarray(0, index + 1);
        input = input.subarray(index + 1);
        let frame;
        try { frame = JSON.parse(record.toString("utf8")); }
        catch { queued.push(record); continue; }
        if (frame?.type === "extension_ui_response" && pending.has(frame.id)) {
          pending.get(frame.id)(frame);
        } else {
          queued.push(record);
        }
      }
    };
    process.stdin.on("data", onData);

    // RPC exclusively owns stdin. Its first reader marks the end of startup.
    const onNewListener = event => {
      if (event !== "data") return;
      process.stdin.removeListener("newListener", onNewListener);
      queueMicrotask(() => {
        process.stdin.removeListener("data", onData);
        Object.assign(ui, originals);
        // Wait until the native listener has actually attached before replay.
        if (queued.length || input.length) {
          process.stdin.unshift(Buffer.concat([...queued, input]));
        }
      });
    };
    process.stdin.on("newListener", onNewListener);
  });
  // After the handler above, so a Pi that does not await the factory still
  // sees it.
  await registerSesoriTools(pi);
}

async function registerSesoriTools(pi) {
  // Read once and removed from the environment, so the agent's commands do
  // not inherit the token. globalThis keeps it for a /reload of this file.
  const launch = (globalThis[Symbol.for("sesori.mcp.launch")] ??= Object.fromEntries(
    Object.entries(sesoriMcpEnvironment).map(([field, name]) => [field, process.env[name]])
  ));
  for (const name of Object.values(sesoriMcpEnvironment)) delete process.env[name];
  const { url, token, server } = launch;
  if (!url || !token || !server) return;

  const call = async (method, params, signal) => {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        accept: "application/json",
        authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ jsonrpc: "2.0", id: randomUUID(), method, params }),
      signal,
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const reply = await response.json();
    if (reply.error) throw new Error(reply.error.message);
    return reply.result;
  };

  let tools;
  try {
    ({ tools } = await call("tools/list", {}, AbortSignal.timeout(10000)));
  } catch (error) {
    console.error(`[sesori] ${server} tools are unavailable: ${error?.message ?? error}`);
    return;
  }
  for (const tool of tools) {
    pi.registerTool({
      name: `mcp__${server}__${tool.name}`,
      label: tool.title ?? tool.name,
      description: tool.description ?? "",
      parameters: tool.inputSchema,
      annotations: tool.annotations,
      async execute(_toolCallId, params, signal) {
        const result = await call("tools/call", { name: tool.name, arguments: params }, signal);
        return { content: result.content, details: {}, isError: result.isError === true };
      },
    });
  }
}
''';
