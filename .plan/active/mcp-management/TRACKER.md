# MCP management tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Branch/base: `sesori/mcp-connection-controls`, `bff0055e47`, in the provided `copper-heron` worktree.
- Current step: 11/22 merged as [#1957][pr-1957];
  steps 12/22 and 13/22 merged as [#1962][pr-1962] and [#1964][pr-1964];
  step 14/22 is implementing authentication availability and credential forgetting;
  authentication wire contracts merged as [#1956][pr-1956];
  native authentication merged as [#1954][pr-1954];
  archive rejection merged as [#1953][pr-1953]; controls merged as [#1952][pr-1952].
  Client loading merged as #1949; Claude inventory API merged as #1948. Execution authorized on 2026-10-13.
- User decisions: Claude Code and Codex first; existing servers and offered connectors only; preserve an extension path
  for later server creation without implementing it now.
- Plan PR: [#1940](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1940).
- Architecture plan review: **approved** on 2026-10-13.

## Delivery

The exact titles, scope, estimates, and dependency order are in `PLAN.md`.

| Step | Outcome | State | PR/evidence |
|---|---|---|---|
| 1/22 | Publish reviewed plan | Merged | [#1940](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1940) |
| 2/22 | Native contracts | Merged | [#1945][pr-1945] |
| 3/22 | Inventory foundation (original 3.a) | Merged | [#1947][pr-1947]; six codec tests |
| 4/22 | Claude scoped inventory and bridge read (original 3.b) | Merged | [#1948][pr-1948] |
| 5/22 | Client inventory lifecycle (original 5.a) | Merged | [#1949][pr-1949] |
| 6/22 | Shared phone/desktop inventory and details (original 5.b) | Merged | [#1950][pr-1950] |
| 7/22 | Claude live-server controls (original 7.a) | Merged | [#1952][pr-1952] |
| 8/22 | Canonical archived-control rejection | Merged | [#1953][pr-1953] |
| 9/22 | Claude native authentication (7.b.1) | Merged | [#1954][pr-1954]; 87 tests and native fixture |
| 10/22 | Authentication wire (original 7.b.2.a) | Merged | [#1956][pr-1956]; 12 codec tests and architecture approval |
| 11/22 | Headless auth owner/routes | Merged | [#1957][pr-1957]; 179 tests, fixture, architecture approval |
| 12/22 | Browser ownership (8.a) | Merged | [#1962][pr-1962]; scoped handles, focused tests and native presentation |
| 13/22 | Shared client authentication lifecycle (8.b) | Merged | [#1964][pr-1964]; 38 tests and architecture approval |
| 14/22 | Authentication availability and credential forgetting (8.c.1) | In progress | Native declarations and headless control |
| 15/22 | Visible authentication and controls (8.c.2) | Not started | — |
| 16/22 | Session external actions (8.d) | Not started | — |
| 17/22 | Claude approvals and form/URL elicitation | Not started | — |
| 18/22 | Codex inventory/actions/authentication | Not started | — |
| 19/22 | Codex forms and offered connectors | Not started | — |
| 20/22 | Secondary harness support and explicit gaps | Not started | — |
| 21/22 | Reconcile regression/capability documents | Not started | — |
| 22/22 | Execute L4 plus named external/package checks; retire | Not started | — |

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
- The step-2 release check identified v1.9.0/build 970 as latest production; v1.9.1 builds at that checkpoint were prereleases.
  The released SSE parser plus byte-identical codecs passed four event-order/settlement fixtures and a snapshot fixture.
  Actual mixed-client/native-owner tests remain required in steps 11/12.

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
  production PR, retaining step 16 for reconciliation. Added the dated source-only verification record below.

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

[pr-1953]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1953

- Ordinal-8 reproducibility: published commit `63ab0f6975da69b84cbab8d6977e28b7d6afe638`,
  tree `8f7faddc5e47fc080b4c5604e29735bd0edc3709`, in the dedicated worktree.
  Tests were rechecked on that published snapshot after the import and assertion
  nullability cleanup. The clean analyzer used byte-identical Dart source before
  publication. Subsequent changes only update plan/tracker text.
  Working directory for both commands:
  `/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/copper-heron/bridge/app`.
  Executable for both commands:
  `/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.5-stable/bin/cache/dart-sdk/bin/dart`.

  ```sh
  dart test test/bridge/routing/post_mcp_inventory_handler_test.dart \
    test/bridge/services/archived_session_validator_test.dart \
    test/bridge/routing/send_prompt_handler_test.dart \
    test/bridge/routing/cancel_queued_prompt_handler_test.dart --reporter expanded
  dart analyze --fatal-infos
  ```

  Outcomes: 45 tests passed and no analyzer issues. The `dart` label above means
  the exact pinned executable, not a PATH-resolved installation.

- Original 7.b is split into native boundary 7.b.1 (ordinal 9) and headless
  authentication owner/wire 7.b.2 (ordinal 10), keeping native process lifetime
  review separate from bridge leases and transport. Current series total is 17.
  This changes PR boundaries, not the final qualification matrix.
- Native-boundary verification at base `5dfef8672f` plus the source draft: 11
  native login/parser/service tests, 29 resident-process tests and four mapper
  tests pass. Plugin API construction/behavior regression tests pass
  (35 tests), for 79 focused tests in total.
  Claude and interface analysis is clean after the service ownership fix. Exact commands
  below use the pinned SDK already recorded above, from `bridge/sesori_plugin_claude`:

  ```sh
  dart test test/claude_mcp_login_repository_test.dart \
    test/claude_session_process_repository_test.dart \
    test/claude_plugin_impl_test.dart test/claude_mcp_mapper_test.dart \
    --reporter expanded
  dart analyze --fatal-infos
  ```

  Interface analysis uses the same analyzer command from `bridge/sesori_plugin_interface`.
- Native production service/repository OAuth smoke passed on exact Claude 2.1.221
  and 2.1.291 on macOS arm64: one explicitly launched resident, static configured
  target binding, native completion, reconnect with discovered tools, cancellation
  and native logout. Terminal/native children stopped within the bounded one-second
  observation (106 ms for 2.1.221 and 110 ms for 2.1.291 in the final run).
  Server definitions are unchanged; the target CLI's `pluginUsage`
  preference bookkeeping can change. No model/provider account or real MCP server.
  Private source: `/private/tmp/copper-heron-mcp-auth-smoke.dart` and its Node
  fixture runner. Command from the worktree:

  ```sh
  /Users/alexandrudochioiu/.local/bin/node /private/tmp/copper-heron-mcp-auth-smoke.mjs
  ```

  The runner uses the exact pinned Dart executable with the bridge package config,
  isolated `CLAUDE_CONFIG_DIR` and a local OAuth fixture. The initial whole-file
  preference byte comparison was too broad; the passing invariant compares MCP
  server definitions. Only isolated native fixture credentials were used; no
  real account or production configuration was used. Real provider, relay, packaged
  and other-host checks remain pending.
- Terminal choice uses the system `script` helper through `HostProcessService`;
  there is no Python, Rust or new PTY dependency in production. Native child
  exit codes 0 and 7 and cancellation were measured on the current host. Apple's
  source also preserves child status in `shell_cmds-234` and current main:
  [Apple terminal helper source][apple-script].
  Source inspection does not qualify older host versions. Linux and Windows/SSE
  gates remain explicit and the plan stays active until its recorded matrix passes.

- Architecture review pass 1 rejected peer-repository coordination in the new
  authentication repository. Context resolution and login construction now belong
  to the authentication service and runtime composer; logout accepts its resolved
  context. The second/final architecture review approved the complete native-boundary diff. Provider callback
  errors preserve bounded failure classification: denial is declined, while
  server failure remains a native failure; neither submits a callback code.

- Final native-boundary verification covers the source staged on
  `sesori/claude-mcp-authentication` above base `5dfef8672ffefdf1ce94a0f69596f195bf0874ad`.
  All 79 tests and both owning-package analyzers passed after the ownership fix;
  the final production fixture then passed both exact Claude pins. Series titles
  for all eight published predecessors are synchronized to 17.

[apple-script]: https://github.com/apple-oss-distributions/shell_cmds/blob/shell_cmds-234/script/script.c

- Step 9 review fixes reproduce and correct cancellation before listener attachment,
  browser-denial/cancellation overlap, ambiguous OAuth query parameters, logout
  health reporting, and pipe cleanup after native exit. Context read failures keep
  a typed cause and private authentication presentation rather than becoming false
  unsupported-capability results. The six new tests first failed against the
  corresponding old behaviors, then the complete 85-test focused suite passed;
  final Claude and interface analyzers are clean. Commands and pinned SDK match
  the native-boundary record above. One baseline probe and a suite initially ran
  concurrently during temporary context-wrapper removal; that failed/incomplete
  run is excluded. After restoration, the final full focused suite passed.
- Terminal-helper spawn outcomes are deliberately excluded from session binary
  health. The verified pins emit an exact native authorization URL; speculative
  prose punctuation trimming or skipping malformed OAuth challenges is declined.
  No broad native-output parser or additional operation registry is added.

- Final native fixture after the review fixes passed both exact pins again, with
  cancellation children stopped within 105/107 ms and server definitions unchanged.
  The review-corrected native PR measures about 1,580 changed lines (29 generated),
  a small soft-cap overage from focused lifecycle/privacy regressions. Its coupled
  fixes stay with the native boundary; the 900 generated wire lines remain in the
  separate unpublished successor. No published history is rewritten.

- A final context-failure regression extended the same assertion to credential
  clearing and reproduced the remaining raw error there. Both operations now use
  one private context wrapper. All 17 native authentication tests and Claude
  analysis passed after this correction; the other 68 passing focused tests and
  interface analysis are unchanged. Native fixture evidence above is from
  `3aa6bbd887`; this local change only shares context-error presentation.

- Current-head Codex review found cleanup could replace an existing native failure.
  Two regressions first reproduced lost native exit/timeout causes and expiry
  classification. Settlement now retains both failures and both stack traces,
  preserves the primary classification, and disables the stream's cancellation
  callback after disposal so stream close cannot repeat a handled cleanup failure.
  All 19 native authentication tests pass; the other 68 focused tests and interface
  analysis remain unchanged. The Claude analyzer caught one const declaration in
  the new fixture, now corrected; final analyzer is clean.
- The separate macOS `script -F` argument finding is invalid on the supported
  helper. Installed usage is `script [-aeFkpqr] [-t time] [file [command ...]]`;
  `/usr/share/man/man1/script.1` identifies `-F` as immediate flushing. Apple
  `shell_cmds-234` parses `adFkpqrt:` and its F branch sets `Fflg`, with no argument.
  Primary source was re-read through GitHub API after web fetching failed; the
  existing source link and both pinned production OAuth fixtures agree. No flag
  rewrite or typescript destination change is made.

- Final settlement-change fixture passed both exact Claude pins again on macOS
  arm64: completion, reconnect/tools, cancellation (109/108 ms child-stop
  observation), logout and unchanged MCP server definitions. The remaining
  qualification matrix is unchanged; the new double-failure tests exercise a
  failure seam that normal native success cannot manufacture.

- Cubic identified cancellation-time diagnostics logging only the primary stack
  from a dual failure. The same catch now logs the private cleanup wrapper and
  its cleanup stack as well. This localized logging correction changes no native
  lifecycle or public result; the owning analyzer passes. The 19 native tests,
  other 68 focused tests and native fixture evidence remain from `68a966b4e2`.

- The authentication wire alone measures 900 generated lines plus its models and
  tests. Original 7.b.2 is therefore split into codec foundation 7.b.2.a (ordinal
  10) and headless owner/routes 7.b.2.b (ordinal 11). Current total is 18, with
  unchanged behavior scope and final qualification matrix. This keeps native
  lifecycle ownership review separate from codec churn. No compatibility shim is
  introduced between these internal steps.

[pr-1954]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1954

- Authentication wire validation ran in the provided worktree with parent HEAD
  `bcfcd8e9f3752fc1bf790439e1381f519b78c6bf`. The validated shared source/test
  snapshot is captured by commit `9770290513` and tree
  `9244e84847d5aff6d4bba2b53229c3d6b3b1c4a7`; those shared files are byte-identical
  to published head `5627fb32fc` (`git diff 9770290513 5627fb32fc -- shared/sesori_shared` is empty).
  Working directory:
  `/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/copper-heron/shared/sesori_shared`.
  Executable: `/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.5-stable/bin/cache/dart-sdk/bin/dart`.
  Results:
  five new privacy/binding/round-trip/forward-unknown tests and seven existing MCP
  codec tests pass (12 total), and shared analysis is clean. Exact pinned SDK
  commands from `shared/sesori_shared`:

  ```sh
  dart test test/models/mcp_authentication_test.dart \
    test/models/mcp_test.dart --reporter expanded
  dart analyze --fatal-infos
  ```

  The first connector-target expectation used an invalid union tag and therefore
  tested the generic union decoder instead of the server-only target boundary;
  it was corrected to the real connector-offer variant. Callback malformed-body
  errors preserve their cause without reflecting credential input. Filtered
  generation's unrelated tracked deletions were restored from HEAD.

- Authentication wire architecture review pass 1 approved the complete successor
  diff against `bcfcd8e9f3`; native owner/routes are excluded. All nine published
  series titles are synchronized to 18.

- The unpublished wire successor is rebased onto native review fixes `3aa6bbd887`.
  Only plan/tracker bookkeeping conflicted; both verification histories are retained.
  The shared wire source, generated output and passing test inputs are unchanged.

- The unpublished wire successor also includes the final context correction
  `8681e53fa0`. The shared contracts and their passing test inputs are unchanged.

- The unpublished wire successor includes native dual-failure correction
  `68a966b4e2`. Only plan/tracker bookkeeping conflicted; contract and test inputs
  remain unchanged. Both step histories and current 18-step numbering are retained.

- The unpublished wire successor includes cancellation diagnostic correction
  `75ffab0694`. Both verification histories are retained; shared contract and
  test inputs remain unchanged.

- PR #1954 merged after current-head CI, Cubic approval and completed Codex review.
  The wire successor was rebased onto squash `64617e92bb` without contract changes.
  Published diff measurement pins base `64617e92bb` and head `5627fb32fc`:
  `git diff --numstat 64617e92bb 5627fb32fc` reports 1,264 additions and 64 deletions,
  1,328 changed lines in nine files, including this tracker. Generated codec files
  contribute 900 lines; the remaining 428 are authored code, tests and docs.
  This measurement precedes the documentation-only review correction.

[pr-1956]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1956

- Wire PR documentation review corrected validation provenance, measured line
  budget and submitted callback privacy in `3361d6b95f`; all four bot threads
  were replied to and resolved. The contract files remain unchanged. The first
  UI CI job failed before tests on a sqlite native-asset checksum mismatch and
  was retried with the integrity check intact.

- Local headless owner reserves one attempt before scope/native preparation,
  holds an active-only runtime stream lease, validates HTTPS launch destinations,
  exposes read/start/continue/cancel handlers, and publishes URL-free invalidation.
  Completion waits for stream settlement and refreshes affected inventories;
  OAuth completion does not assert a connection or discovered tools.
- The first cold-stream preparation test exposed cancellation waiting for a native
  event inside `await for`. Replacing that loop with cancellation-propagating
  stream composition fixes the real bridge-shutdown flow. Fixture compile errors
  and an unlistened fake-controller teardown were also corrected; the failing
  exploratory runs are excluded from passing evidence.

- Wire PR #1956 merged after the corrected head passed all checks, Cubic approval
  and completed Codex review. The owner is next; no client auth UI is claimed.
- Owner verification from the provided worktree with parent `3361d6b95f`:
  19 route/authentication tests, 77 runtime tests, 17 client inventory tests and
  56 shared SSE codec tests pass (169 total). The 15 existing inventory-handler
  tests passed in the initial mixed run; that run's new auth fixture did not load
  and is excluded from new-owner passing evidence. Tests used the pinned SDK
  executable recorded above, from the owning package directories:

  ```sh
  # bridge/app
  dart test test/bridge/routing/mcp_authentication_handler_test.dart --reporter expanded
  dart test test/bridge/runtime/plugin_runtime_test.dart --reporter expanded
  # client/module_core
  dart test test/services/mcp_service_test.dart --reporter expanded
  # shared/sesori_shared
  dart test test/models/sesori_sse_event_test.dart --reporter expanded
  # each owning package
  dart analyze --fatal-infos
  ```

  Bridge, client core and shared analyzers pass. No native provider, packaged
  client or relay E2E qualification is added by these unit/route tests. The final
  plan matrix remains required. Native cancellation errors preserve a typed cause
  and failure state rather than claiming successful cancellation.

- The passing owner code/test snapshot is commit `e56fa43a4e` (recorded before
  the clean rebase) and current immutable head `8613b4674dc0dd3644af0d424902db6ea1f01cfb`,
  tree `67d97e44a27c3c77b1eea697c648ec3652ede9ef`. Source/test files are identical
  across that rebase. Package working directories are the provided worktree's
  `bridge/app`, `client/module_core` and `shared/sesori_shared`.
- The production owner/repository/handlers plus native Claude service fixture
  passed both exact pins on macOS arm64 from `8613b4674d`: live target binding,
  request-only HTTPS challenge recovery, busy second start, matching callback,
  native completion, harness invalidation, explicit cancellation and unchanged
  server definitions after native logout. Each pin made one token request.
  Native children disappeared within 103/104 ms in a bounded one-second
  observation. The fixture used isolated native configuration and fixture
  credentials, a local OAuth issuer advertising an HTTPS fixture destination,
  and an in-memory catalog/runtime test adapter. Runtime lease semantics were
  verified separately in the production runtime suite. This is not a real
  provider/browser, relay, full running bridge or packaged-client qualification.
  Early fixture failures assumed synchronous invalidation delivery and immediate
  child disappearance; those overstrict assertions were corrected to await the
  stream notification and use the existing bounded child observation.
- Immutable pre-evidence-update line budget: `git diff --numstat 8bfeda9416 8613b4674d`
  reports 1,084 additions and 16 deletions (1,100 changed lines, 27 files), including
  the tracker. Generated SSE codec changes are 51 lines; authored churn is 1,049.

- Owner architecture implementation review pass 1 approved the complete diff
  against `8bfeda9416`, including client invalidation and shared SSE boundaries.

- Owner PR review found preparation waiting on native readiness, late disposal
  relative to routed drain, repeat cancellation, callback-outcome uncertainty,
  and stale capability prose. The fixes cancel read-only preparation promptly,
  activate native work after known cancellation capability, interrupt ownership
  before route drain, memoize native cancellation and preserve uncertain callback
  settlement. Explicit cancellation remains available after callback submission;
  duplicate cancellation alone returns the existing settling state.
- Twenty-seven owner route/lifecycle tests pass after the review corrections.
  The unchanged runtime/client/shared suites retain their earlier evidence. The
  final native owner fixture also passed both pins: a SIGSTOP-suspended resident's
  read-only preparation cancelled in 2/1 ms, resumed status never started the
  discarded login helper, and the full HTTPS fixture journey passed. Native
  children disappeared within 123/124 ms in the bounded one-second observation.
  This remains fixture/in-memory-adapter qualification, with the full final
  provider/relay/client/platform matrix still required.
[pr-1957]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1957

- Client/external-action scope is split into ordinals 12–15: browser transport
  ownership, shared authentication lifecycle, visible controls, and session URL
  actions. Original step 8 maps to 8.a–8.d, with the existing feature scope and
  final qualification matrix unchanged. Current series total is 21; published
  titles are synchronized, and historical squash commit subjects are preserved.

- Owner architecture implementation review pass 2/final approved commit
  `76efbf4039` against `8bfeda9416`: read-only preparation, activation sequencing,
  single native cancellation, callback settlement and disposal before route drain.
  The reviewed immutable diff is 1,439 changed lines across 28 files, including
  51 generated lines and 1,388 authored lines. Twenty-seven owner tests and the
  owning analyzer pass. Together with the unchanged 77 runtime, 17 client and
  56 shared tests, that review-corrected snapshot totals 177 focused tests. The final native fixture used the review-corrected source at
  `76efbf4039` (only its subsequent lint brace adjustment was unrelated to behavior).

- Owner review round 2: preparation cleanup failure now publishes native failure,
  completes the original start, and releases the reservation while rethrowing the
  typed cancellation cause with its stack trace. Its regression failed before
  the fix; 28 owner tests now pass. Combined focused evidence is 178 tests
  (28 owner + 77 runtime + 17 client inventory + 56 shared codec). The final
  architecture approval remains for commit `76efbf4039`; this follow-up changes
  local error handling, with no new ownership or architectural boundary.

- Owner review round 3: failed native cancellation is visible through GET and
  duplicate cancel while the stream remains owned; a second start remains busy
  until native settlement. Its regression failed before the fix. The initial
  start still waits for native context validation; GET exposes its reserved
  starting attempt during read-only preparation, and explicit cancellation stays
  prompt. The route recovery assertion covers that contract. Focused evidence
  is now 179 tests: 29 owner + 77 runtime + 17 client inventory + 56 shared codec.

- Browser ownership step 12 is implemented locally: bridge/connection/purpose
  identity handles, typed busy, matching retry/cancel/disposal, accepted-provider
  ownership, retained blocked challenge and explicit retry. Architecture review
  pass 1 approved the new production boundaries against `f6da8d1151`; subsequent
  changes include the local shared-sheet height transition found during native
  QA. That method-level UI change introduces no new architectural boundary;
  its owning widget suite, analyzer and native recording passed afterward.
- Browser focused evidence is 198 tests: 169 core transport/provider/Cubit plus
  29 shared harness widget tests. The overlap regression failed before the fix.
  Core/shared UI and downstream mobile/desktop analyzers pass. Presentation and
  localization generators ran; no unrelated generated output was retained.
- The debug macOS synthetic visual fixture builds and starts with Metal/Impeller,
  without account, bridge, browser or persistence initialization. Computer Use
  initially blocked interaction; after the user enabled its permissions, native
  busy/retry/cancellation checks ran. The recording exposed a status-layout snap;
  the shared sheet now eases height changes over 200 ms and honors reduced motion.
  The 29 owning widget tests and shared UI analyzer passed after that local fix.
  The existing production app PID 7903 remains untouched.
- Additional callback qualification on Claude 2.1.221/2.1.291 verifies the owning
  native helper PID binds the expected loopback port and a fixture HTTP browser
  return completes authentication without stdin forwarding. Each pin made one
  fixture token request; explicit cancellation stopped children within 96 ms in
  the bounded one-second observation, and logout preserved server definitions.
  The tested owner source is `94c80bcc3a`, with the in-memory catalog/runtime
  adapter and isolated fixture credentials. This qualifies direct loopback
  return, not system-browser launch, real-provider policy, relay or packaged UI.

- Step 11 merged at accepted head `94c80bcc3a` with all 33 checks passing;
  current-head Codex review completed and Cubic approved. The reserved-start
  contract feedback was explicitly declined with its GET recovery/cancellation
  evidence; all actionable feedback was addressed. Step 12 rebased unpublished
  onto the merge at `067380c981`, retaining its focused test provenance.
- Step-12 native UI qualification passed on macOS 27.0.1 / Xcode 27.0 with
  Flutter 3.47.5, debug/Metal/Impeller, source captured in `8149858f03`.
  Computer Use exercised busy, retry, opening, waiting, cancellation and Close.
  The final window-only recording confirms intermediate height positions during
  the 200-ms transitions. The fixture uses the product router and synthetic
  service state; no website, account, bridge, relay or credential store was used.
  This is presentation qualification, not the final provider/package matrix.
  Owned fixture PID 74617 exited; production PID 7903 remains running unchanged.
- Reviewed synthetic media is on `pr-media` at `44764241f2`, under
  `sesori/mcp-client-authentication/`: cropped existing launch-failure and new
  busy presentations, plus a silent 19.6-second retry/cancel/close GIF (700 KB).
  Screenshots compare states rendered by the fixture, rather than claiming a
  separate old-binary run. Original recordings stay private.

- Step-12 pre-publication measurement before this record: 19 files,
  853 additions and 77 deletions (930 changed), with 25 generated and
  905 authored lines. No prior registry, persisted state or database schema
  is superseded; unscoped browser cancellation and replacement were removed
  from every live in-repository consumer.

- Immutable initial publication measurement: `git diff --numstat 067380c981 1ec19cc9b7`
  reports 859 additions and 77 deletions (936 changed), including the six-line
  measurement record above: 25 generated and 911 authored lines across 19 files.
  The preceding pre-record measurement remains its labeled historical snapshot.
- Step-12 review reproductions failed before their fixes: owner reservation now
  precedes synchronous phase notification, and provider cleanup keeps its owner
  handle until closure so disposal joins the same cancellation. No cleanup
  future registry, queue or additional mutable coordination field was added.
- Both changed core suites pass 95 tests after those fixes; the unchanged
  Cubit suite retains 76 passing tests, for 171 core plus 29 UI tests (200 total).
  Core analysis is clean. The production UI is unchanged from its native recording.

[pr-1962]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1962

- Step 12 merged at accepted head `b4498eaae6`: all 20 pre-merge checks passed
  (19 success, one skip), Cubic approved, and current-head Codex code/security
  reviews completed. All four actionable bot threads were addressed and resolved.
  The terminal merged report also observed a newly running post-merge check;
  that report is not evidence that the added check had passed.
- Step 13 is implemented locally on merged base `5c47d7532f`: typed API/repository,
  one shared connection/bridge-fenced auth service, request-scoped recovery while
  start POST waits, explicit browser intent, matching handle/challenge reuse,
  busy retention, native settlement and observational Cubits. Existing management
  supplies authoritative bridge identity; unsupported identity is explicit.
  No provider state machine, native request registry, timer, persistence or
  configuration writer was copied or added. No existing owner becomes obsolete.
- Step-13 focused evidence: 13 auth service/Cubit and two auth repository tests
  pass, plus 17 inventory and four repository regressions (36 total). Core, mobile
  and desktop analyzers pass. DI generation adds 11 generated lines. Native truth,
  request progress and browser presentation are separate typed states; source
  errors retain causes, and callback destinations remain absent from logs/SSE.
  This internal lifecycle has no new visible controls or database effect;
  presentation/native-provider/relay/package qualification remains pending.

- Step-13 architecture implementation review pass 1 **approved** the 16 staged
  paths against `5c47d7532f`, applying Client rules. No architectural findings.
  Mutable budget is ten fields: state subject, composite subscriptions, current
  connection and bridge ID, epoch, observation/staleness/mutation versions,
  in-flight read epoch, and the one accepted browser record. These cover current
  recovery/ownership; no per-attempt map, queue, timer or durable state is added.

- Step-13 source/test evidence was uncommitted on `5c47d7532f`, captured
  unchanged in `641be7dc77`. Immutable measurement against that base is
  1,114 additions and five deletions (1,119 changed) across 16 files:
  11 generated DI lines and 1,108 authored lines, before this evidence record.

- Original visible-control step 8.c is split into 8.c.1 (ordinal 14: native
  declarations and headless credential forgetting) and 8.c.2 (ordinal 15: client
  controls/presentation). Generated inventory contracts and native ownership
  changes are reviewed separately from motion/UI. Current total is 22; subsequent
  ordinals shift once, and published titles are synchronized without rewriting
  historical squash commits. The final qualification matrix remains unchanged.

[pr-1964]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1964

- Client-lifecycle review corrections reproduced before fixing: starts now
  recheck pending work after identity refresh, and native-settlement-only mode
  cannot post cancellation or release its browser. Unknown cancellation during
  read-only preparation remains cancellable. The stale regression status now
  distinguishes the implemented lifecycle from pending visible controls.
- The changed auth service suite passes 15 tests after review, with unknown-mode
  preparation cancellation checked separately after strengthening its assertion.
  Combined focused evidence is now 38 tests; core analysis is clean. Architecture
  approval remains for `641be7dc77` source: follow-up guards change ordinary method
  behavior, with no new class, dependency or lifecycle boundary.

- Step 13 merged at accepted head `a5779e3eee`, squash `bff0055e47`: 20 pre-merge checks passed
  (19 success, one skip), Cubic approved the current head and all six actionable inline threads were resolved.
  Codex code/security review completed at initial head `74aadc0574`; subsequent review hit the account usage limit.
  Current-head Codex review is not claimed. The merged report includes a newly running post-merge check, not proof
  that the added check passed. Step 14 synchronized to the squash without rewriting published history.
- Step-14 release refresh found public v1.9.1 published at 2026-10-14 08:56:26 UTC, commit `8bfeda9416`.
  It contains MCP inventory/control/authentication wire models, replacing the earlier latest-production assumption.
  Both new capability fields have dated omission defaults to unknown. The exact released MCP source/generated
  codecs pass a private additive-field/control-tag fixture; the current decoder passes a released-shape snapshot.
  The earlier v1.9.0 parser result remains historical evidence; final mixed-client qualification now includes v1.9.1.
- Step 14 implements independent per-server authentication/forgetting declarations and one headless native owner
  for either login or credential forgetting, with active-runtime leases, canonical archive/ownership checks, typed
  gaps and authoritative refresh. Native effects determine invalidation. No new mutable field, queue, credential
  store, configuration writer or database schema is introduced. The single-variant manual serializer is obsolete
  and replaced by generated union serialization while retaining the existing server-action wire tag.
- Step-14 focused evidence: 15 shared codec, 50 bridge route/owner, 53 Claude mapper/context/login, 21 client
  inventory/repository and nine shared UI tests pass (148 unique tests). The unsupported-harness assertion passes
  separately after its addition. Shared/interface/Claude/bridge/core/shared-UI/desktop analyzers pass.
- The private native fixture passes Claude 2.1.221 and 2.1.291 on macOS arm64: production headless forgetting
  returns resident inventory, emits harness invalidation and preserves server definitions. Preparation cancellation
  takes 1 ms at both pins; native child shutdown is observed within 108/107 ms. This isolates synthetic credentials
  and an in-memory catalog/runtime adapter; real provider, relay, packaged and other-host gates remain pending.
- Step-14 architecture implementation reviews pass 1 and pass 2 **approved** the staged change against
  `bff0055e47`, applying Client/Bridge/Shared rules with no findings. Pass 2 includes the newly verified public
  v1.9.1 wire omission defaults; plugin-internal constructors remain required and no native ownership changes
  were introduced by that adjustment. Markdown title ordering, final qualification ownership and diff checks pass.
- Step-14 tested source is captured in `acefd5513a` against `bff0055e47`: 1,231 additions and 131 deletions
  (1,362 changed) across 34 files, with 375 generated and 987 authored lines, below the soft cap.
  The native flow was exercised before the additive omission defaults; changed shared serialization/decoding then
  passed its updated codec suite and exact public v1.9.1 parser fixture. Native ownership/plugin logic was unchanged.
- Step-14 review correction: the harness-effect regression fails with the former request-derived scope mapping.
  Native server-action completion now carries its required declared effect scope through the plugin/repository
  boundary, matching credential forgetting. Claude reports session effects; all internal constructors update
  together. The changed bridge suites pass 51 tests and Claude resident tests pass with explicit scope assertions,
  for 149 unique focused tests overall. Interface/Claude/bridge analyzers pass; no new owner or lifecycle is added.
  Regression prose now says capability fields are decoded, since visible controls remain step 15.
