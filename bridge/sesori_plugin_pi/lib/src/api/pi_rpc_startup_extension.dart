/// Loaded before user extensions so startup dialogs can receive RPC replies.
///
/// Pi 1.0.4 awaits `session_start` before attaching its stdin reader. A startup
/// dialog otherwise waits forever or lets Node exit, even when Sesori replies.
/// This extension owns only that gap; native RPC owns all subsequent input/UI.
const piRpcStartupExtensionSource = r'''
import { randomUUID } from "node:crypto";
import { writeSync } from "node:fs";

export default function (pi) {
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
}
''';
