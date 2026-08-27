# Provider Route Conformance

## Capability

A configured model route preserves its declared protocol, model identity,
modalities, tools, and response semantics through the provider, coding harness,
bridge, relay, and client boundaries that claim to support them.

## Required Behavior

- Catalog or setup success proves configuration readability only. Each route is
  exercised at every capability claimed for it: text, tools, images, questions,
  permissions, streaming, and replay where applicable.
- Each protocol route is selected independently with its intended model. A
  successful fallback or cross-protocol model substitution is not a pass.
- A raw provider probe runs before Harness or Sesori participates. For tool
  routes, advertise one uniquely named disposable tool such as `sesori_probe`;
  the provider must return that exact name. Prefixing, suffixing, translating,
  or selecting an unadvertised name fails tool conformance even when the HTTP
  response and stop reason report success.
- Record response framing as well as status. A non-streaming request returned as
  an event stream is acceptable only when the configured consumer supports that
  framing and still settles exactly once.
- The Harness catalog exposes the intended provider/model pair as an available
  opaque selection, and a direct Harness turn attributes terminal output to that
  same pair.
- Tool conformance requires a real completed call and result. A model response
  that claims success after an unknown, rejected, malformed, or failed call is a
  failure.
- Image conformance uses a bounded non-sensitive fixture and verifies that the
  model interprets image content rather than a filename or prompt description.
- Question conformance requires a model-facing question producer. A composed
  question service/provider without a model-facing tool or another real
  consumer proves transport readiness, not ordinary model-initiated questions.
- Permission conformance runs with bridge auto-approval disabled and verifies
  both one-time approval and rejection without broadening either answer.
- After bridge and client restart, completed text, images, tools, message
  timestamps supplied by the backend, and terminal states replay without
  duplication or attribution drift.

## Execution Runbook

1. Declare the exact protocol and claimed capabilities for every route. Validate
   the endpoint, authentication, model, and native request shape separately so
   an invalid probe is blocked setup rather than a provider failure. Keep
   credentials in the provider's private local store; never place them in a
   command, committed fixture, screenshot, transcript, or evidence file.
2. Use a disposable prompt, image, tool, and session. Capture only bounded
   status, framing, stop reason, requested/returned tool name, provider/model
   attribution, interaction outcome, and cleanup result.
3. Probe the provider's native protocol boundary without Harness or Sesori.
   Run a text request first, then advertise only `sesori_probe` and require one
   call to it. Stop tool testing for that route if the returned name differs.
4. Refresh Harness options and verify the exact provider/model selection. Run
   one direct text turn, then the route's claimed tool and image capabilities.
5. Traverse the headless bridge boundary. Verify opaque selection round-trip,
   terminal attribution, normalized tool lifecycle, and useful local errors.
6. Traverse the release-target client -> relay -> bridge -> plugin path. Verify
   rendering and settlement for the claimed rich capabilities rather than
   treating a debug route as client evidence.
7. Restart the bridge first and inspect its headless history replay. Then restart
   the client, reopen the session, and compare durable messages, timestamps,
   parts, tool states, and model attribution at each boundary.
8. Delete disposable sessions through product APIs, restore auto-approval and
   other changed settings, remove only named proof files, and stop test-owned
   processes. Never recursively delete a provider, Harness, plugin, or user
   state root as cleanup.

## Failure Attribution

| First divergent boundary | Likely owner |
|---|---|
| Raw probe has invalid endpoint, authentication, model, or request shape | Local probe setup or provider profile |
| Valid raw provider request fails or returns a renamed/unadvertised tool | Provider, router, or selected model |
| Raw provider passes but direct Harness fails | Harness provider adapter or local profile |
| Direct Harness passes but bridge debug path fails | Backend plugin or runtime adapter |
| Bridge path passes but relay/client path fails | Bridge routing, relay, shared contract, or client |
| Live path passes but headless bridge restart replay differs | Adapter persistence/history or bridge cache mapping |
| Headless bridge replay passes but client cold-load replay differs | Client cache or merge behavior |

Do not add a downstream alias, tool-name rewrite, retry, or compatibility shim
until the first divergent boundary demonstrates that downstream code owns the
problem.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | One text route through its raw provider boundary and direct Harness selection. |
| L2 Routine | Every configured protocol route; exact tool-name probe and each route's claimed text/tool/image capabilities. |
| L3 Release | Release-target client through relay and bridge; questions and permissions for every route claiming them. |
| L4 Extended | Bridge/client restart replay, provider errors, malformed tool calls, rejection, abort, and two concurrent sessions. |
| L5 Full | Every release provider profile and advertised host/client matrix, including alternate framing and compatibility builds where claimed. |

## Failure Signals

- A route reports success under a provider, model, or protocol other than the
  one selected.
- A provider returns a tool name different from the only advertised tool.
- A failed tool is narrated as success, or a one-time permission becomes a
  standing grant.
- A model sees a filename or prompt text but not the attached image bytes.
- A question seam exists but no real model-facing consumer can raise a question.
- Rich content, timestamps, terminal state, or attribution changes after reopen.
- Committed or shared evidence contains credentials, source, prompts,
  transcripts, paths, raw provider output, account identifiers, or image bytes.
- Local diagnostics suppress useful errors, stack traces, paths, identifiers, or
  operation context instead of selectively removing known credentials, prompts,
  transcripts, or image payloads.

## Known Limitations

- Provider and model behavior can be nondeterministic. A failure should be
  reproduced at the lowest boundary before assigning ownership.
- Passing text does not imply tool, image, question, or permission support.
- A route may intentionally claim only a subset of capabilities; omitted
  capabilities are recorded as unsupported, not silently counted as passing.

## Sources

- Provider profile and model catalog contracts in the owning Harness adapter.
- `session-creation-and-options.md`, `session-turns.md`,
  `questions-and-permissions.md`, `attachments-and-images.md`, and
  `tools-and-file-changes.md`.
- Bridge debug routes, plugin option/session APIs, and release-target client
  interaction surfaces.
