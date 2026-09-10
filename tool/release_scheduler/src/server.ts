import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { pathToFileURL } from "node:url";

import { DispatchFailure, GitHubDispatcher, type DispatchResult } from "./github_dispatcher.ts";

type LogEntry = Record<string, string | number>;
type LogWriter = (entry: LogEntry) => void;
type Dispatch = () => Promise<DispatchResult>;

type HandlerOptions = {
  dispatch: Dispatch;
  writeLog: LogWriter;
};

export function createRequestHandler(options: HandlerOptions) {
  return async (request: IncomingMessage, response: ServerResponse): Promise<void> => {
    const path = request.url?.split("?", 1)[0];
    if (path === "/health") {
      if (request.method !== "GET") {
        writeJson({ response, status: 405, body: { status: "method_not_allowed" }, allow: "GET" });
        return;
      }
      writeJson({ response, status: 200, body: { status: "ok" } });
      return;
    }

    if (path !== "/dispatch") {
      writeJson({ response, status: 404, body: { status: "not_found" } });
      return;
    }
    if (request.method !== "POST") {
      writeJson({ response, status: 405, body: { status: "method_not_allowed" }, allow: "POST" });
      return;
    }

    try {
      const result = await options.dispatch();
      options.writeLog({
        severity: "INFO",
        message: "GitHub workflow dispatch accepted and run created",
        workflow_run_id: result.workflowRunId,
        run_url: result.runUrl,
        html_url: result.htmlUrl,
      });
      writeJson({
        response,
        status: 200,
        body: {
          status: "accepted",
          workflow_run_id: result.workflowRunId,
          run_url: result.runUrl,
          html_url: result.htmlUrl,
        },
      });
    } catch (error: unknown) {
      const failure = safeFailureLog(error);
      options.writeLog({
        severity: "ERROR",
        message: "GitHub workflow dispatch failed",
        ...failure,
      });
      writeJson({ response, status: 502, body: { status: "dispatch_failed" } });
    }
  };
}

export function startServer(): void {
  const dispatcher = new GitHubDispatcher();
  const handler = createRequestHandler({
    dispatch: () => dispatcher.dispatch(),
    writeLog: (entry) => console.log(JSON.stringify(entry)),
  });
  const port = readPort();
  const server = createServer((request, response) => {
    void handler(request, response);
  });
  server.listen(port, "0.0.0.0", () => {
    console.log(
      JSON.stringify({
        severity: "INFO",
        message: "Release scheduler dispatcher listening",
        port,
      }),
    );
  });
}

function safeFailureLog(error: unknown): LogEntry {
  if (!(error instanceof DispatchFailure)) {
    // Only the owning I/O boundary knows which credentials to redact.
    return {
      operation: "dispatch",
      code: "unexpected_error",
      error_name: error instanceof Error ? error.name : typeof error,
    };
  }
  const entry: LogEntry = {
    operation: error.operation,
    code: error.code,
    ...error.diagnostics,
  };
  if (error.status !== undefined) {
    entry.status = error.status;
  }
  if (error.requestId !== undefined) {
    entry.request_id = error.requestId;
  }
  return entry;
}

function writeJson(options: {
  response: ServerResponse;
  status: number;
  body: object;
  allow?: string;
}): void {
  const body = JSON.stringify(options.body);
  options.response.statusCode = options.status;
  options.response.setHeader("Content-Type", "application/json; charset=utf-8");
  options.response.setHeader("Content-Length", Buffer.byteLength(body));
  if (options.allow !== undefined) {
    options.response.setHeader("Allow", options.allow);
  }
  options.response.end(body);
}

function readPort(): number {
  const rawPort = process.env.PORT ?? "8080";
  const port = Number(rawPort);
  if (!Number.isInteger(port) || port < 1 || port > 65_535) {
    throw new Error("PORT must be an integer between 1 and 65535");
  }
  return port;
}

const entrypoint = process.argv[1];
if (entrypoint !== undefined && import.meta.url === pathToFileURL(entrypoint).href) {
  startServer();
}
