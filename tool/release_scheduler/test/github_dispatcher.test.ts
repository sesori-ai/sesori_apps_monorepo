import assert from "node:assert/strict";
import { generateKeyPairSync, verify } from "node:crypto";
import test from "node:test";

import {
  DispatchFailure,
  GITHUB_REF,
  GITHUB_REPOSITORY,
  GITHUB_WORKFLOW,
  GitHubDispatcher,
} from "../src/github_dispatcher.ts";

const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
const privateKeyPem = privateKey.export({ format: "pem", type: "pkcs8" }).toString();

test("mints a repository-scoped token and dispatches fixed automatic workflow", async () => {
  const calls: Array<{ url: string; init: RequestInit }> = [];
  const fetchRequest = async (input: string | URL, init: RequestInit = {}): Promise<Response> => {
    calls.push({ url: input.toString(), init });
    if (calls.length === 1) {
      return Response.json({ token: "installation-token" }, { status: 201 });
    }
    return Response.json(
      {
        workflow_run_id: 123456789,
        run_url: "https://api.github.com/repos/sesori-ai/sesori_apps_monorepo/actions/runs/123456789",
        html_url: "https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/123456789",
      },
      { status: 200 },
    );
  };
  const dispatcher = new GitHubDispatcher({
    fetchRequest,
    nowSeconds: () => 2_000_000_000,
    readPrivateKey: async () => privateKeyPem,
  });

  const result = await dispatcher.dispatch();

  assert.equal(result.workflowRunId, 123456789);
  assert.equal(calls.length, 2);
  const tokenCall = requiredCall(calls, 0);
  assert.equal(tokenCall.url, "https://api.github.com/app/installations/160598508/access_tokens");
  assert.equal(tokenCall.init.method, "POST");
  assert.deepEqual(JSON.parse(requiredBody(tokenCall.init)), {
    repositories: [GITHUB_REPOSITORY],
    permissions: { actions: "write" },
  });
  const tokenHeaders = new Headers(tokenCall.init.headers);
  assert.equal(tokenHeaders.get("x-github-api-version"), "2026-03-10");
  const authorization = tokenHeaders.get("authorization");
  if (authorization === null || !authorization.startsWith("Bearer ")) {
    assert.fail("Expected Bearer App JWT");
  }
  const jwt = authorization.slice("Bearer ".length);
  const jwtParts = jwt.split(".");
  assert.equal(jwtParts.length, 3);
  const payload = JSON.parse(Buffer.from(requiredString(jwtParts, 1), "base64url").toString()) as unknown;
  assert.deepEqual(payload, { iat: 1_999_999_940, exp: 2_000_000_540, iss: "4897384" });
  assert.equal(
    verify(
      "RSA-SHA256",
      Buffer.from(`${requiredString(jwtParts, 0)}.${requiredString(jwtParts, 1)}`),
      publicKey,
      Buffer.from(requiredString(jwtParts, 2), "base64url"),
    ),
    true,
  );

  const dispatchCall = requiredCall(calls, 1);
  assert.equal(
    dispatchCall.url,
    `https://api.github.com/repos/sesori-ai/${GITHUB_REPOSITORY}/actions/workflows/${GITHUB_WORKFLOW}/dispatches`,
  );
  assert.equal(new Headers(dispatchCall.init.headers).get("authorization"), "Bearer installation-token");
  assert.deepEqual(JSON.parse(requiredBody(dispatchCall.init)), {
    ref: GITHUB_REF,
    inputs: { automatic: "true" },
  });
  assert.ok(dispatchCall.init.signal instanceof AbortSignal);
});

test("reports bounded GitHub failure metadata without retrying or retaining response body", async () => {
  let callCount = 0;
  const dispatcher = new GitHubDispatcher({
    fetchRequest: async () => {
      callCount += 1;
      return new Response("sensitive upstream response body", {
        status: 401,
        headers: { "x-github-request-id": "ABCD:5678" },
      });
    },
    readPrivateKey: async () => privateKeyPem,
  });

  await assert.rejects(dispatcher.dispatch(), (error: unknown) => {
    assert.ok(error instanceof DispatchFailure);
    assert.equal(error.operation, "mint_installation_token");
    assert.equal(error.code, "http_error");
    assert.equal(error.status, 401);
    assert.equal(error.requestId, "ABCD:5678");
    assert.doesNotMatch(JSON.stringify(error), /sensitive upstream response body/);
    return true;
  });
  assert.equal(callCount, 1);
});

test("network failures retain DNS diagnostics and redact the authorization credential", async () => {
  let credential = "";
  const dispatcher = new GitHubDispatcher({
    readPrivateKey: async () => privateKeyPem,
    fetchRequest: async (_input, init) => {
      credential = new Headers(init?.headers).get("authorization")!.slice("Bearer ".length);
      const cause = Object.assign(new Error(`getaddrinfo ENOTFOUND api.github.com; token=${credential}`), {
        code: "ENOTFOUND",
      });
      throw new TypeError("fetch failed", { cause });
    },
  });

  await assert.rejects(dispatcher.dispatch(), (error: unknown) => {
    assert.ok(error instanceof DispatchFailure);
    assert.equal(error.diagnostics.error_name, "TypeError");
    assert.equal(error.diagnostics.cause_code, "ENOTFOUND");
    assert.match(error.diagnostics.cause_message!, /api.github.com; token=\[REDACTED\]/);
    assert.match(error.diagnostics.error_stack!, /fetch failed/);
    assert.ok(!JSON.stringify(error.diagnostics).includes(credential));
    assert.ok(error.cause instanceof TypeError);
    return true;
  });
});

test("malformed keys retain signing diagnostics without logging key material", async () => {
  const malformedKey = "malformed-private-key-material";
  const dispatcher = new GitHubDispatcher({
    readPrivateKey: async () => malformedKey,
    fetchRequest: async () => assert.fail("Invalid keys must not make HTTP requests"),
  });

  await assert.rejects(dispatcher.dispatch(), (error: unknown) => {
    assert.ok(error instanceof DispatchFailure);
    assert.equal(error.operation, "sign_app_jwt");
    assert.equal(error.code, "private_key_invalid");
    assert.ok(error.diagnostics.error_message);
    assert.match(error.diagnostics.error_stack!, /createAppJwt/);
    assert.ok(!JSON.stringify(error.diagnostics).includes(malformedKey));
    assert.ok(error.cause instanceof Error);
    return true;
  });
});

test("invalid JSON diagnostics omit parser messages that quote response bodies", async () => {
  const dispatcher = new GitHubDispatcher({
    readPrivateKey: async () => privateKeyPem,
    fetchRequest: async () => new Response('upstream-sensitive-token-not-json', { status: 201 }),
  });

  await assert.rejects(dispatcher.dispatch(), (error: unknown) => {
    assert.ok(error instanceof DispatchFailure);
    assert.equal(error.code, "invalid_json");
    assert.deepEqual(error.diagnostics, { error_name: "SyntaxError" });
    assert.ok(error.cause instanceof SyntaxError);
    return true;
  });
});

function requiredCall(
  calls: Array<{ url: string; init: RequestInit }>,
  index: number,
): { url: string; init: RequestInit } {
  const call = calls[index];
  assert.ok(call);
  return call;
}

function requiredBody(init: RequestInit): string {
  if (typeof init.body !== "string") {
    assert.fail("Expected string request body");
  }
  return init.body;
}

function requiredString(values: string[], index: number): string {
  const value = values[index];
  assert.ok(value);
  return value;
}
