# MCP management tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Branch/base: `sesori/mcp-archive-rejection`, `0ed5a42b81`, in the provided `copper-heron` worktree.
- Current step: 8/16, canonical archived-control rejection in progress;
  live Claude controls merged as [#1952][pr-1952].
  Client loading merged as #1949; Claude inventory API merged as #1948. Execution authorized on 2026-10-13.
- User decisions: Claude Code and Codex first; existing servers and offered connectors only; preserve an extension path
  for later server creation without implementing it now.
- Plan PR: [#1940](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1940).
- Architecture plan review: **approved** on 2026-10-13.

## Delivery

The exact titles, scope, estimates, and dependency order are in `PLAN.md`.

| Step | Outcome | State | PR/evidence |
|---|---|---|---|
| 1/16 | Publish reviewed plan | Merged | [#1940](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1940) |
| 2/16 | Native contracts | Merged | [#1945][pr-1945] |
| 3/16 | Inventory foundation (original 3.a) | Merged | [#1947][pr-1947]; six codec tests |
| 4/16 | Claude scoped inventory and bridge read (original 3.b) | Merged | [#1948][pr-1948] |
| 5/16 | Client inventory lifecycle (original 5.a) | Merged | [#1949][pr-1949] |
| 6/16 | Shared phone/desktop inventory and details (original 5.b) | Merged | [#1950][pr-1950] |
| 7/16 | Claude live-server controls (original 7.a) | Merged | [#1952][pr-1952] |
| 8/16 | Canonical archived-control rejection | In progress | Late #1952 feedback |
| 9/16 | Claude native authentication (original 7.b) | Draft paused | Native terminal/login draft preserved in stash |
| 10/16 | Shared authentication and external-action presentation | Not started | — |
| 11/16 | Claude approvals and form/URL elicitation | Not started | — |
| 12/16 | Codex inventory/actions/authentication | Not started | — |
| 13/16 | Codex forms and offered connectors | Not started | — |
| 14/16 | Secondary harness support and explicit gaps | Not started | — |
| 15/16 | Reconcile regression/capability documents | Not started | — |
| 16/16 | Execute L4 plus named external/package checks; retire | Not started | — |

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
  Actual mixed-client/native-owner tests remain required in steps 10/11.

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
  drafts. These clarify the existing scope; arbitrary server configuration remains deferred. Step 10's estimate now
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
  production PR, retaining step 15 for reconciliation. Added the dated source-only verification record below.

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

- Step 3 split: original 3.a/3.b map to PR ordinals 3/4; later ordinals shift by one, with 13 total. The merged
  plan PR #1940 now uses the current 14-step total; its squash commit is unchanged.
  No feature scope or architecture decision changed.
- Step-3 foundation: four shared wire tests and shared/interface analyzers passed on exact Dart 3.13.4. No runtime
  endpoint or adapter is exposed yet. No old owner, cache, route, or persisted model is superseded at this boundary.
- Step-3 pre-publication measurement: 1,679 generated lines and 470 authored lines (2,149 total before this record),
  including plan/doc churn. Keep generated codecs with their source as the soft-cap exception; the adapter/read
  flow is split into step 4. No persistence, runtime lifecycle, or user-visible behavior changes in step 3.
- Step-3 architecture implementation review: **approved** against staged HEAD `2412bcd3da`, applying Bridge and
  Shared rules. No findings; optional plugin ownership and backend-neutral contracts were preserved.
- Step-2 final review at `992af36665`: all four native pins passed; unexpected version is rejected before fixture
  servers open, target Claude URL/identifier are asserted, and both Claude pins reject wrong-state callbacks without
  exchanging a token before a fresh valid login succeeds. Minimum exits; target rejects and reprompts until bounded
  cancellation. Four tooling tests passed. Split metadata is now published in step 2 to match its 13-step PR title.
- Step-2 grant/ownership/refresh review at `2e52cf2b23`: all four probes passed with exact Claude native grant
  suggestions and elicitation subtype/server ownership, plus refreshed Codex OAuth/tool state and target connected
  status without discovery error. The unsupported-version test passed after decoding its script file URL. The codec
  regression document begins in step 3; live inventory coverage begins in step 4.
- Step-2 side-effect review at `ed6083f41b`: both Claude pins passed 13 exchanges with an independent enablement
  read; both Codex pins passed 22 with changed-config reload visible in app/live-thread inventory and wrong-state
  callback rejected without token exchange before fresh success. Negative Codex callback HTTP200 still reports
  native failure. Codex JSONL framing follows the official header-omitting protocol, rather than strict MCP framing.
- Step 2 merged as PR #1945 after all actionable bot findings were addressed, current-head reviews settled, and
  required CI passed. Step 3 rebased onto `2c70025d8f`; neither owning production package changed on main, so the
  existing focused tests/analyzers and architecture approval remain applicable. Foundation measurement before this
  tracker update: 291 authored production/test and 1,679 generated lines (1,970 total excluding docs). No obsolete runtime owner or stored data exists
  to remove in this contract-only step.

[pr-1945]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1945
[pr-1947]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1947

Native evidence: [contract captures](evidence/native-contracts.md).

- Step-3 Codex review added independent server/connector section availability and
  graceful unknown response enum/union parsing. Six wire tests and shared plus
  plugin-interface analysis passed; request scopes/targets remain intentionally
  closed. No published MCP peer needs a legacy field default.

- Step 4: Claude mapper/resident-process suite passed (17 tests), and bridge MCP
  route suite passed (7 tests). Exact Dart 3.13.4 analysis passed for Claude and
  bridge app. Tests cover safe metadata, truthful discovery state, no implicit
  spawn, durable owner/native-ID binding, moved project path, and explicit
  unavailable states. Architecture implementation review approved the staged
  step-4 flow. Production resident-process adapter smoke passed with isolated
  stdio fixture on Claude 2.1.221 and 2.1.291: inactive read spawned nothing,
  one explicit launch returned connected state and the echo tool. Initial smoke
  used a missing Node path; reruns with the installed executable passed. A real
  relay/client route smoke remains unexecuted.

- Step 4 updated in lockstep with the reviewed section-availability contract.
  The bridge route also proves readable offered connectors survive server-section
  failure and retain bridge-owned target scope. Claude tests remain 17 passing,
  route tests are now 7 passing, and affected analysis is clean.

- Step 3 merged as #1947 after both current-head reviews completed with no
  remaining findings and required CI passed. Step 4 rebased onto `a708a3a84e`;
  owning bridge/Claude package contents on main match the reviewed foundation
  base, so focused verification remains applicable. No prior cache, route,
  persistence or runtime owner is superseded by this additive read flow.

[pr-1948]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1948

- Step-4 review: stdio transport no longer implies authentication is unnecessary.
  Known control rejection/process-exit/timeout errors retain typed causes/stacks
  in the plugin result, log once at the bridge repository, and emit only a safe
  read-failed wire state. Archived inventory remains a read-only operation.
  Claude mapper/process/control tests passed (47); bridge route tests passed (9);
  shared codec tests passed (6). All four affected packages analyze cleanly.

- Original step 5 split into 5.a client lifecycle (ordinal 5) and 5.b UI (ordinal 6).
  One PR remains open with one local successor. New per-view state ownership is
  independently testable before presentation: 9 lifecycle and 3 repository tests
  pass on the pinned Flutter/Dart SDK. No scope expansion or database change.

- Step-4 teardown review: disposal now completes pending native controls with
  ClaudeControlException at the stream-client boundary. The inventory repository
  keeps its narrow catch and maps teardown to safe readFailed state without
  swallowing unrelated StateError bugs. Focused Claude tests passed (48);
  Claude analysis passed. Original step 5 is now two PRs, with total 14.

- Step 5.a local verification was an uncommitted run on `53f16cb004` plus
  the client changes later committed as `f7acf6da27` (before the main rebase).
  Commands: the two focused files via `dart test` from `client/module_core`,
  and `dart analyze` from core, mobile, and desktop. Twelve tests passed;
  core, mobile, and desktop analyze cleanly on Flutter 3.47.5 / Dart 3.13.4.
  Full core DI generation changed only the intended registrations. Per-view
  service ownership avoids a shared inventory cache; no prior persistence,
  listener, or lifecycle owner becomes obsolete. This step exposes no UI or
  analytics action; screen reporting remains with the following UI step.
  Real relay/client and packaged qualification remain pending.
- Step 5.a architecture implementation review: **approved** for the client
  additions against `53f16cb004`; no findings in layering, DI ownership,
  lifecycle ownership, or shared boundaries. Prior Claude changes were excluded.

- Step 4 merged as #1948 after current-head Codex completed without new findings,
  Cubic approved, and all 32 required checks passed. Step 5.a rebased onto
  `120a438770`; client package contents are unchanged from the uncommitted run above,
  so the focused tests, code generation, and downstream analysis remain applicable.

[pr-1949]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1949

- Step 5.a review verification was uncommitted on `d668256344`: 19 focused
  service/repository tests and core analysis passed from `client/module_core`.
  HTTP 404 and unrecognized refreshes preserve readable snapshots with distinct
  states. Two single-signal failure tests prove reconnect re-arms reads without
  another stale signal; failed state remains visible without scheduled polling.
  The original verification provenance is now explicitly recorded above.
- Step 5.a second architecture review: **approved** against `120a438770`
  through `d668256344` plus these uncommitted fixes; no architectural findings.

- Step 5.a merged as #1949 after current-head Codex completed without new
  findings, Cubic approved, and all required checks passed. Step 6 rebased onto
  `d3a4dfb8e7`; the client contents match the validated parent.
- Step 6 initial verification was uncommitted on `d3a4dfb8e7`, later committed
  as `f1fd4bce10`: five focused MCP widget
  tests pass, including unknown states, stable refresh scroll position, and
  phone width at 2x text. The unchanged harness settings suite passed 28 tests
  earlier in this step. Shared UI/mobile/desktop analyzers are clean.
  The account-free native fixture builds on macOS 27.0.1 / Xcode 27.0 with
  Flutter 3.47.5. Its generated bundle has a unique identity and no URL schemes.
  Initial automation was blocked by macOS authentication; the user confirmed
  it is finished, and the native visual checks below passed.
- Step 6 architecture implementation review: **approved** for the new shared
  presentation and shell composition against `d3a4dfb8e7`; no findings.
- Native step-6 fixture checks passed after unlock: inventory opening, server
  details, Escape/close return, long-list scroll, failed refresh retaining rows,
  and final close. The underlying fixture content is pixel-identical after
  closing. Original captures/recordings remain private under `/private/tmp`;
  public media contains only synthetic fixture data and a cropped app region.
  The public GIF removes idle intervals while retaining action speed. The
  automation session and owned fixture process were closed; pre-existing Sesori
  PID 7903 remains untouched. This is fake inventory/service UI evidence, not
  live relay, provider, device, packaging, or GPU/performance qualification.
- Step 6 adds no new route or product analytics event. Existing screen reporting
  stays intact; inventory reads do not answer a separate adoption decision.
  No prior UI, persisted state, watcher, or compatibility path is superseded.
- Public step-6 media is on `pr-media` at `1e829e0f9a` under
  `sesori/mcp-inventory-presentation/`: closed/open/details PNGs and a 21.3-second
  cropped GIF. The complete public artifact was visually checked before upload.

[pr-1950]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1950

- Step-6 review fixes were verified uncommitted on `f1fd4bce10`, then
  committed as `d8aad49ec6`: archived mobile sessions
  retain read-only inventory, offline Refresh is disabled, details show refresh
  status and distinguish a removed server from a failed read. Eight focused MCP
  widget tests pass; shared UI, mobile and desktop analyze cleanly. The second
  and final architecture implementation review approved these changes.
- Reproducible step-6 commands (all paths relative to this worktree):
  - SDK: `/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.5-stable/bin/flutter`
    (`flutter` below), with bundled `bin/cache/dart-sdk/bin/dart` (`dart` below).
  - `client/module_app_ui`: `flutter gen-l10n`;
    `flutter test test/features/mcp/mcp_inventory_view_test.dart --no-pub --reporter expanded`
    (eight passing after review fixes). Initial five-test run used the same test
    file; `flutter test test/features/settings/harnesses_settings_view_test.dart`
    passed 28 tests before the review fixes; that settings implementation is unchanged.
  - `client/module_app_ui`, `client/app`, `client/desktop`:
    `dart analyze --fatal-infos` (all clean after review fixes).
  - `client/desktop`: `flutter build macos --debug --target tool/mcp_inventory_fixture.dart --no-pub`.
    Before launch, generated bundle metadata is assigned the fixture-only identity
    `ai.sesori.fixture.mcp.copper-heron` and its URL schemes are removed;
    `codesign --force --deep --sign - --preserve-metadata=entitlements build/macos/Build/Products/Debug/Sesori.app`
    and `codesign --verify --deep --strict build/macos/Build/Products/Debug/Sesori.app`.
  - Worktree root: `open -na <absolute-worktree>/client/desktop/build/macos/Build/Products/Debug/Sesori.app`;
    `agent-device open ai.sesori.fixture.mcp.copper-heron --platform macos --surface app --foreground --session mcp-copper-heron --json`.
    `agent-device screenshot <private-png> --session mcp-copper-heron --json`
    captures fixture-only states; `peekaboo click --app ai.sesori.fixture.mcp.copper-heron --at <window-coordinates> --foreground --input-strategy synthOnly --json --no-remote`
    and `peekaboo press Escape --app ai.sesori.fixture.mcp.copper-heron --foreground --input-strategy synthOnly --json --no-remote`
    exercise the flow. Artifacts remain private; inspected app crops alone are published.

- Native review-fix verification passed for the revised detail header, failed
  refresh retaining content, returning to inventory and closing both layers.
  The underlying reading area is pixel-identical after closing; the entry button
  differs only by hover feedback. Intermittent native automation refusal required
  observing before retry; no refused action is counted as success. The fixture
  and recording were closed; original Sesori PID 7903 remains alive.
- Revised synthetic detail PNGs and the 2.4-second refresh GIF are published on
  `pr-media` at `9591e31107`. Every GIF frame was inspected. Full-display raw
  recordings include unrelated surfaces and remain private; only the verified
  app crop from the stable interval was published.

- Additional step-6 review fixes were validated on `8dc8a25fb3` plus the
  corresponding source changes: unknown entries suppress successful empty-catalog
  claims; mobile child sessions expose read-only menu entries while root-only
  mutations remain guarded in the shell. Nine MCP widget tests and the focused
  child-session menu test pass; UI and mobile analysis are clean. The latter runs
  from `client/app` with `flutter test test/features/session_detail/widgets/session_detail_body_test.dart --plain-name 'a child session exposes shell-provided read-only menu entries' --no-pub --reporter expanded`.
  Default native fixture content/motion is unchanged by these conditional fixes.

- Original step 7 is split into 7.a live-server controls (ordinal 7) and 7.b
  native authentication (ordinal 8). The series has 15 PRs. Terminal ownership
  and cancellation remain in the authentication step; no Python dependency,
  generic config writer or credential store is introduced by controls.
- Local step-7 controls verification on `33048f9eef` plus the source changes:
  54 Claude mapper/process/control tests, 14 bridge inventory/action route tests,
  and 20 shared-client service/repository tests passed. Seven shared codecs tests
  pass, including equal-key connector rejection and typed mutation refresh results.
  Commands use the pinned Dart SDK from the previous verification section:

  ```sh
  # bridge/sesori_plugin_claude
  dart test test/claude_session_process_repository_test.dart \
    test/claude_mcp_mapper_test.dart test/claude_stream_client_test.dart --reporter expanded
  # bridge/app
  dart test test/bridge/routing/post_mcp_inventory_handler_test.dart --reporter expanded
  # client/module_core
  dart test test/services/mcp_service_test.dart test/repositories/mcp_repository_test.dart --reporter expanded
  # shared/sesori_shared
  dart test test/models/mcp_test.dart --reporter expanded
  ```

  Owning-package analysis is clean.
- Production controls smoke passed with exact Claude 2.1.221 and 2.1.291 using
  isolated synthetic stdio configuration: disable observed as disabled; enable
  independently left disabled state; reconnect returned connected with discovered
  tools. One explicit process launch throughout; configuration content unchanged.
  Private smoke source/logs are under `/private/tmp`; no real server, account,
  provider credential or model request was used. Relay/packaged/other-host
  qualification remains pending.

- Unknown-entry notice deduplication was verified against `33048f9eef` plus
  the notice changes: nine MCP widget tests and shared UI analysis pass. The
  test checks one global hint for unknown-only and mixed known/unknown entries.

- Step-7 architecture review found no general/client/bridge violations and raised
  one shared-wire default concern. That finding is inapplicable under the user's
  public-production-only compatibility rule: the latest public release is v1.9.0
  (2026-09-24), and exact commit `ffa5935c8363c6429fdf2e3c3fb95b3a906f5ab5`
  contains neither `/mcp/inventory` nor `McpServerSnapshot`. MCP inventory has only
  landed in this unpublished series. Its contracts therefore update in lockstep;
  no legacy default or compatibility marker is introduced. All other reviewed
  boundaries passed. Release baseline was rechecked through `gh release list
  --exclude-pre-releases --exclude-drafts --limit 1 --json tagName,publishedAt,isLatest`
  and `git grep` against that release commit.

- Step 6 merged as #1950 after all current-head reviews completed without
  remaining findings and required CI passed. The local controls successor moved
  onto `fa9717350c`; its tree matches `8a5589010f` exactly before controls, so
  unchanged focused verification remains applicable. No prior cache, database,
  runtime process owner or compatibility path is made obsolete by these controls.

[pr-1952]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1952

- Step 7 published as #1952 at `2d9f6d91c2`; validation above describes the
  pre-commit source snapshot that this commit contains. The PR monitor started
  immediately. Published series titles now use 15; historical commits are intact.
  Authored/generated churn before this publication record: 922/714 (1,636 total).

- Step-7 first-review fixes reject absent/unknown action tags before native access
  and emit the explicit server tag on serialization. Native malformed status
  becomes a typed read/action failure while preserving its cause and original
  stack. Focused verification: 24 Claude process tests, 15 bridge route tests,
  seven shared codec tests passed; Claude, shared and bridge analysis is clean.
  Second/final architecture review approved the full branch and working fixes.
  Latest public v1.9.0 has no MCP inventory contract; no unpublished-peer default
  is retained. Controls smoke inputs and production control logic are unchanged.

- Step 7 merged as #1952, squash `0ed5a42b81`, with a byte-identical tree to
  verified head `83ef69a6ed`. A delayed Codex finding arrived after merge:
  archived MCP controls returned plain-text 409 instead of the canonical JSON
  archive rejection. Added a small ordinal-8 follow-up; the series now has 16
  PRs. Native authentication is ordinal 9 and its draft remains preserved.

- Ordinal-8 verification: 45 tests passed across MCP inventory/control routing,
  archive validation, prompt routing and queued-prompt cancellation. Bridge
  `dart analyze --fatal-infos` is clean. The MCP archive regression now asserts
  JSON content type and the exact canonical session ID/reason, with no native
  action, inventory read or invalidation event. No new state or duplicate query.
- Ordinal-8 architecture implementation review approved the exception ownership
  move and canonical repository rejection; no client/shared changes.
