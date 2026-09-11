import { createSign } from "node:crypto";
import { readFile } from "node:fs/promises";

export const GITHUB_OWNER = "sesori-ai";
export const GITHUB_REPOSITORY = "sesori_apps_monorepo";
export const GITHUB_WORKFLOW = "release-all-platforms.yml";
export const GITHUB_REF = "main";

const GITHUB_APP_ID = "4897384";
const GITHUB_INSTALLATION_ID = "160598508";
// This version removes return_run_details and always returns 200 with run IDs.
const GITHUB_API_VERSION = "2026-03-10";
const GITHUB_API_ROOT = "https://api.github.com";
const PRIVATE_KEY_PATH = "/secrets/github-app-key.pem";
const REQUEST_TIMEOUT_MS = 10_000;

type FetchRequest = (input: string | URL, init?: RequestInit) => Promise<Response>;
type ReadPrivateKey = () => Promise<string>;

type DispatcherOptions = {
  fetchRequest?: FetchRequest;
  nowSeconds?: () => number;
  readPrivateKey?: ReadPrivateKey;
};

export type DispatchResult = {
  workflowRunId: number;
  runUrl: string;
  htmlUrl: string;
};

type DispatchFailureOptions = {
  operation: string;
  code: string;
  status?: number | undefined;
  requestId?: string | undefined;
  cause?: unknown;
  diagnostics: Record<string, string>;
};

export class DispatchFailure extends Error {
  readonly operation: string;
  readonly code: string;
  readonly status: number | undefined;
  readonly requestId: string | undefined;
  readonly diagnostics: Record<string, string>;

  constructor(options: DispatchFailureOptions) {
    super(`GitHub operation failed: ${options.operation}`, { cause: options.cause });
    this.name = "DispatchFailure";
    this.operation = options.operation;
    this.code = options.code;
    this.status = options.status;
    this.requestId = options.requestId;
    this.diagnostics = options.diagnostics;
  }
}

export class GitHubDispatcher {
  readonly #fetchRequest: FetchRequest;
  readonly #nowSeconds: () => number;
  readonly #readPrivateKey: ReadPrivateKey;

  constructor(options: DispatcherOptions = {}) {
    this.#fetchRequest = options.fetchRequest ?? fetch;
    this.#nowSeconds = options.nowSeconds ?? (() => Math.floor(Date.now() / 1000));
    this.#readPrivateKey = options.readPrivateKey ?? (() => readFile(PRIVATE_KEY_PATH, "utf8"));
  }

  async dispatch(): Promise<DispatchResult> {
    const privateKey = await this.#loadPrivateKey();
    const appJwt = createAppJwt({
      appId: GITHUB_APP_ID,
      nowSeconds: this.#nowSeconds(),
      privateKey,
    });
    const installationToken = await this.#mintInstallationToken({ appJwt });
    return this.#dispatchWorkflow({ installationToken });
  }

  async #loadPrivateKey(): Promise<string> {
    try {
      return await this.#readPrivateKey();
    } catch (error: unknown) {
      throw new DispatchFailure({
        operation: "read_private_key",
        code: "private_key_unavailable",
        cause: error,
        diagnostics: describeError({ error, redactions: [] }),
      });
    }
  }

  async #mintInstallationToken(options: { appJwt: string }): Promise<string> {
    const operation = "mint_installation_token";
    const response = await this.#request({
      operation,
      url: `${GITHUB_API_ROOT}/app/installations/${GITHUB_INSTALLATION_ID}/access_tokens`,
      init: {
        method: "POST",
        headers: githubHeaders({ authorization: `Bearer ${options.appJwt}` }),
        body: JSON.stringify({
          repositories: [GITHUB_REPOSITORY],
          permissions: { actions: "write" },
        }),
      },
    });
    const json = await parseJson({ operation, response });
    if (!isRecord(json) || typeof json.token !== "string" || json.token.length === 0) {
      throw responseFailure({ operation, response, code: "invalid_response" });
    }
    return json.token;
  }

  async #dispatchWorkflow(options: { installationToken: string }): Promise<DispatchResult> {
    const operation = "dispatch_workflow";
    const response = await this.#request({
      operation,
      url:
        `${GITHUB_API_ROOT}/repos/${GITHUB_OWNER}/${GITHUB_REPOSITORY}` +
        `/actions/workflows/${GITHUB_WORKFLOW}/dispatches`,
      init: {
        method: "POST",
        headers: githubHeaders({ authorization: `Bearer ${options.installationToken}` }),
        body: JSON.stringify({
          ref: GITHUB_REF,
          inputs: { automatic: "true" },
        }),
      },
    });
    const json = await parseJson({ operation, response });
    if (
      !isRecord(json) ||
      typeof json.workflow_run_id !== "number" ||
      !Number.isSafeInteger(json.workflow_run_id) ||
      typeof json.run_url !== "string" ||
      json.run_url.length === 0 ||
      typeof json.html_url !== "string" ||
      json.html_url.length === 0
    ) {
      throw responseFailure({ operation, response, code: "invalid_response" });
    }
    return {
      workflowRunId: json.workflow_run_id,
      runUrl: json.run_url,
      htmlUrl: json.html_url,
    };
  }

  async #request(options: { operation: string; url: string; init: RequestInit }): Promise<Response> {
    let response: Response;
    try {
      response = await this.#fetchRequest(options.url, {
        ...options.init,
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      });
    } catch (error: unknown) {
      throw new DispatchFailure({
        operation: options.operation,
        code: "request_failed",
        cause: error,
        diagnostics: describeError({
          error,
          redactions: [new Headers(options.init.headers).get("Authorization")!.replace(/^Bearer /, "")],
        }),
      });
    }
    if (!response.ok) {
      void response.body?.cancel();
      throw responseFailure({ operation: options.operation, response, code: "http_error" });
    }
    return response;
  }
}

export function createAppJwt(options: { appId: string; nowSeconds: number; privateKey: string }): string {
  const header = encodeJwtPart({ alg: "RS256", typ: "JWT" });
  const payload = encodeJwtPart({
    iat: options.nowSeconds - 60,
    exp: options.nowSeconds + 9 * 60,
    iss: options.appId,
  });
  const unsignedToken = `${header}.${payload}`;
  try {
    const signer = createSign("RSA-SHA256");
    signer.update(unsignedToken);
    signer.end();
    const signature = signer.sign(options.privateKey, "base64url");
    return `${unsignedToken}.${signature}`;
  } catch (error: unknown) {
    throw new DispatchFailure({
      operation: "sign_app_jwt",
      code: "private_key_invalid",
      cause: error,
      diagnostics: describeError({ error, redactions: [options.privateKey] }),
    });
  }
}

function githubHeaders(options: { authorization: string }): Record<string, string> {
  return {
    Accept: "application/vnd.github+json",
    Authorization: options.authorization,
    "Content-Type": "application/json",
    "User-Agent": "sesori-release-scheduler",
    "X-GitHub-Api-Version": GITHUB_API_VERSION,
  };
}

function encodeJwtPart(value: object): string {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

async function parseJson(options: { operation: string; response: Response }): Promise<unknown> {
  try {
    return (await options.response.json()) as unknown;
  } catch (error: unknown) {
    throw new DispatchFailure({
      operation: options.operation,
      code: "invalid_json",
      status: options.response.status,
      requestId: readRequestId(options.response),
      cause: error,
      // JSON parser messages may quote the response body, including a token.
      diagnostics: { error_name: error instanceof Error ? error.name : typeof error },
    });
  }
}

function responseFailure(options: {
  operation: string;
  response: Response;
  code: string;
}): DispatchFailure {
  return new DispatchFailure({
    operation: options.operation,
    code: options.code,
    status: options.response.status,
    requestId: readRequestId(options.response),
    diagnostics: {},
  });
}

// Native fetch errors retain DNS/TLS details in cause. Redact credentials at
// the boundary that owns them, without discarding useful messages or frames.
function describeError(options: { error: unknown; redactions: readonly string[] }): Record<string, string> {
  const diagnostics: Record<string, string> = {};
  const errors = [options.error, options.error instanceof Error ? options.error.cause : undefined];
  for (const [index, error] of errors.entries()) {
    if (!(error instanceof Error)) continue;
    const prefix = index === 0 ? "error" : "cause";
    const fields: Record<string, string> = { name: error.name, message: error.message };
    if (error.stack !== undefined) fields.stack = error.stack;
    if ("code" in error && (typeof error.code === "string" || typeof error.code === "number")) {
      fields.code = String(error.code);
    }
    for (const [field, value] of Object.entries(fields)) {
      let redacted = value;
      for (const secret of options.redactions) {
        if (secret.length > 0) redacted = redacted.replaceAll(secret, "[REDACTED]");
      }
      diagnostics[`${prefix}_${field}`] = redacted;
    }
  }
  return diagnostics;
}

function readRequestId(response: Response): string | undefined {
  const requestId = response.headers.get("x-github-request-id");
  if (requestId === null || requestId.length > 128 || !/^[A-Za-z0-9:._-]+$/.test(requestId)) {
    return undefined;
  }
  return requestId;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
