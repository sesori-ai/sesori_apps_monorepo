import assert from "node:assert/strict";
import { spawn, execFileSync } from "node:child_process";
import { existsSync, mkdirSync, realpathSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Run from the repository root using the pinned npx commands in EVIDENCE.md.
const version = process.argv[2];
assert.ok(["0.85.1", "0.84.1"].includes(version), "Pass a supported probe version");
const binary = process.env.PATH.split(path.delimiter)
  .map((directory) => path.join(directory, "pi"))
  .find((candidate) => existsSync(candidate));
assert.ok(binary, "Run through npx --package=@earendil-works/pi-coding-agent@VERSION");
const cli = realpathSync(binary);
assert.equal(execFileSync(process.execPath, [cli, "--version"], { encoding: "utf8" }).trim(), version);
const fixture = fileURLToPath(new URL("./quota_probe_provider.ts", import.meta.url));

for (const mode of ["terminal", "recover", "exhausted"]) {
  const config = path.resolve("bridge/.dart_tool/quota-probe-" + version + "-" + mode);
  mkdirSync(config, { recursive: true });
  writeFileSync(path.join(config, "settings.json"), JSON.stringify({
    retry: { enabled: true, maxRetries: 1, baseDelayMs: 5 },
    compaction: { enabled: false },
  }));
  const child = spawn(process.execPath, [cli,
    "--mode", "rpc", "--no-session", "--no-extensions", "--no-skills",
    "--no-prompt-templates", "--no-themes", "--no-tools", "--extension", fixture,
    "--provider", "openai-codex", "--model", "quota-probe",
  ], { env: { ...process.env, PI_CODING_AGENT_DIR: config, QUOTA_PROBE_MODE: mode } });
  let buffer = "", stderr = "";
  const events = [];
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      child.kill();
      reject(new Error(`${version} ${mode} timed out: ${stderr}`));
    }, 30000);
    child.stderr.on("data", (data) => { stderr += data; });
    child.stdout.on("data", (data) => {
      buffer += data;
      while (buffer.includes("\n")) {
        const end = buffer.indexOf("\n"), line = buffer.slice(0, end);
        buffer = buffer.slice(end + 1);
        let event;
        try { event = JSON.parse(line); } catch { continue; }
        events.push(event);
        if (event.type === "agent_settled") child.kill();
      }
    });
    child.once("error", (error) => { clearTimeout(timeout); reject(error); });
    child.once("exit", (code) => {
      clearTimeout(timeout);
      if (events.some((event) => event.type === "agent_settled")) resolve();
      else reject(new Error(`${version} ${mode} exited ${code}: ${stderr}`));
    });
    child.stdin.write(JSON.stringify({
      id: "quota-fixture", type: "prompt", message: "synthetic quota protocol probe",
    }) + "\n");
  });
  const assistants = events.filter((event) => event.type === "message_end" && event.message?.role === "assistant");
  assert.equal(assistants.length, mode === "terminal" ? 1 : 2);
  assert.ok(assistants.every(({ message }) => message.provider === "openai-codex" && typeof message.timestamp === "number"));
  assert.equal(assistants.at(-1).message.stopReason, mode === "recover" ? "stop" : "error");
  assert.equal(events.filter((event) => event.type === "agent_settled").length, 1);
  const retry = events.findIndex((event) => event.type === "auto_retry_end");
  const settled = events.findIndex((event) => event.type === "agent_settled");
  if (mode === "terminal") assert.equal(retry, -1);
  else {
    assert.ok(retry >= 0 && retry < settled);
    assert.equal(events[retry].success, mode === "recover");
  }
  const sequence = events.filter((event) => [
    "agent_start", "message_end", "agent_end", "auto_retry_start", "auto_retry_end", "agent_settled",
  ].includes(event.type)).map(({ type, willRetry, success, message }) => ({
    type, willRetry, success,
    ...(message?.role === "assistant" ? {
      provider: message.provider, stopReason: message.stopReason,
      timestampType: typeof message.timestamp,
    } : {}),
  }));
  console.log(JSON.stringify({ version, mode, result: "PASS", sequence }));
}
