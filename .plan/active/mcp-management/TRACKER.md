# MCP management tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Branch/base: `sesori/mcp-contract-evidence`, `c03b588d9e`, in the provided `copper-heron` worktree.
- Current step: 2/12, [PR #1945](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1945) in review.
  Step-3 inventory foundations are preserved locally. Execution authorized on 2026-10-13.
- User decisions: Claude Code and Codex first; existing servers and offered connectors only; preserve an extension path
  for later server creation without implementing it now.
- Plan PR: [#1940](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1940).
- Architecture plan review: **approved** on 2026-10-13.

## Delivery

The exact titles, scope, estimates, and dependency order are in `PLAN.md`.

| Step | Outcome | State | PR/evidence |
|---|---|---|---|
| 1/12 | Publish reviewed plan | Merged | [#1940](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1940) |
| 2/12 | Freeze priority native contracts and capability evidence | PR review | [#1945](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1945); [evidence](evidence/native-contracts.md) |
| 3/12 | Claude scoped inventory and bridge contract | Local foundations in progress | Not published |
| 4/12 | Shared phone/desktop inventory and details | Not started | — |
| 5/12 | Claude actions and native authentication | Not started | — |
| 6/12 | Shared authentication and external-action presentation | Not started | — |
| 7/12 | Claude approvals and form/URL elicitation | Not started | — |
| 8/12 | Codex inventory/actions/authentication | Not started | — |
| 9/12 | Codex forms and offered connectors | Not started | — |
| 10/12 | Secondary harness support and explicit gaps | Not started | — |
| 11/12 | Reconcile regression/capability documents | Not started | — |
| 12/12 | Execute L4 plus named external/package checks; retire | Not started | — |

## Evidence and decisions

- 2026-10-13: inspected current plugin contracts, Claude process/control ownership, Codex approvals, shared
  question/permission models, client browser auth ownership, bridge routing, harness capabilities, and regression proof
  rules.
- Step-1 checks identified local Claude Code 2.1.296 and Codex 0.162.1 with version/help and schema generation only;
  those installed runtimes did not qualify the repository pins. Step 2 now probes the exact pins using isolated fixtures.
  No user MCP server was queried, connected, installed, or authorized.
- Exact target/minimum native fixture captures have passed in step 2. Real-provider OAuth, packaged clients,
  cross-host and complete bridge/relay/client checks remain **Not run** and belong to qualification.
- External documentation links and their scope are recorded in the plan. Claude terminal requirements, native
  elicitation frames, Codex callback completion, and executable released-client parsing have now been checked in step 2.
  Authenticated connector setup, production terminal support, and real mixed-client ownership remain later gates.
  The earlier source-only released-client check is retained as the step-1 checkpoint below.
- Additional product analytics events are deferred; existing screen reporting applies. No server/tool/connector
  identities enter analytics.
- No reduction of the retirement matrix has been requested or accepted.
- 2026-10-13: the user authorized implementation. Step 1 merged with 8/8 checks and no unresolved threads.
- Step 2 ran both exact minimum/target versions on macOS arm64 with isolated native configuration, stdio/HTTP MCP,
  deterministic local model output, fixture OAuth, native trust rejection, typed forms, and URL decline/unsupported.
  Details, method/version differences, and unexecuted external/packaged boundaries are in the native evidence.
- The native probes do not qualify real accounts, credential persistence, connector entitlements, other native hosts,
  bridge/relay ownership, client presentation, or the final L4 matrix. Those gates remain active.
- Public release check still identifies v1.9.0/build 970 as latest production; newer v1.9.1 builds are prereleases.
  The released SSE parser plus byte-identical codecs passed four event-order/settlement fixtures and a snapshot fixture.
  Actual mixed-client/native-owner tests remain required in steps 6/7.

## Review record

- 2026-10-13: `architecture-plan-review` approved the initial design at base `55c7d4cbba`; specificity gate passed,
  client/bridge/shared rules applied, and no architectural findings were reported. No design changes were required.
- Review explicitly leaves native method/version support, OAuth continuation behavior, connector setup URLs, and
  executable released-client event handling to step 2. It does not establish runtime feasibility or authentication.
- Initial PR #1940 review: clarified exclusion of full authorization/elicitation URLs from diagnostics, wrapped prose,
  made the delivery overview concise while retaining exact titles and scopes below it, and recorded the measured
  publication diff. Feature scope and architectural ownership were unchanged.
- Codex follow-up review: verified the current browser service cancels its previous operation, question replies carry
  only string lists, and the question modal closes before validation. The plan now requires owner-scoped browser reuse
  with a busy result, distinct server/connector inventory variants, and typed form contracts/UI that preserve invalid
  drafts. These clarify the existing scope; arbitrary server configuration remains deferred. Step 7's estimate now
  includes the explicit shared form work.
- Architecture follow-up on 2026-10-13: **approved**, comparing the revised plan against `6fe2ad9944`. The specificity
  gate passed with no findings across client, bridge, and shared boundaries. Browser ownership, distinct catalog offers,
  and typed form layers retain one native pending owner and add no credential store or server-configuration framework.
- Further Codex feedback: made the external destination policy explicit (absolute HTTPS, host, no user info) and chose
  a shared legacy cancel/upgrade notice over per-client negotiation. Source-only inspection of public v1.9.0/build 970
  at `ffa5935c8363` found the required question routes, additive-field tolerance, and unknown-SSE handling; step 2 must
  confirm that behavior in executable released-peer fixtures. Both typed and legacy views
  share one canonical request and settlement; mixed released/current client fixtures are required. Focused architecture
  review against `124e2e9abc` **approved** the compatibility projection and URL-policy ownership with no findings;
  executable runtime compatibility remains an implementation gate.
- Further review clarifications: separated the existing non-pending catalog setup result from native session consent
  requests; settings setup does not fabricate session ownership. Required capability and regression updates in each
  production PR, retaining step 11 for reconciliation. Added the dated source-only verification record below.

## Verification log

- 2026-10-13: source-only inspection of public v1.9.0/build 970, commit `ffa5935c8363`, checked
  `connection_service.dart` unknown-SSE handling, `SessionApi` question routes, generated question codecs, and
  `QuestionModal` cancellation. This supports the proposed legacy notice; it does not prove runtime compatibility.
  Step 2 must confirm old-client-only and mixed-client behavior with executable released-peer fixtures.
- Step 1: Markdown local links, 12 exact series titles, tracker order, user scope/future-creation boundaries, and staged
  `git diff --check` passed.
- Initial publication measurement on 2026-10-13: `git diff --numstat 55c7d4cbba c56bb0c02d` reported 202 additions for
  `PLAN.md` and 48 for `TRACKER.md`: two files, 250 authored additions, zero deletions, and zero generated or production
  changes. This snapshot precedes the review formatting changes. It was below the 350–650 estimate because the initial
  prose was unwrapped and the plan used two documents without per-step files; the estimate is a sizing guide, not a
  quota.
- Production tests and implementation qualification are not part of this planning-only change and remain **Not run**.
- Step 2: four native probe commands passed their protocol assertions; native Codex JSON schemas were generated for
  both pins. The released-peer runner passed on the repository's exact Dart 3.13.4 SDK. No production source changed.
- Step-2 review rerun at probe revision `1446909afb`: both Claude probes passed 12 exchanges; both Codex probes passed
  19, including app scope and `never` policy. Released-peer decoding and three focused tooling tests passed. Exact
  command/cwd/source provenance and remaining qualification gaps are recorded in the linked native evidence.
- Step-2 second review rerun at `a4d4929325` passed the same matrix with expected outcomes for every exchange, target
  URL forwarding, failed untrusted login, successful reload, and server/thread-attributed Codex OAuth completion.
- Step-2 attribution review: target Claude and both Codex pins passed at `2c291ba091`; minimum Claude passed at
  `b84d837e65` after the new assertion exposed its absent `mcp_server` field. Native tool names, target server context,
  Codex elicitation ownership, and target inventory/error/origin/capability fields are now asserted. Three tooling tests passed.
- Step-2 pagination/payload review: both Codex native probes passed at `c7cd246fbb` with three-page termination,
  exact URL elicitation mode/destination/identifier, and URL-only OAuth response assertions. Claude assertions are
  unchanged; its observed initial pending status is explicitly not a guaranteed startup state.
