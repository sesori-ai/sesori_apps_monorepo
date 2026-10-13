# Priority MCP contract evidence

Date: 2026-10-13. Implementation base: `c03b588d9e`. Host: macOS arm64.
Measured executable probe revision: `1446909afb` (rerun after review fixes).
This record establishes native protocol behavior, not released Sesori support.

## Exact executables

Official npm platform packages were unpacked in temporary storage. No global
runtime was upgraded. Each executable's `--version` matched its requested pin.

| Harness | Version | Role | Executable SHA-256 |
|---|---|---|---|
| Claude | 2.1.221 | Minimum PATH | `7a181f36ed0fc4fbac6cee4ecf2b615eff93d8b434221fff5d7c878dc5ebf380` |
| Claude | 2.1.291 | Target | `9a1d2ed6bb4421e8fc80c892c0413f293be3ee50ae3d7dda1a7622197a056690` |
| Codex | 0.139.0 | Minimum PATH | `c6ede9ef9b672ef5a99384e507bec5476cbb60934c03f19cbd0355d9fdd83915` |
| Codex | 0.160.1 | Managed target | `09fa44fdc37a5fc70dc1ace31235f90468a2e193d0e85f7552eab068ea2582be` |

Packages: `@anthropic-ai/claude-code-darwin-arm64@<version>` and
`@openai/codex@<version>-darwin-arm64`. Probe entry points:
[native runner](../../../../tool/mcp-contracts/probe.mjs),
[fixture servers](../../../../tool/mcp-contracts/fixture.mjs),
[released-peer runner](../../../../tool/mcp-contracts/released-peer.mjs).

## Native capability matrix

All four native probes passed assertions using isolated stdio and HTTP servers.
Claude additionally used a deterministic local Anthropic protocol fixture; no
prompt was sent to a model provider. Codex direct MCP calls needed no model turn.

| Native boundary | Claude 2.1.221 | Claude 2.1.291 | Codex 0.139.0 | Codex 0.160.1 |
|---|---|---|---|---|
| Scoped inventory | Resident process | Resident process | Thread or app | Thread or app |
| Tool discovery | Names/annotations | Names/annotations | Full tool metadata | Full tool metadata |
| Connection state | Native status | Native status | Not in status DTO | Native `runtimeStatus` |
| Safe HTTP origin | Must derive from native config | Must derive from native config | Not in status DTO | `httpOrigin` |
| Enable/disable | Live-process `mcp_toggle` | Same | No dedicated RPC | No dedicated RPC |
| Reconnect | `mcp_reconnect` | Same | Whole-config reload RPC | Same |
| Form elicitation | Forwarded | Forwarded | Forwarded | Forwarded |
| URL elicitation | Native rejects before forwarding | Forwarded | Forwarded | Forwarded |
| OAuth completion | CLI with terminal | Same | URL plus completion notification | Same, optional thread context |
| OAuth native attempt ID | None; owned CLI process | Same | None | None |
| Connector catalog | Not exercised | Not exercised | Empty unauthenticated `app/list` | Same |

Claude status initially reports `pending`, reports `disabled` after a toggle,
and reports `connected` with all three fixture tools after reconnect. Native
config is included in this reply: production mapping must selectively omit
commands, arguments, environment, headers, and endpoint paths/query/user info.
The toggle affects the resident process; it is not evidence of persistent
configuration enablement. Unknown server and unknown subtype return control
errors. Native status tools lack descriptions even when the fixture advertises
them; absence must remain honest.

Claude sends `can_use_tool` with `mcp_server`, tool name, input, and native
permission suggestions. Both versions independently ask before all three tools.
Forms use `subtype: elicitation`, `mcp_server_name`, `requested_schema`, and typed
`{action, content}` responses. The boolean, integer, choice value distinct from
its label, optional-field omission, and bounded string-array values round-trip
without flattening. Target URL requests use `url` and `elicitation_id`. Minimum
URL requests return MCP error `-32602`, “Client does not support URL-mode
elicitation requests”; the bridge cannot present a request it never receives.

Claude project `.mcp.json` login fails explicitly while awaiting trust approval.
After explicit native setup of only the fixture server, `mcp login --no-browser`
in a pseudo-terminal prints a URL, accepts the pasted native callback, and exits
successfully on both versions. A plain pipe emits only startup text and remains
blocked through the bounded ten-second check. The production authentication
boundary needs a terminal-capable native process; Python is not that boundary.
Any new PTY dependency and supported-host behavior must be qualified in step 5.

Codex paginated status returns every configured fixture exactly once when each
page requests one server. A separate no-thread read returns the same configured
server names. Minimum status has no connection-state/discovery-error
fields: do not infer that an empty tool map means an empty successful catalog.
Target adds `runtimeStatus`, `toolsError`, `httpOrigin`, and server capabilities.
The minimum login request accepts a server name; target adds optional thread
context. Both return only `authorizationUrl`, then
`mcpServer/oauthLogin/completed` identifies the server and success; target can
include `threadId`. The plan's anticipated native attempt ID does not exist at
these pins. The bridge owns its operation identity and native callback lease.

Codex fixture OAuth succeeds after its exact loopback callback receives the
fixture state/code. There is no MCP callback-completion or cancel RPC in either
generated request schema. The adapter must bind continuation to the issued
callback and retain ownership through native completion/expiry; cancelling UI
alone cannot imply that the native listener stopped. No provider-account login
RPC may be substituted for MCP login. Stdio OAuth returns an explicit error.

Codex requests preserve `serverName`, `threadId`, nullable `turnId`, and distinct
form/URL modes. Native replies retain boolean/integer/choice/array typing; URL
decline reaches the fixture. With approval policy `never`, Codex declines these
requests itself; interactive delivery uses `on-request`. Target also has
`openai/userVerification`, `openai/form`, and `openaiForm` schema variants: their
mere presence is not generic-form support. Unsupported native schemas must
receive the deliberate unsupported/decline path, not a guessed grant.

Neither empty catalog response proves authenticated connector metadata or a
working install URL. Connector availability/setup remains gated by its native
catalog; no test installs a plugin or uses the under-development install APIs.

## Released-client boundary

Public v1.9.0/build 970, commit `ffa5935c8363c6429fdf2e3c3fb95b3a906f5ab5`:
the released SSE parsing methods were executed with matching question and
SSE model/generated codecs (LF/CRLF normalized). Four combinations of typed-first/legacy-first and
completion/cancel passed, plus pending snapshot notice decoding. Unknown typed
events are skipped; additive notice fields are ignored; legacy question text,
custom-disabled behavior, attribution, and settlement IDs remain intact.

This is an executable wire-parser fixture, not a packaged old app or production
mixed-client proof. Steps 6/7 must test one canonical native pending owner,
modern/legacy presentation, competing replies, cancellation, and snapshot
recovery after the real typed interactions exist.

## Reproduction and measured results

Run from the repository root at probe revision `1446909afb`; dependencies were
resolved in `shared/sesori_shared` using Dart 3.13.4. Native fixture subprocess
cwd is a fresh temporary directory chosen by `mkdtemp`, not the checkout or the
developer's project. The released-peer Dart cwd is `shared/sesori_shared`.
The following exact commands used the temporary executables hashed above:

```sh
node tool/mcp-contracts/probe.mjs claude \
  /private/tmp/copper-heron-mcp-runtimes/claude-2.1.221/claude \
  /private/tmp/copper-heron-mcp-runtimes/claude-min.json
node tool/mcp-contracts/probe.mjs claude \
  /private/tmp/copper-heron-mcp-runtimes/claude-2.1.291/claude \
  /private/tmp/copper-heron-mcp-runtimes/claude-target.json
node tool/mcp-contracts/probe.mjs codex \
  /private/tmp/copper-heron-mcp-runtimes/codex-0.139.0/codex \
  /private/tmp/copper-heron-mcp-runtimes/codex-min.json
node tool/mcp-contracts/probe.mjs codex \
  /private/tmp/copper-heron-mcp-runtimes/codex-0.160.1/codex \
  /private/tmp/copper-heron-mcp-runtimes/codex-target.json
node tool/mcp-contracts/released-peer.mjs \
  /private/tmp/copper-heron-mcp-runtimes/dart-sdk/bin/dart
node --test tool/mcp-contracts/fixture.test.mjs \
  tool/mcp-contracts/released-peer.test.mjs tool/mcp-contracts/terminal.test.mjs
```

| Command | Result at measured revision |
|---|---|
| Claude minimum | Exit 0; 12 native exchanges; all assertions passed |
| Claude target | Exit 0; 12 native exchanges; all assertions passed |
| Codex minimum | Exit 0; 19 native exchanges; all assertions passed |
| Codex target | Exit 0; 19 native exchanges; all assertions passed |
| Released peer | Exit 0; four event-order/settlement cases plus snapshot passed |
| Tooling tests | Exit 0; three tests passed |

The Codex reruns include app scope and explicit `never`-policy form/URL decline.
They assert stdio OAuth rejection and an empty successful unauthenticated
catalog. Claude asserts unknown-server reconnect rejection and the ten-second
plain-pipe timeout without a URL. HTTP fixtures advertise only echo; form/URL
elicitation and exact typed replies are exercised through stdio. None of these
checks establish HTTP elicitation support or real external provider behavior.

## Remaining qualification

Not run: Linux/Windows native probes, real OAuth/provider policy, native
credential persistence across restart, authenticated offered connectors,
packaged browser returns, full bridge/relay/client journeys, and device feel.
These retain their gates in the plan. Scalar validation and draft correction
belong to the production form boundary in step 7; the native round trip alone
does not supply that product validation.
