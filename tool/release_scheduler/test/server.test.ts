import assert from "node:assert/strict";
import { createServer, request as httpRequest, type Server } from "node:http";
import type { AddressInfo } from "node:net";
import test, { type TestContext } from "node:test";

import { DispatchFailure } from "../src/github_dispatcher.ts";
import { createRequestHandler } from "../src/server.ts";

test("GET /health reports readiness without dispatching", async (context) => {
  let dispatchCount = 0;
  const server = await serve(context, {
    dispatch: async () => {
      dispatchCount += 1;
      throw new Error("unexpected dispatch");
    },
    writeLog: () => undefined,
  });

  const response = await fetch(`${server}/health`);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: "ok" });
  assert.equal(dispatchCount, 0);
});

test("POST /dispatch reports created workflow run and logs bounded identifiers", async (context) => {
  const logs: Array<Record<string, string | number>> = [];
  const server = await serve(context, {
    dispatch: async () => ({
      workflowRunId: 42,
      runUrl: "https://api.github.com/repos/sesori-ai/sesori_apps_monorepo/actions/runs/42",
      htmlUrl: "https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/42",
    }),
    writeLog: (entry) => logs.push(entry),
  });

  const response = await fetch(`${server}/dispatch`, { method: "POST" });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    status: "accepted",
    workflow_run_id: 42,
    run_url: "https://api.github.com/repos/sesori-ai/sesori_apps_monorepo/actions/runs/42",
    html_url: "https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/42",
  });
  assert.equal(logs.length, 1);
  assert.equal(logs[0]?.workflow_run_id, 42);
});

test("dispatch failure omits secret and upstream response body details", async (context) => {
  const logs: Array<Record<string, string | number>> = [];
  const server = await serve(context, {
    dispatch: async () => {
      throw new DispatchFailure({
        operation: "mint_installation_token",
        code: "http_error",
        status: 401,
        requestId: "ABCD:1234",
        cause: new Error("private-key-and-upstream-body-must-not-appear"),
        diagnostics: { error_name: "TypeError", cause_code: "ENOTFOUND", cause_message: "api.github.com [REDACTED]" },
      });
    },
    writeLog: (entry) => logs.push(entry),
  });

  const response = await fetch(`${server}/dispatch`, { method: "POST" });
  const responseBody = await response.text();

  assert.equal(response.status, 502);
  assert.equal(responseBody, '{"status":"dispatch_failed"}');
  assert.deepEqual(logs, [
    {
      severity: "ERROR",
      message: "GitHub workflow dispatch failed",
      operation: "mint_installation_token",
      code: "http_error",
      status: 401,
      request_id: "ABCD:1234",
      error_name: "TypeError",
      cause_code: "ENOTFOUND",
      cause_message: "api.github.com [REDACTED]",
    },
  ]);
  assert.doesNotMatch(JSON.stringify(logs) + responseBody, /private-key|upstream-body/);
});

test("malformed absolute-form targets return 404 without rejecting the handler", async (context) => {
  const server = await serve(context, {
    dispatch: async () => assert.fail("Unknown routes must not dispatch"),
    writeLog: () => undefined,
  });

  const status = await new Promise<number | undefined>((resolve, reject) => {
    const request = httpRequest(server, { path: "http://[", method: "GET" }, (response) => {
      response.resume();
      resolve(response.statusCode);
    });
    request.on("error", reject);
    request.end();
  });
  assert.equal(status, 404);
  assert.equal((await fetch(`${server}/health?probe=1`)).status, 200);
});

type HandlerOptions = Parameters<typeof createRequestHandler>[0];

async function serve(context: TestContext, options: HandlerOptions): Promise<string> {
  const handler = createRequestHandler(options);
  const server = createServer((request, response) => {
    void handler(request, response);
  });
  await listen(server);
  context.after(() => close(server));
  const address = server.address() as AddressInfo;
  return `http://127.0.0.1:${address.port}`;
}

async function listen(server: Server): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
}

async function close(server: Server): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    server.close((error) => (error === undefined ? resolve() : reject(error)));
  });
}
