# MCP management tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Branch: `sesori/mcp-pi-acp-capability-audit`, in the provided `copper-heron` worktree.
- Current step: 35/37 bounded Pi/ACP source and adapter audit is prepared for review.
  Parent 34/37 merged as [#2010][pr-2010] at accepted head `5f783ab402`.
  Latest squash: `bcfa8e369b`, with 19 passing pre-merge checks.
  Native v2 OAuth support was verified through its Integration API on both pins.
  Split contracts, v2 ownership and v1 ownership for review; final qualification is unchanged.
  Native recording remains deferred by the user.
  Claude native forms merged as [#1991][pr-1991].
  Typed transport merged as [#1989][pr-1989].
  External-action client presentation merged as [#1986][pr-1986].
  Earlier steps 11–14 merged as [#1957][pr-1957], [#1962][pr-1962], [#1964][pr-1964] and [#1966][pr-1966];
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
| 1/37 | Publish reviewed plan | Merged | [#1940](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1940) |
| 2/37 | Native contracts | Merged | [#1945][pr-1945] |
| 3/37 | Inventory foundation (original 3.a) | Merged | [#1947][pr-1947]; six codec tests |
| 4/37 | Claude scoped inventory and bridge read (original 3.b) | Merged | [#1948][pr-1948] |
| 5/37 | Client inventory lifecycle (original 5.a) | Merged | [#1949][pr-1949] |
| 6/37 | Shared phone/desktop inventory and details (original 5.b) | Merged | [#1950][pr-1950] |
| 7/37 | Claude live-server controls (original 7.a) | Merged | [#1952][pr-1952] |
| 8/37 | Canonical archived-control rejection | Merged | [#1953][pr-1953] |
| 9/37 | Claude native authentication (7.b.1) | Merged | [#1954][pr-1954]; 87 tests and native fixture |
| 10/37 | Authentication wire (original 7.b.2.a) | Merged | [#1956][pr-1956]; 12 codec tests and architecture approval |
| 11/37 | Headless auth owner/routes | Merged | [#1957][pr-1957]; 179 tests, fixture, architecture approval |
| 12/37 | Browser ownership (8.a) | Merged | [#1962][pr-1962]; scoped handles, focused tests and native presentation |
| 13/37 | Shared client authentication lifecycle (8.b) | Merged | [#1964][pr-1964]; 38 tests and architecture approval |
| 14/37 | Auth availability and forgetting (8.c.1) | Merged | [#1966][pr-1966]; 149 tests, native fixture |
| 15/37 | Shared action lifecycle (8.c.2.a) | Merged | [#1969][pr-1969]; 33 tests, architecture approval |
| 16/37 | Visible auth and controls (8.c.2.b) | Merged | [#1971][pr-1971]; 24 widgets and native fixture flow |
| 17/37 | External-action transport (8.d.1) | Merged | [#1981][pr-1981]; 61 shared cases, architecture approval |
| 18/37 | Native external-action routing (8.d.2.a) | Merged | [#1984][pr-1984] |
| 19/37 | External-action client presentation (8.d.2.b) | Merged | [#1986][pr-1986] |
| 20/37 | Typed form transport (9.a) | Merged | [#1989][pr-1989] |
| 21/37 | Claude native forms (9.b.1) | Merged | [#1991][pr-1991] |
| 22/37 | Canonical headless forms (9.b.2) | Merged | [#1992][pr-1992] |
| 23/37 | Client typed draft lifecycle (9.c.1) | Merged | [#1993][pr-1993] |
| 24/37 | Shared typed form controls (9.c.2) | Merged | [#1995][pr-1995] |
| 25/37 | Codex scoped inventory (10.a) | Merged | [#1999][pr-1999]; evidence below |
| 26/37 | Codex native OAuth ownership (10.b) | Merged | [#2000][pr-2000]; evidence below |
| 27/37 | Codex typed forms and URL requests | Merged | [#2001][pr-2001]; 46 tests and exact pins |
| 28/37 | Codex offered connector catalog | Merged | [#2003][pr-2003]; 32 checks; exact pins |
| 29/37 | Connector setup actions and browser handoff | Merged | [#2005][pr-2005]; evidence below |
| 30/37 | OpenCode v2 inventory/controls (11.a) | Merged | [#2006][pr-2006]; evidence below |
| 31/37 | OpenCode v1 inventory/controls (11.b) | Merged | [#2007][pr-2007]; 118 cases; both pins |
| 32/37 | OpenCode v2 auth contracts (11.c.1) | Merged | [#2008][pr-2008]; 61 cases; both pins |
| 33/37 | OpenCode v2 authentication owner (11.c.2) | Merged | [#2009][pr-2009]; both native pins |
| 34/37 | OpenCode v1 native MCP authentication (11.d) | Merged | [#2010][pr-2010]; 180 unique cases; both pins |
| 35/37 | Bounded Pi/ACP source and capability audit (11.e) | Prepared | Exact source/schema audit; documentation only |
| 36/37 | Reconcile regression/capability documents | Not started | — |
| 37/37 | Execute L4 plus named external/package checks; retire | Not started | — |

[pr-2010]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/2010
[pr-2009]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/2009
[pr-2008]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/2008
[pr-2007]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/2007
[pr-2000]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/2000
[pr-2001]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/2001
[pr-2003]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/2003
[pr-2005]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/2005
[pr-2006]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/2006

## Evidence and decisions

- Step-34 accepted head `5f783ab402` merged with 19 passing checks, Cubic
  approval and completed code/security reviews without new findings. Two scoped
  declines retain reasoned replies. The merged main tree equals the accepted
  parent tree; the entire local step-35 diff is preserved byte-for-byte across
  integration before updating this delivery state.
- Step-35 exact source audit found no passive resident MCP management seam in
  Pi RPC or standard ACP. Documentation-only scope and complexity replace the
  conditional production estimate; no new production owner, wire state or native
  action is added. No architecture review or Dart/Flutter suite is required.
  Existing commands, generic approvals and bounded forms remain unchanged.
  Pi source commits are `4b060d3a98618019adb9985d517516c8e99a2bbe` (0.99.0)
  and `7c10bd4337495ee613f2224843ecdf349b80d1df` (1.0.4). Their RPC type files
  are byte-identical with no MCP management methods. Native `/mcp` is a text/
  command path and login opens the native host browser; separate CLI JSON list
  creates fresh connections. Standard ACP schema 0.10.8 at
  `59fdb36c3520fe40109e628c48eede5a2a6204df` describes input transports/server
  definitions, not inventory/control/OAuth/catalog methods. Seven registered ACP
  adapters share the existing base and none implements the optional MCP APIs.
  Vendor-specific extensions remain unqualified, not assumed unsupported.
  Current descriptor minimum/target versions are recorded in capabilities.
  Relative Markdown links and source/schema comparisons pass. No production
  behavior or analytics event changes; no causal code cleanup was found.
  This is source evidence, not native runtime/provider/platform qualification.
  Original final L4 and deferred native recording gates remain unchanged.
- Step-34 third PR review reproduced a malformed remote URL reaching native
  authentication HTTP 500 at 1.17.7 and retaining uncertain ownership. Shared
  HTTP(S)/host preflight now blocks sign-in before native mutation; forgetting
  remains independent. Empty and malformed URL regressions bring the focused
  suite to 137 passing cases (180 unique across affected runs); owning analysis
  is clean. Both exact v1 pins verify zero authentication writes/token exchanges
  for malformed configuration (1.14.17 already rejects native inventory), plus
  successful disabled sign-in/forget/sign-in with unchanged configuration.
  Corrected the control-layer documentation: the service validates fresh targets,
  while the repository resolves scopes and maps native reads/mutations.
- Step-34 second PR review rejects configured callbacks with reserved OAuth
  response keys before start. The shared scope resolver moves into the existing
  repository, so general controls and authentication share one mapping without a
  service-to-service dependency or duplicated policy. All 135 directly affected
  authentication/controls/concrete-plugin cases and owning analysis pass (178
  unique across affected runs). Both exact v1 pins verify reserved-key preflight
  without mutation and successful exact-session authentication after the move,
  preserving disabled state and configuration. Earlier architecture approvals
  retain their recorded scopes; no third review is invoked for these corrections.
- Step-34 PR review preserves only non-secret OAuth redirect metadata in a
  disabled/enabled configuration sum. Unsupported callback overrides now declare
  native configuration requirements before start; forgetting stays independent.
  Both exact v1 pins reject the override through the production owner with no
  native mutation. Disabled callback results complete authentication after native
  token persistence; both pins verify two token exchanges without enabling the
  server or changing configuration. Known OAuth query and fragment secrets are
  redacted while useful paths and diagnostic context remain under local-log rules.
  All 80 directly affected cases and owning analysis pass; 95 earlier affected
  API/repository/plugin cases remain unchanged (175 unique cases across runs).
  Source generation passes. The pure challenge value retains its invariant
  methods; no separate parser/lifecycle collaborator is justified by that review
  suggestion. Native recording and original final qualification remain pending.
  Final architecture implementation review approved (pass 2) on `ff8c9447d1`;
  the full reviewed step is 1,460 lines, including 231 generated lines.
- Step 33 merged at accepted head `760ec2e428`, squash `37f62d4837`, with
  all 19 pre-merge and 20 terminal checks passing. Cubic approved, current-head
  Code/Security reviews completed, and four architecture/native-shape suggestions
  remain intentionally open with reasoned replies. The challenge invariant stays
  with its immutable value; no extra parser/cadence owner is introduced.
  Step-34 integration preserves the entire tested successor tree and diff exactly:
  SHA-256 `a175adba77e28a62a5a5dcce72f6a969a765517469e9c2c60b36e6911e1a0254`.
- Step-34 architecture plan review approved the minimal v1 configuration
  projection, existing scope resolver, manual callback owner and shared plugin
  callback validator. Native DELETE auth destroys credentials, so this operation
  exposes native settlement without cancellation. Provider denial cannot safely
  settle native work; retirement logs unavailable cleanup for attached runtimes.
  Both exact 1.14.17/1.17.7 production owners pass exact session attribution,
  manual callback completion, harness-profile forgetting and sign-in again.
  Configuration bytes are unchanged and two fixture token exchanges are verified
  per pin. All 77 authentication/controls/shared-validator cases and 95 affected
  v1 API/repository/plugin cases pass (172 total); owning analysis is clean.
  Both v2 native owner flows pass after validator extraction. V1 callback failure
  diagnostics reuse the existing OAuth query redactor beside that validator.
  Native 1.14.17 already-authorized serialization failure
  remains uncertain; 1.17.7's explicit no-challenge maps to completion. Analytics
  assessment retains the existing shared lifecycle seam and adds no tap event.
  Architecture implementation review approved the final 1,266-line diff (1,079
  authored, 187 generated, 21 files). Synthetic before/after controls are hosted
  on orphan pr-media commit `652da40b9907b4bdbf6b35a90146235c228df8e1`.
  Recording and original provider/package/relay/device/L4 gates remain pending.
- Step-33 PR review fixes cancellation before subscription, waits for a pending
  start handle within runtime teardown's existing budget, and settles confirmed
  attempt disappearance as unresolved failure outside acknowledged cancellation.
  Polling waits through DELETE acknowledgement and native persistence still wins.
  Callback validation rejects both result keys even with an empty value; local
  failure logs redact OAuth query secrets while retaining useful endpoint context.
  All 34 authentication cases and owning analysis pass; both exact native
  production-owner probes pass. The pinned MCP core registers one form-free
  OAuth method, so provider-only shapes do not add inventory metadata requests.
  Lifecycle polling stays with the reviewed operation owner; native v2 exposes
  no pushed attempt-status seam. Original final qualification remains pending.
- Step-33 architecture implementation pass 1 found transport status branching in
  repository/service. Native rejection and exact attempt-not-found translation
  now live in the API; repository maps them to typed domain outcomes retaining
  original causes and stack traces. The native generated error contract checks
  the tag and exact integration/attempt IDs, so a different 404 cannot confirm
  cancellation. Lifecycle code imports no raw transport type. The new tests
  preserve original causes and distinguish integration absence from attempt
  removal. Both native production-owner probes pass after this correction.
  Evidence uses `step33-review1-{tests,analyze,native}` private logs.
  Final architecture implementation review approved (pass 2). There are 105
  unique affected passing cases across the 76 lifecycle/inventory/activity/write,
  36 authentication/raw-HTTP, 39 authentication/API and two targeted runtime
  retirement runs. The added retirement cases cover both cleanup success and
  failure, retaining interrupted status and rejecting further callbacks.
  Parent squash integration preserves the entire tested successor diff exactly
  (SHA-256 `78b3d83043a87a538b9091a92c6e684ed82772ea8fa563cb0666493137c96546`).

- Step-33 architecture plan review approved the precise repository/domain/service
  ownership. Existing general service resolves scope; existing repository maps
  native I/O; the new focused service owns attempts. Only subscription starts
  native work. Native cancellation is a no-op while persisting, so the owner
  preserves an observed terminal result and confirms removal after DELETE;
  callback HTTP acknowledgement never settles authentication. Unknown status,
  failed reads and uncertain starts retain ownership. Runtime retirement logs
  unresolved cleanup after a bounded teardown attempt, without claiming cancel.
  All 76 focused lifecycle/inventory/activity/write cases pass and package analysis
  is clean. Both native 2.0.11 and 2.0.24 pass through production
  service/repository/API with an exact native session: confirmed cancellation,
  callback and native completion, harness-scoped forgetting and sign-in again.
  Configuration is unchanged. Private evidence uses `step33-{tests,analyze,native}`
  logs under `/private/tmp/copper-heron-mcp-`. The synthetic product controls
  fixture passes; images are on `pr-media` at
  `bafa9486273793f499440c63b3257a6258c17be5` under
  `sesori/mcp-opencode-v2-oauth/`. Native recording and all final qualification
  gates remain pending. Parent #2008 review fixes are integrated locally.

- Step-32 review corrections wrap the new tracker rows/command and generate
  `ConnectionInfo`, `IntegrationMethod` and `IntegrationAttemptStatus` as sealed
  bases with final variants in their own library. The surface opts only these
  new families into generation; six obsolete separate variant files are removed.
  Existing class names and native wire decoding remain unchanged. Exhaustive
  test switches cover all three families. All 61 focused cases, package analysis
  and both exact native typed probes pass again; private evidence uses
  `/private/tmp/copper-heron-mcp-step32-review1-{tests,analyze,native}.log`.
  Final architecture implementation review approved the closed families (pass 2).

- Step-32 API contracts pass 61 focused tests and package analysis with pinned
  Dart (Flutter 3.47.7-stable). Cwd `bridge/sesori_plugin_opencode`:
  Tests: `dart test` with `test/v2/opencode_v2_mcp_authentication_api_test.dart`,
  `test/v2/opencode_v2_mcp_test.dart`, and `test/v2/opencode_v2_api_test.dart`.
  Cwd `bridge`: `dart analyze --fatal-infos sesori_plugin_opencode`.
  Both isolated 2.0.11 and 2.0.24 native probes pass through the production typed
  API: returned integration/method IDs, acknowledged cancellation, automatic
  callback plus native completed status, exact credential removal and unchanged
  configuration bytes. The typed probe exposed a real minimum-version omission:
  2.0.11 credential metadata has no `method`; a source-controlled generator
  override makes that field nullable instead of inventing a value. Native
  target metadata still decodes its enum. Private evidence:
  `/private/tmp/copper-heron-mcp-step32-{tests,analyze,typed-native}.log`.
  Architecture plan and implementation pass 1 approved the API-only scope.
  Synthetic control screenshots pass the product widget fixture and are hosted
  on `pr-media` commit `95aed578bbcf9643a668219c7da30b3d99637679` under
  `sesori/mcp-opencode-authentication/`. No motion changes; native recording
  remains deferred. Product authentication remains unavailable until step 33.

- Step 31 merged as #2007 at accepted head `b364c8b2f7`, squash `35a0e40be4`.
  Nineteen checks passed before merge, Cubic approved and current-head code/security
  reviews completed without findings. Its native recording remains deferred.
- The revised series has 37 steps: native v2 Integration OAuth exists on both
  2.0.11 and 2.0.24, so contracts and ownership are separate from v1 authentication.
  Step-32 architecture plan review approved this API-only boundary. Raw native
  probes pass cancellation, automatic callback completion and exact credential
  removal on both v2 pins, with unchanged configuration. Native v1 1.14.17 and
  1.17.7 separately pass manual callback exchange/removal; browser return alone
  fails and deletion also removes credentials, so it cannot serve as safe cancel.
  None of this reduces the original final L4/package/provider/device matrix.

- Step-31 tested source `790caa38cc` follows the accepted step-30 corrections: existing
  service coordinates scope/target/action; repository maps directory reads and
  mutations. Native writes remain unbounded, with two new slow-write regressions.
  All 118 affected v1 cases and owning analysis pass; both exact native versions
  pass again through service/repository/API, replacing resident fixture processes
  and retaining configuration bytes. Logs use the `step31-final-*` private paths.
  The original presentation fixture is unchanged. Final architecture review
  approved the aligned ownership (pass 2). Parent #2006 merged after passing CI
  and completed code/security reviews; its additional presentation-capability
  guard was declined because native controls remain valid across status changes.
  All incoming squash-conflict files matched reviewed parent `c8aa783df3`;
  the entire v1 diff is unchanged after integration.

- Step 31 tested source `a00726445c`: architecture plan and implementation reviews
  approved. All 116 affected MCP/API/repository/plugin
  cases and package analysis pass. Cwd `bridge/sesori_plugin_opencode`:

  ```sh
  dart test test/opencode_mcp_test.dart test/opencode_api_http_test.dart \
    test/opencode_repository_test.dart test/opencode_plugin_impl_test.dart
  ```

  Cwd `bridge`: `dart analyze --fatal-infos sesori_plugin_opencode`. Both use
  pinned Flutter 3.47.7-stable's bundled Dart. The existing PATH floor 1.14.0
  has no upstream Git tag/npm artifact; npm's first published 1.14.x version is
  1.14.17. Its schema confirms the same status/connect/disconnect seam as target
  1.17.7. Native qualification uses those two exact integrity-verified binaries,
  without changing runtime policy. Both pass production API/repository inventory,
  enable, resident reconnect, disable and exact session lookup; resident fixture
  processes are replaced and config bytes remain unchanged. Fixture preparation
  includes its schema declaration to avoid OpenCode's first-read metadata rewrite.
  No model/tool call or provider sign-in occurs. Private probe/log:
  `/private/tmp/copper-heron-mcp-step31-native.py` and corresponding `.log`.
  Original provider/package/client/L4 and deferred native recording remain pending.
  Synthetic before/after/control widget renders pass and were inspected. Media:
  orphan `pr-media` commit `e174f0dabdfe4a37260a0380168ab88b94294b9c`, under
  `sesori/mcp-opencode-v1-controls/`. This is shared presentation evidence only.

- Step-30 review corrections: existing service owns scope resolution, fresh-target
  validation and action dispatch; the repository exposes mapped directory reads
  and mutations. MCP API calls preserve original failures for one headless log,
  including native session lookup. Native writes remain unbounded; response loss
  retains the client's existing uncertain-action behavior. Project effects
  invalidate all plugin inventories so other session/project views refresh.
  Final implementation architecture review approved (pass 2). All 72 affected
  v2 cases and 26 headless route cases pass; owning analysis is clean. The same
  v2 command below runs from its package; headless command from `bridge/app` is
  `dart test test/bridge/routing/post_mcp_inventory_handler_test.dart`.
  Both exact native pins pass again through service/repository/API, preserving
  configuration bytes and replacing the resident fixture process on reconnect.
  The historical Step-17 CI denominator remains 32/32; plan renumbering does not
  rewrite measured results. Deferred/external qualification remains unchanged.

- Step 30 tested source `51bcf3f5f4`: both architecture reviews approved; all 69
  affected v2 cases and package analysis pass. Cwd `bridge/sesori_plugin_opencode`:

  ```sh
  dart test test/v2/opencode_v2_mcp_test.dart \
    test/v2/opencode_v2_api_test.dart \
    test/v2/opencode_v2_repository_test.dart \
    test/v2/opencode_v2_plugin_test.dart
  ```

  Cwd `bridge`: `dart analyze --fatal-infos sesori_plugin_opencode`. Both commands
  use the pinned Flutter 3.47.7-stable Dart SDK. Exact native 2.0.11 and 2.0.24
  archives matched npm SHA-512 integrity; target SHA-256 also matches the runtime
  manifest. The private probe `/private/tmp/copper-heron-mcp-step30-native.py`
  uses isolated profiles, a synthetic local password and test-only native server
  overrides. Both pins pass production API/repository inventory, enable, resident
  reconnect, disable and exact session lookup; reconnect replaces the fixture
  process and configuration bytes remain unchanged. It executes no model/tool
  call or provider login. Private log: `/private/tmp/copper-heron-mcp-step30-native.log`.
  Parent #2005 merged after passing CI and clean completed code/security reviews.
  Incoming squash-conflict files exactly match reviewed parent `ae59986031`;
  the entire successor diff is unchanged after integration. Provider/package/client/L4
  qualification remains pending.

- Step-29 review follow-up preserves ordinary server/forget response diagnostics
  and compression, while setup responses retain destination redaction. Automatic
  inventory reads preserve terminal setup feedback; explicit refresh clears it.
  All 43 affected API/service cases pass, including ordinary HTTP-error details
  and both opened/failed feedback across stale-data reads. CI-style analysis of
  `module_core` and `desktop/tool/mcp_inventory_fixture.dart` passes. The versioned
  desktop inventory fixture now supplies and disposes its read-only action stream.
  Commands use pinned Flutter 3.47.7-stable with its `FLUTTER_ROOT`; no native
  recording is claimed.

- Step 29 resolves native setup destinations through the existing scoped headless
  action route and launches only an explicit, current client action. Destinations
  remain request-local; opened feedback never claims connection. At tested draft
  `d2d4a7bb00`, 143 affected cases and six owning analyzers passed, including phone layout/motion at normal and
  doubled text size. Desktop/phone fixture renders were inspected after integrating
  lazy catalog rows. Both exact Codex pins passed fresh empty-catalog reads.
  Real offers/provider completion, native recording and final L4/package/device
  qualification remain pending. Step 28 merged with 32 passing checks and clean
  completed code/security reviews. Squash-integration conflicts matched the
  already-integrated parent byte-for-byte; setup source remains unchanged.
  CI on published `081a65797c` then found three custom exhaustive-switch lint
  errors and an unstubbed action-state getter in an existing mobile archive
  fixture. These are follow-up corrections, not passing CI evidence for that head.
  Reproducible local checkpoints, from the provided `copper-heron` worktree:

  Cwd `shared/sesori_shared`, 11 passed:

  ```sh
  dart test test/models/mcp_test.dart
  ```

  Cwd `bridge`, 50 passed:

  ```sh
  dart test \
    sesori_plugin_codex/test/codex_mcp_repository_test.dart \
    sesori_plugin_codex/test/codex_mcp_plugin_test.dart
  ```

  Cwd `bridge/app`, 24 passed:

  ```sh
  dart test test/bridge/routing/post_mcp_inventory_handler_test.dart
  ```

  Cwd `client/module_core`, 36 passed:

  ```sh
  dart test test/services/mcp_service_test.dart
  ```

  Cwd `client/module_app_ui`, 22 passed:

  ```sh
  flutter test --no-pub \
    test/features/mcp/mcp_inventory_view_test.dart \
    test/features/mcp/mcp_server_controls_view_test.dart
  ```

  Commands used pinned Flutter 3.47.7-stable and its bundled Dart, with
  `FLUTTER_ROOT` set to that SDK for client commands. The owning analyzer commands
  were `dart analyze --fatal-infos .` for shared/plugin interface/client core,
  `dart analyze --fatal-infos app` and `dart analyze --fatal-infos sesori_plugin_codex`
  from `bridge`, and `flutter analyze --no-pub` from shared UI. The CI-only custom
  lint result above limits that earlier local analysis claim.

  Follow-up `55ed930a05` fixes those CI findings. The same 22 UI cases pass,
  including unclipped feedback with the product font. Cwd `client/app`, all seven
  cases pass with:

  ```sh
  flutter test --no-pub test/features/session_detail/session_detail_title_hydration_test.dart
  ```

  Cwd `client`, the CI-style custom analyzer passes for both corrected owners:

  ```sh
  dart analyze --fatal-infos module_app_ui
  dart analyze --fatal-infos app/test/features/session_detail/session_detail_title_hydration_test.dart
  ```

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

[pr-1966]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1966

- Step 14 merged at accepted head `704c5ca515`, squash `235ff86970`: all 32 pre-merge checks passed, Cubic
  approved the current head and both actionable threads were resolved. Codex review was unavailable because
  of the account usage limit; no Codex coverage is claimed for this PR. The terminal report included a newly
  running post-merge check, not proof that it passed.
- The former visible-control step 15 draft measured 1,592 changed lines before final docs/native UI fixes.
  It is split into client action lifecycle (8.c.2.a, ordinal 15) and visible controls/presentation (8.c.2.b,
  ordinal 16). Both are independently valid; the preserved UI draft resumes only after Step 15 opens.
  Current total is 23, subsequent ordinals shift once, and final qualification remains ordinal 23 with its
  unchanged L4/native/provider/package scope. Published titles synchronize without rewriting squash history.
- Step 15 adds typed entry-action API/repository operations, one per-view action state subject and an observational
  Cubit. Request/target attribution survives completion and API failure. Native inventory supersedes earlier reads;
  queued staleness triggers a fresh read. Read-only/offline posture, duplicate prevention, connection replacement,
  failed authoritative reads and view disposal are covered. No visible controls or database effect yet.
- Step-15 focused verification: 24 inventory/action service and five repository tests pass (29 total). Core,
  shared UI, mobile and desktop analyzers pass. DI constructors are unchanged and require no generated update.
  Mutable inventory-owner budget is eight fields, including the one new action subject; no extra generation,
  request map, timer, callback owner or queue. All 14 published titles now match the 23-step delivery table;
  Markdown ordering and final qualification ownership validate. The complete retirement matrix remains active.
- Step-15 architecture implementation review pass 1 **approved** the 20 staged paths against `235ff86970`,
  applying Client rules. No findings; the existing view service owns action state/disposal and the new Cubit
  observes it without duplicating lifecycle. The deferred controls draft is outside this foundation review.
- Step-15 tested source is captured in `91b9c1b240` against `235ff86970`: 509 additions and 93 deletions
  (602 changed) across 20 files, all authored, below the soft cap. No generated output or visible
  product layout changed; the separate UI draft remains preserved for the next presentation PR.

[pr-1969]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1969

- Step 15 review: corrected unknown action inventory without a readable snapshot,
  restored idle actions after same-configuration reconnect, and re-armed an
  in-flight read after an uncertain mutation without resending the action. Mobile
  read-only sessions retain inspection only. Entry actions use a bounded 210-second
  management request budget; ordinary reads retain their existing budget.
  Four failure probes failed before these fixes and pass afterward; 33 focused
  cases pass (27 service, five repository, one slow-action API case). Core/mobile
  analyzers pass. Earlier shared UI/desktop analyzer evidence is unchanged.

- Step 15 merged: accepted head `3a0a7de296`, squash `c3716bfce5`. All ten
  round-one review findings were addressed with prefixed replies; no unresolved
  threads remain. Cubic approved the accepted head with zero issues across its
  eight follow-up files. Codex review quota prevented a new review. The monitor
  reported 20/20 checks passing before merge; its terminal report had a newly
  running post-merge check, so it is not recorded as 21 passing checks.
- Step 16 local qualification: eight controls and nine inventory widget cases
  pass; shared UI/mobile/desktop analyzers pass before parent synchronization.
  Architecture implementation pass 1 approved the staged presentation against
  `3a0a7de296` (B-Client; no shared/bridge production change). A private synthetic
  macOS fixture builds, but CUA returns `cgWindowNotFound` for fixture and Finder,
  including after session reset. Read-only Peekaboo reports granted permissions
  and a Stage Manager thumbnail. Native interactions and public motion/screenshot
  evidence remain pending; no provider/relay/packaged qualification is claimed.

- Step 16 parent synchronization: the unpublished branch moved onto Step 15's
  squash `c3716bfce5` without rewriting published history. Localization was
  regenerated from source after the settings-parent merge. All 17 MCP widget
  cases and shared UI/desktop analyzers pass on this parent. Native qualification
  still awaits a usable CUA window; the fixture artifact has an isolated bundle
  ID and app name and uses no account, bridge, browser or native credentials.

- Step 16 native capture update: the user confirmed the laptop had been locked.
  After unlock and an owned-fixture restart, full native screenshots and CUA
  accessibility navigation work. Inspection-only details hide management;
  mutable details open the separate controls layer. Explicit sign-in retains
  its challenge through busy-browser retry without automatic browser launch.
  The server-title pixel band is identical between idle and browser-busy captures.
- Inspected, cropped synthetic comparison PNGs (54/59 KB) are published on
  `pr-media` at `06c61fd6beb390d0ff20cdf23255aeb6636d51b0` under
  `sesori/mcp-visible-controls/`. They compare two fixture modes of the same
  native build, not separate production binaries. Production PID 7903 is untouched.
  A locked-session recording failed before the user unlocked the Mac again;
  the successful follow-up below completes the presentation checks.

[pr-1971]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1971

- Series bookkeeping: original 8.d splits into wire transport (ordinal 17) and
  native integration (ordinal 18), keeping one current total of 24. The wire
  successor is preserved locally in `6d625712f5`; it remains unpublished until
  this controls parent merges. Published titles and forward planning are
  synchronized. Historical evidence/squash titles and the final matrix are unchanged.
  The lock flag was verified before pausing input; no system settings changed.

- Step 16 native presentation qualified on 2026-10-14 using implementation
  `182b1e8519` with parent/localization synchronization at `c3716bfce5`. The
  private fixture source SHA-256 is
  `ffb6f0b24d9e8164816c713e55731b41419d18e54ed1b6413df7b6582d47fe6b`.
  CUA inputs exercised explicit sign-in, busy-browser retry, controls
  close/reopen retaining waiting state, explicit cancellation and settlement,
  forgetting confirmation/cancel/confirm, and full inventory dismissal retaining
  an active challenge. A synthetic native completion while the inventory was
  closed appeared after reopening; Check sign-in retained authoritative state.
  Cancelled confirmation sent no action; confirmed action progressed from pending
  to completed without claiming disconnection or cleared native credentials.
- Silent window-only capture retained genuine transition frames and observed
  frame intervals. The inspected 560×589 GIF is 655,480 bytes and 36.96 seconds,
  showing controls opening, explicit browser retry, close/reopen and cancellation.
  Media commit `665794822475d3dbeeb2e57bf4225144036f2d80` publishes it under
  `sesori/mcp-visible-controls/flow.gif`; all frames contain only fixture data.
  Owned fixture PID 78941 was stopped; production PID 7903 was preserved. No
  account, bridge, real browser, persistence or credential operation ran. These
  checks qualify native presentation only; final L4/provider/package checks remain required.

- Step 16 review fixes: mobile menu activation now reads the current loaded
  archive flag as well as hydrated session metadata. A shell regression failed
  with mutations allowed before the fix and passes with read-only inventory
  when the native archive flag precedes the session timestamp. All seven mobile
  shell cases and 17 shared MCP widget cases pass. Mobile/shared UI analyzers
  pass; localization was regenerated from its action-neutral English source.
  Authentication busy state blocks sign-in and forgetting; independent resident
  reconnect/enable/disable controls remain available. Capability/regression docs
  now describe the implemented presentation consistently. Native motion evidence
  predates these wording and mobile-gating fixes; desktop layout is unchanged.

- Step 16 initial draft publication is reproducible with `git diff --numstat`
  from base `c3716bfce50e99039ca4381ba2f7cf11b49d9487`
  to head `182b1e8519def007f22aeb683cc949374a34cafe`:
  1,341 additions + 17 deletions = 1,358 changed lines across 16 files.
  Generated localization reconciles as 264 additions in `app_localizations.dart`
  plus 136 in `app_localizations_en.dart`, with no generated deletions: 400 lines.
  The remaining 958 authored lines include `app_en.arb`'s 45 additions and one
  deletion. Native CUA interactions and visual evidence were pending at publication.
- Original 8.d splits into transport (8.d.1, ordinal 17) and native session
  integration (8.d.2, ordinal 18). The snapshot codecs alone add 571 generated
  lines. The series has 24 steps; final L4/native/provider/package requirements
  are unchanged. The integration retains validation, canonical ownership,
  modern filtering, legacy cancellation and UI qualification together.
- Step 17 production baseline refreshed on 2026-10-14: latest non-prerelease
  remains v1.9.1 at `8bfeda9416c96ea5de70ffc701a36b738f24eff7`, published
  08:56:26 UTC. Exact archived public snapshot and SSE question codecs accept
  both additive form/external-action markers while retaining original session,
  display parent and cancel-only custom-disabled notices. This is codec proof,
  not mixed-client or native cancellation qualification.
- Local wire draft: 61 focused shared cases pass (five external/marker cases and
  56 SSE cases), and the shared analyzer is clean. Destinations are excluded
  from generated presentation. No producer, route, modern filter, UI, native
  reply or database change is claimed by the codec foundation.

- Step 17 architecture implementation pass 1 approved all 15 staged paths
  against `182b1e8519` (B-Shared only); no findings. All sixteen published PR
  titles are synchronized to the 24-step plan. Historical squash titles and
  prior tracker evidence remain unchanged. The wire successor remains local
  until the controls parent completes native/visual qualification and merges.
- Earlier draft controls CI reported 19/19 passing. GitHub rejected that
  auto-merge attempt because the PR was draft. Native presentation qualification
  subsequently passed; the current controls head is in review.

- Step 16 accepted head `533093e0e2` merged as `ea65f5b045` after all nine
  findings received prefixed replies and the follow-up review approved with zero
  issues. CI passed 20/20 before merge; the terminal report had a new post-merge
  check running, so it is not recorded as 21 passing checks.
- Step 17 synchronized onto that squash and the newer main toolchain. Public
  production remains v1.9.1; compatibility comments use the current product
  version v1.9.2 without treating that development version as released. Filtered
  code generation completed with Dart 3.13.5 / Flutter 3.47.7, and 143 unrelated
  tracked generated deletions were restored. The same 61 shared cases pass on
  the synchronized source, and its shared analyzer is clean. The preceding
  architecture approval and exact public codec proof remain applicable.

- Step 17 initial publication [#1981][pr-1981] is the `git diff --numstat` range
  `ea65f5b045ba5fc5200704f1eb55bf73408c4751` to
  `e1016a5e7b82c34d311e2f1447a5190ea54407ed`: 895 additions + 25 deletions =
  920 changed lines across 14 files. Files ending in `.freezed.dart` or `.g.dart`
  account for 650 generated lines; the remaining 270 lines are authored. This
  step changes no localization source or generated localization output.

[pr-1981]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1981

- Step 17 accepted head `253e167066` merged as `cfecaf9494`. Both documentation
  findings were fixed and the follow-up review approved with zero issues. The
  codec/runtime split finding received a reasoned prefixed decline and remains
  deliberately unresolved; it did not identify a runtime defect. CI reported
  32/32 passing before merge and 33/33 in the terminal report.
- Original 8.d.2 splits into headless/native routing (ordinal 18, 8.d.2.a) and
  typed client presentation (ordinal 19, 8.d.2.b). The native draft already totals
  637 changed lines across 35 files before route tests, client presentation and
  docs. This keeps both complete review boundaries near the soft cap. Native
  producers land with URL-free cancel-only notices and a safe client handoff;
  the typed browser/consent modal follows immediately. The current series total
  is 25; final L4/native/provider/package requirements remain unchanged.

- Step 18 implements native URL requests in Claude's existing approval owner,
  active-only headless snapshot/reply routes and archive validation, plus the
  client's explicit cancel-only handoff. It preserves original child ownership,
  keeps URLs out of broadcasts, rejects unsafe destinations before disclosure or
  acceptance, and uses native cancellation for legacy replies and teardown.
- Focused checks: 89 Claude cases; 46 bridge repository/service/mapping cases;
  33 route/service cases after final routing edits; 22 question-modal widgets;
  13 core permission/cold-load cases. The cold-load test preserves the external
  marker and child cancellation owner. Seven owning package/module analyzers
  pass. Architecture implementation review approved with no findings.
- Exact isolated macOS arm64 native runs exercised the production registry:
  Claude 2.1.291 URL accept/decline/cancel all settled with the original native
  request ID; 2.1.221 rejected URL elicitation before forwarding. Both pins
  forwarded unsupported forms and received native decline plus the existing
  session-attributed warning. This checks protocol/registry integration, not
  real-provider authorization, browser completion or packaged app qualification.
- Native synthetic handoff fixture built successfully. On 2026-10-15 the user
  explicitly deferred recording and asked to continue code work while the Mac
  was locked. Publish the native routing step with that presentation evidence
  pending; record it later. This defers timing only and does not reduce the
  final L4/native/provider/package qualification matrix.

[pr-1984]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1984

- Step 18's initial checks above ran from the uncommitted implementation later
  recorded in `fa2c98fd97f10e3b4c49b005b64344fa92ef3fb8`; publication head
  `84b723c661e82f7748e48f24008014ceeb19d494` changes only the recording-deferral note.
  SDK: Dart 3.13.5 from Flutter 3.47.7. Working directories below are relative to
  this repository's dedicated `copper-heron` checkout. Focused commands:
  - `bridge/sesori_plugin_claude`: `dart test test/claude_stream_client_test.dart test/claude_approval_registry_test.dart test/claude_plugin_impl_test.dart` (89).
  - `bridge/app`: `dart test test/bridge/repositories/external_action_repository_test.dart test/bridge/services/pending_interaction_service_test.dart test/bridge/repositories/question_repository_test.dart test/bridge/repositories/mappers/session_event_mapper_test.dart` (46).
  - `bridge/app`: `dart test test/bridge/repositories/external_action_repository_test.dart test/bridge/services/pending_interaction_service_test.dart test/bridge/routing/get_project_questions_handler_test.dart test/bridge/routing/get_session_questions_handler_test.dart` (33).
  - `client/module_app_ui`: `flutter test --no-pub test/features/session_detail/widgets/question_modal_test.dart` (22).
  - `client/module_core`: `flutter test --no-pub test/cubits/session_detail/session_detail_cubit_permission_test.dart` (13).
  - `bridge`: `dart analyze --fatal-infos <package>` for `app`, `sesori_plugin_interface`,
    `sesori_plugin_claude`, `sesori_plugin_opencode`, `sesori_plugin_pi`; both client
    modules: `flutter analyze --no-pub --fatal-infos`.
- Native protocol and UI-fixture checks are explicitly uncommitted fixture runs,
  not packaged-product checks. From checkout root, native command:
  `node /private/tmp/copper-heron-mcp-step18-native-probe.mjs`; source package
  configuration: `bridge/.dart_tool/package_config.json`. At production head
  `84b723c661`, the stronger review probe captured MCP initialize capabilities:
  2.1.221 sends `elicitation: {}`; 2.1.291 sends `elicitation: {form: {}, url: {}}`.
  All six native cases pass with URL-mode negotiation asserted. The host's empty
  elicitation opt-in is not the native MCP capability advertisement.
  Fixture SHA-256 values: probe `164b0ac2273708faf17a371c5beb437344955f5bad5e452d5d384a2880bd26e1`,
  production-registry worker `0b31b67b02105e8020bbabf24f89c0d2a5ddb2c29c7494a257b381f931250737`,
  capability capture `c22e033f1eb2e9fa067f06e6eea315876fe16fdfdf990e5ffa3f2457c02f4002`.
  UI command from `client/desktop`: `flutter build macos --debug --no-pub --target /private/tmp/copper-heron-mcp-step18-handoff-fixture.dart`;
  fixture SHA-256 `9ff466ca3cb25a178e3f5c81df7e35e171d577c1e3ee947108a395e62ea4c3ee`.
  Build succeeds; native presentation remains unrecorded per the user's deferral.
- Review archive-read regression failed before the one-owner binding filter and
  passes afterward, through both direct and display-parent reads. The same
  four-file bridge command above now passes 47 cases; `bridge/app` analyzer is clean.
  Verified source tree: `32764caae11fb0f193e26d2c0ce8fc1660e3feaf`; subsequent
  edits add only this evidence reference, with production and tests unchanged.

- Step 19 implements shared typed external-action controls through the existing
  SessionApi/Repository layers, a stateless service and a per-modal Cubit. The
  existing pending-request list remains authoritative. Both shells supply the
  typed factory; shared presentation resolves no service locator. Explicit
  browser intent, declared native choices, dismissal-only close, read-failure
  legacy cancellation and connection fencing are covered locally.
- Focused Step 19 checks: 19 core API/service/lifecycle cases, 29 shared modal
  widgets, 207 mobile session-body/navigation cases and 13 desktop session-view
  cases. Core, shared UI, mobile and desktop analyzers are clean. DI and
  localization outputs are generated from source. Native presentation recording
  remains deferred; local widgets do not establish packaged/native qualification.
- The analytics checklist was applied: browser opening and native response
  acceptance cannot prove authorization completion. No new event is added
  without an honest product outcome/reporting contract. Architecture plan review
  approved the concrete client-only flow after its file/layer map was clarified.
- Step 19 architecture implementation review approved without findings. The two
  final targeted cases retain a thrown browser error and stack without URL
  presentation, and acknowledge/dismiss a request already settled while closed.
  Their commands are the corresponding test files with `--plain-name 'thrown
  browser failures retain'` and `--plain-name 'a request settled while closed'`;
  they pass in addition to the preceding 18 core and 28 shared UI cases.
- Step-18 second review fixes move destination policy into PendingInteractionService
  for both snapshot reads and acceptance, retaining canonical access in the repository.
  Public-client cancel projections now carry dated retirement conditions. Typed
  notices retain neutral request/Review wording after dismissal and do not emit
  ordinary-question outcome analytics. The banner and analytics regressions failed
  behaviorally at published head `e6162c78b9` before the fixes.
- Review-fix checks use the same pinned SDK and working-directory conventions above:
  the four-file bridge command passes 47 cases; the core permission command passes
  13; from `client/app`, `flutter test --no-pub test/features/session_detail/widgets/session_detail_body_test.dart`
  passes 197. Full bridge, core, shared-UI and mobile analyzers plus targeted Claude
  analysis pass. Architecture implementation review pass 2 approves without findings.
  Verified review-fix tree: `767dcaf79a75c1d3dd8342db0d6d819827ed2c0d`;
  subsequent edits add only this evidence reference. Final diff is 1,641 changed lines.
- Step 19's initial implementation is recorded in `10660b7f2b`, based on
  `e6162c78b9`. Integrated parent fixes `4086e6e93c` without rewriting either history;
  localization outputs were regenerated from the combined source. Verified merged
  source commit: `a8a8a5695e`; its production/test sources match the verified merge.
  With Flutter 3.47.7 / Dart 3.13.5, affected integration checks pass: from
  `client/module_core`, `flutter test --no-pub test/cubits/session_detail/session_detail_cubit_permission_test.dart test/api/session_external_actions_api_test.dart test/services/session_external_action_service_test.dart test/cubits/session_detail/session_external_action_cubit_test.dart`
  (32); from `client/module_app_ui`, `flutter test --no-pub test/features/session_detail/widgets/question_modal_test.dart test/features/session_detail/widgets/external_action_modal_test.dart`
  (29); from `client/app`, `flutter test --no-pub test/features/session_detail/widgets/session_detail_body_test.dart test/features/session_detail/widgets/adaptive_child_session_navigation_test.dart`
  (208). Each of those three modules passes `flutter analyze --no-pub --fatal-infos`.
- CI at `4086e6e93c` found `prefer_exhaustive_switch` in the new analytics guard.
  Package-level analysis had missed the workspace plugin diagnostic. Replaced its
  wildcard with all three non-loaded sealed states; behavior is unchanged. Source
  tree `988213c63ffbf663634de63615747c0c474d9193` records that correction.
  `dart analyze --fatal-infos` from `client` now passes with the CI plugin enabled.
- Step 19 incorporates `935f4c79e4`. CI-equivalent workspace analysis identified
  four successor-only lint issues, corrected with promoted local state snapshots,
  an explicit nullable-destination check and directional padding. `dart analyze
  --fatal-infos` from `client` passes. The affected Cubit and modal test files
  pass 9 and 7 cases respectively; modal taps target the actual buttons with no
  hit-test warnings. Verified source commit: `22358bd5f2`.
- Step 18 merged at accepted head `935f4c79e4`, squash `834374b34f`; 31 checks
  passed before merge and 32 in the terminal monitor report. Three deliberately
  declined threads retain their prefixed explanations. Step 19 merged current
  main without rewriting history and preserves its Computers-page changes.
  Synchronized source commit `1585422cc5` passes the same
  32 core, 29 shared modal, 208 mobile and 13 desktop cases using commands above
  (desktop: `flutter test --no-pub test/features/sessions/desktop_session_detail_screen_test.dart`).
  Client-root `dart analyze --fatal-infos` also passes. The published commit differs
  from the tested snapshot only in tracker publication state and this record.

[pr-1986]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1986

- Step 19 is published as #1986 at `1585422cc5`, with 1,318 changed lines
  (1,173 authored and 145 generated). Its monitor is active; native recording remains
  deferred. Old form step 20 is split into contracts/native-headless/client substeps
  9.a–9.c, ordinals 20–22. Old steps 21–25 become 23–27; the new series total is 27.
  Feature scope and final L4/native/provider/package requirements remain unchanged.
- Step 20 implements shared-only typed form contracts, strict integer/finite-number
  serialization and explicit unknown variants. No native/client capability is
  claimed yet. Architecture plan and implementation reviews both approved without
  findings. New mutable-state budget: zero. Published PR titles 1–19 now use /27;
  historical squash commit messages remain unchanged.
- Step-20 checks on Flutter 3.47.7 / Dart 3.13.5, from `shared/sesori_shared`:
  ```sh
  dart test test/models/pending_form_test.dart \
    test/models/pending_external_action_test.dart test/models/sesori_sse_event_test.dart
  ```
  The command passes 70; `dart analyze --fatal-infos` passes. Full `dart run build_runner build`
  succeeds, preserving all pre-existing generated codecs. Filtered generation had
  deleted 166 unrelated generated files; those were restored before the full run.
  Codec/default/validation contents do not appear in generated diagnostic strings.
  Verified source commit: `d62d2d501b`; its production/test sources match the
  tested snapshot, with only the tracker evidence reference differing.

- Step-19 review fixes redact URL-bearing snapshot error bodies, remove copy that
  promises undeclared actions, reconcile tracker publication state and distinguish
  thrown browser errors from false-return failures. Declared decline/cancel for
  unsupported destinations remain intentional; browser access and acceptance stay blocked.
- The SSE-before-reply regression was behaviorally red at `1585422cc5`: the modal
  closed without opening the next request. The existing pending-dismissal guard now
  notifies its presentation owner once; no new mutable state or late-reply owner.
  That full session-screen case passes, as do both new error-body redaction cases.
  Checks: 3 API tests, 40 shared request-modal widgets, 209 mobile session/navigation
  tests; client-root `dart analyze --fatal-infos` passes. Commands use the same
  pinned SDK and package paths above; new API/sequence regressions extend those files.
  Architecture implementation review pass 2 approved without findings.
  Verified review-fix source commit: `f46ee6b4c9`; its production/test sources
  match the verified tree. References above use published commits reachable from
  this PR, rather than intermediate local-only trees.
- Follow-up review adds the existing mounted-page guard to the dismissal callback.
  The full-screen SSE sequencing regression still passes; workspace-plugin analysis
  of `session_detail_body.dart` passes. Each replacement source commit above is an
  ancestor of the pushed head and differs from its tested snapshot only in TRACKER.md.
- Step 19 merged at accepted head `3efd585b99`, squash `db22ff3b68` after all 20
  pre-merge checks passed (21 in the terminal report). The two declared-negative-response
  policy threads remain deliberately open with prefixed explanations. The Step-20 branch incorporated
  current main while #1989 remains in review, preserving concurrent computer-management and Linux-distribution work.
  Its shared source, tests, dependencies and SDK pin are unchanged from tested commit
  `d62d2d501b`; no unchanged passing suite was rerun solely for confidence.
- Step-20 review reproduced a real JSON-decoding failure: generated code cast
  `fieldErrors` to `Map<String, String>` before conversion. The decoder now accepts
  the JSON map boundary and validates string entries inside the converter.
  The JSON-round-trip regression failed before the fix and passes afterward;
  all 71 focused shared tests and `dart analyze --fatal-infos` pass at source
  commit `9eaf60b35a`. Full code generation succeeds. Native date-time spellings
  remain plugin-owned; all normalized Sesori text-format names round trip.

[pr-1989]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1989

- Step 21 separates native form handling (9.b.1) from canonical headless routing
  (9.b.2, new ordinal 22). Native production/tests already exceed 1,100 lines before
  route coverage. Client forms move to 23, Codex to 24–25, secondary harnesses to
  26, reconciliation to 27 and final qualification to 28. Scope and retirement
  matrix are unchanged. No new pending registry, timer, queue or persistence.
- Architecture plan review identified the existing repository interaction-kind
  mapper as the required shared boundary. Added its form case for both live SSE
  and REST notices; no parallel mapping in handlers or event consumers.
- Inspection of canonical archive confirmed it is permanent and does not stop
  Claude. The existing plugin archive notification now delegates to the existing
  pending owner cancellation; a native form cannot remain unanswerable afterward.
  No new lifecycle subscription or owner is introduced.
- Step-21 source commit `75ac1b1a95` implements the native plugin boundary only;
  headless form routes and client forms remain unimplemented. The first focused
  run passes 92 cases across `claude_form_schema_test.dart`,
  `claude_approval_registry_test.dart` and `claude_plugin_impl_test.dart` from
  `bridge/sesori_plugin_claude`. After adding archive cancellation, the changed
  plugin integration file passes all 40 cases. Use pinned Dart 3.13.5 `dart test`
  with those paths. Bridge-root `dart analyze --fatal-infos` for
  `sesori_plugin_claude`, `sesori_plugin_interface` and the changed repository
  interaction-kind mapper passes; the archive source/test analysis also passes.
  Full plugin-interface code generation succeeds and changes only its form enum entry.
- Ten exact-pin native fixture cases pass on Claude 2.1.221 and 2.1.291: both
  form accept/decline/cancel sets, target URL accept/decline/cancel and minimum
  native URL rejection before forwarding. The native MCP peer observes the
  production registry's exact typed content, distinct option values, optional
  text omission and negative replies. An invalid submission retains the same
  request before correction. This qualifies the isolated native adapter seam,
  not headless/relay/client ownership, real providers, packaged clients or UI feel.
  Recording remains deferred; final coverage remains required.
- Private Step-21 probe input SHA-256 values:
  - `native-probe.mjs`: `93f5533750b22f21b6a51447d9ca13aaf32771b9210687f133765adae77ae179`.
  - `native-worker.dart`: `6e3a445d5ec90113889965b1d13e419401bdfdf095d97c804adca3975f596fbe`.
  - `native-capability-fixture.mjs`: `6ec0a109276d05d154ee1eb10b8990fdb64f00b5f497d72aaafc38664d5d72d8`.
  Inputs and result log are retained under the private `copper-heron-mcp-step21-`
  artifact prefix. Fixture/model sources originate in `tool/mcp-contracts/fixture.mjs`.
- Published PR titles 1–20 now use the current /29 total. Historical squash
  messages remain unchanged. The final qualification matrix is not reduced.
- Step-21 architecture implementation review pass 1 approved source range
  `1d284e4629..75ac1b1a95` without findings. The later tracker evidence record
  changes no production or test sources.
- Step 20 merged at accepted head `1d284e4629`, squash `feb6f77858`, with 32
  checks in the pre-merge snapshot and a clean final Cubic approval. The normalized native-format
  spelling suggestion remains deliberately declined with a prefixed explanation.
  The Step-21 branch incorporated current main; each conflicting incoming document was verified
  byte-identical to the already incorporated parent. The merge changes no files
  from approved source `ced5e6797a`, so no unchanged passing suite was rerun.

[pr-1991]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1991
[pr-1992]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1992
[pr-1993]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1993
[pr-1995]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1995
[pr-1999]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1999

- Step 20's later terminal monitor snapshot records 33 passing checks; the 32
  above is the earlier pre-merge snapshot. Step 21 was
  published as #1991 at `0dd7b76ca1`: 1,340 changed lines, one generated and
  1,339 authored. Its monitor was started at publication. Native recording remains deferred.
- Step 22 implements FormRepository, neutral mappings and the three form routes
  through the existing PendingInteractionService, dispatcher and archive validator.
  Optional-plugin reads remain active-only, snapshots filter the actual owner,
  replies require the exact original backend session, and typed unknown values
  cannot reach native submission. No new mutable owner, persistence or coordination.
- Step-22 source `04fb37e065` passes the initial 59 focused cases from
  `bridge/app`, using pinned Dart 3.13.5:
  ```sh
  dart test test/bridge/repositories/form_repository_test.dart \
    test/bridge/repositories/external_action_repository_test.dart \
    test/bridge/services/pending_interaction_service_test.dart \
    test/bridge/routing/reply_to_question_handler_test.dart \
    test/bridge/routing/reject_question_handler_test.dart \
    test/bridge/routing/reply_to_permission_handler_test.dart
  ```
  After adding unsupported-plugin and both archive-route checks, the changed
  `form_repository_test.dart` passes all 15 cases. Bridge-root
  `dart analyze --fatal-infos app` passes. Architecture implementation review
  pass 1 approves all 15 changed files without findings. Initial authored churn:
  787 lines; zero generated. Native/relay/client/provider/package boundaries and
  deferred recording remain unqualified by these headless API fixtures.
- Step-21 review regressions failed before their fixes: a failed archive write
  lost the pending request and emitted false settlement, and equal option titles
  discarded differentiating descriptions. Source `5d9fa31baf` retains failed
  archive cancellations in the same owner and includes descriptions in labels,
  preserving opaque IDs/native values. Existing teardown still retires stopped
  requests. All 95 focused schema/registry/plugin cases and Claude analysis pass.
- Rechecked public v1.9.1 source `8bfeda9416c96ea5de70ffc701a36b738f24eff7`:
  its snapshot/SSE question models have no interaction-kind enum, and generated
  decoders ignore the additive marker. All nine source/generated fixture files
  match that release byte-for-byte; Step 17's executable proof already covers
  both form and external-action markers. No new legacy wire fallback is needed.
  Corrected final qualification to step 28 and clarified the branch/main merge.
- Step-21 architecture implementation review pass 2 approved the complete PR
  through source `5d9fa31baf`, including archive settlement, without findings.
- Step 21 merged at accepted head `b9f0cad1db`, squash `5765963a81`, with 19
  pre-merge and 20 terminal checks passing. The declined released-codec concern
  remains open with its prefixed source-backed explanation. Final native diff:
  1,447 lines, one generated. Step 22 incorporated those review fixes and current
  main, preserving concurrent debug-server response-lifetime fix `10b6e87325`.
  Each conflicting incoming document matched the integrated native parent
  byte-for-byte. At that integration checkpoint, Step-22 production, tests,
  contracts and dependencies matched tested `04fb37e065`; the unrelated
  debug-server file was outside those route fixtures. The later review-only
  regression in `fc8a80e766` expanded the form suite from 15 to 16 cases, as
  recorded below. No unchanged passing suite was rerun solely for confidence.
- Step-22 review clarifies 32 pre-merge versus 33 later terminal checks for
  Step 20. Actual-owner archive policy remains intentional: archiving only a
  display parent must not retire an active child's independently answerable form.
  The new direct/display-read and original-child reply regression passes with
  all 16 form cases; targeted analysis passes. Source: `fc8a80e766`.
- Step 23 is split into client foundation (9.c.1, ordinal 23) and visible controls
  (9.c.2, ordinal 24): the foundation alone measures about 1,000 lines before UI.
  Former ordinals 24–28 become 25–29. This independently compiling split adds no
  compatibility scaffolding and does not change the final qualification matrix.
  The complete client architecture plan was approved before implementation.
- Step-23 foundation preserves typed defaults and optional omission, raw numeric
  drafts, field-specific validation and typed error causes. One modal-scoped Cubit
  retains drafts on failure and permanently retires old-connection controls;
  existing pending-list ownership remains unchanged. All 29 core form cases,
  two desktop DI cases and seven mobile DI cases pass. Client-root analysis with
  the repository plugin passes. Visible controls are the next independent step;
  no native recording or provider/package qualification is claimed here.
- Step-23 architecture implementation review pass 1 approved the complete client
  foundation without findings. Production boundaries and test inputs were unchanged
  after the passing focused checks; generated DI output remains with its source.
- Step 22 merged at accepted head `960468bf0f`, squash `0483482b2e`, with 19
  pre-merge and 20 terminal checks passing. The latest Cubic review approved with
  zero new issues; the declined actual-owner cascade concern retains its explanation.
  Step-23 source `065329c44d` contains the verified client foundation. Merge
  `8201540472` integrated the parent; all three conflicting incoming documents
  matched the already integrated parent byte-for-byte. Production/test inputs and
  dependencies did not change, so no unchanged passing suite was repeated.
- Step-23 review corrected four publication/Markdown notes in `84aea1db7a`.
  Connection retirement intentionally retains the independent submission snapshot:
  the consumer prioritizes the connection-changed explanation and disables all
  response controls. Existing source checks remain unchanged. The narrow ApiError
  catch suppressions preserve the repository's expected typed transport causes.
- Step-24 shared form controls preserve keyed text/focus ownership, raw numeric
  drafts, optional omission, explicit Yes/No and opaque choice values. Declared
  bounds and requiredness are visible. Error/status space stays reserved; busy
  inputs are read-only, and settlement preserves content during the closing
  transition. Both shells provide the factory through the presentation scope.
  Native recording remains deferred in timing only; final qualification is unchanged.
- Step-24 verification passes: eight shared form widget cases, two form/URL
  settlement scheduler cases and 13 desktop session composition cases. Form
  controls retain focus/selection and field height through busy/validation states;
  raw drafts, optional clearing, boolean/choice typing, narrow 2x text, reduced
  motion, unknown-schema refusal and retired-connection presentation are covered.
  The final widget run has no missed-tap warnings. Client-root analysis with the
  repository plugin passes. Architecture implementation review pass 1 approved
  the shared modal/editor, scope and shell composition without findings.
- Step 23 merged at accepted head `84aea1db7a`, squash `9c4b5341d6`, with 20
  pre-merge and 21 terminal checks passing. Its declined snapshot-reset concern
  remains explained; the UI regression verifies connection-changed presentation
  takes priority over retained submission state and that late acceptance is fenced.
  Merge `eebc0578c3` integrated the foundation into Step 24. All three conflicting
  incoming documents matched the already integrated parent byte-for-byte.
- Step-24 source `83971467a5` includes fixture-driven compact constraint captions.
  Eight widget cases and a separate synthetic before/after render pass together,
  with zero missed-tap warnings; final client-root analysis passes. The two
  scheduler and 13 desktop composition cases passed before the caption-only change.
  Inspected fixture images contain synthetic data only; native motion recording
  and the real provider/relay/package matrix remain deferred qualification work.
- Step-24 review source `3654f20c9b` reserves the keyboard inset, using bottom
  safe-area padding only when no software keyboard is present. The phone case
  failed before the fix: viewport bottom 704 exceeded keyboard boundary 524.
  All ten form widget cases and client-root analysis now pass, with no missed-tap
  warnings. New UI-to-repository coverage preserves explicit empty text/arrays
  separately from omission; Clear answer remains the omission action. Native
  motion qualification is explicitly pending. Keyboard-closed screenshot inputs
  are unchanged; no unchanged passing scheduler/desktop suite was repeated.
- Step-24 follow-up pins submission status above the scrolling fields. Both
  validation and transport-failure regressions reproduce hidden feedback on the
  prior implementation (status top -542), then pass without moving the scroll
  position or replacing drafts/controllers/selection. All 12 form widget cases
  and client-root analysis pass. The initial-position fixture image is byte-identical
  to the published screenshot; native motion recording remains deferred.
- Step 25 is split into read-only Codex inventory (10.a, ordinal 25) and native
  OAuth ownership (10.b, ordinal 26). The inventory source alone measures about
  932 lines including 349 generated lines. Remaining ordinals shift by one to
  a single total of 30; the final qualification matrix is unchanged.
- Codex inventory uses generated typed native DTOs, a stateless repository/mapper
  and the existing attached app-server owner. Session and harness reads consume
  every page; project scope is explicitly unsupported. Minimum-version omissions
  stay unknown. No implicit connect, session start/resume, native tool call,
  configuration write or per-server control is introduced. Native OAuth remains
  not implemented for the next step; no duplicate authentication owner is added.
- Step-25 verification: 22 focused MCP repository/plugin cases pass, including
  complete pagination, exact context, malformed/later-page failure, safe metadata,
  independent discovery/runtime/auth state and detached/disconnected lifecycle.
  The initial combined run also passed 16 existing API/plugin cases. Normal code
  generation and bridge-root package analysis pass. Architecture plan and
  implementation review pass 1 approved the inventory boundary without findings.
- Both exact Codex binaries retain their recorded fingerprints. An isolated
  generation-bound HTTP fixture showed status discovery opens new connections
  but resident tool calls retain the original connection even after config reload.
  Therefore no reconnect/toggle/forget action is advertised. Six captured native
  status pages pass through the new production decoder/repository, three per pin.
  These are native JSON and adapter checks, not provider/relay/packaged qualification.
- Step 24 merged at accepted head `bb5bd92929`, squash `5d429a126f`, with
  20 pre-merge and 21 terminal checks passing. Fresh Cubic review approved with zero issues;
  Codex code/security reviews completed. No newly actionable threads remained;
  the two declined empty-to-omission suggestions retain their explanations.
- Step-25 inventory review fixes preserve unknown authorization on absent/null
  metadata, stable tool ordering, original local discovery diagnostics and safe
  remote failures. Cold native threads return live-session-required without
  resume/fallback; disconnected project scope remains explicitly unsupported.
  Both native schemas make nextCursor optional, so omission remains a valid
  terminal page. No speculative cursor registry or new unadvertised action wire
  outcome was added; local diagnostic causes remain useful as required by AGENTS.md.
- Review verification passes: 30 MCP cases plus five existing account API cases,
  normal DTO generation and bridge-root package analysis. Exact native restarted
  app-servers at both pins reproduce the cold-thread error. Documentation now
  distinguishes existing generic Codex elicitation from the upcoming typed native
  integration and includes native server titles/descriptions in the metadata boundary.
  Architecture implementation review pass 2 approved the complete PR/worktree
  boundary with no findings; the separate OAuth draft remains excluded.
- Step 25 merged at accepted head `f1f7d9cd8b` after 19 passing pre-merge checks,
  fresh Cubic zero-issue approval and completed current-head Codex code/security
  reviews. Five declined suggestions retain their prefixed explanations.
- Step 26 uses the existing native-settlement operation and canonical bridge owner.
  Native DTO/API, exact callback forwarding and a per-connection resource service
  add no shared contract, client owner or credential store. Native cancellation
  remains unavailable. Lazy preparation, exact server/thread correlation, native
  expiry/denial and uncertain-response ownership are covered without a local timer.
- OAuth verification: 22 authentication cases, 35 inventory cases and 13 MCP
  plugin/existing plugin-client cases pass; normal DTO generation and package
  analysis pass. The 13 include the new active-sign-in WebSocket disconnect case.
  Both fingerprint-verified native pins pass the production DTO/API/repository/
  service plus loopback callback forwarding for expiry, denial and success, then
  report authenticated inventory. Final native reruns also include safe diagnostic
  categories and repository-owned completion mapping; 22 auth/MCP-plugin cases and
  package analysis pass after that correction.
  This is isolated macOS arm64 plugin/native evidence, not real provider, shared
  headless HTTPS/browser, relay/client, packaged or native-feel qualification.
- OAuth architecture implementation pass 1 found API completion DTOs crossing the
  repository boundary. Mapping now occurs in the repository, exposing sealed
  completed/failed models; the service no longer imports API DTOs. No shared
  contract or ownership change was needed.
  Architecture implementation pass 2 approved the complete corrected boundary
  without findings; the final 22-case and native-pin reruns include that mapping.
- A pre-publication same-name harness/session override probe found minimum
  0.139.0 ignores OAuth thread context and selects the harness issuer; target
  0.160.1 selects the session issuer. The existing initialize user agent gates
  session sign-in to versions at least 0.160.1; older/unknown runtimes return
  native-configuration handoff before OAuth, retaining harness sign-in.
  The final 70 focused cases and package analysis pass after this localized
  correctness fix. Actual native reruns verify minimum session refusal with no
  OAuth RPC, minimum harness expiry/denial/success, and target session
  expiry/denial/success. No new architecture boundary or contract was added.
- OAuth PR #2000 review tightened session completion to an exact thread match;
  harness completion alone may omit it. Callback timeouts now abort HTTP work,
  verified with stalled-header and stalled-body sockets. Inventory coordination
  moved to the existing service; the repository maps API data only. Original
  inventory failures remain in useful local logs while presentation stays safe.
  All 26 affected auth/MCP-plugin cases and package analysis pass; both exact
  native pins pass the corrected production adapter journeys. Six findings were
  addressed. Fixed-query callback machinery was declined: both pinned native
  listeners advertise query-free callback URIs, so no supported flow alters a
  fixed callback query. No third architecture review was invoked.

- Step 27 separates typed pending-request integration from connector catalog/setup
  work (now 28), keeping both coherent native boundaries below the PR size cap.
  The series total is 31; final L4 scope remains unchanged. Architecture plan
  review approved typed requests, the single shared pending owner and plugin-local
  schema mapping without findings. OAuth #2000 remains monitored while 27 is local.
- Step-27 exact native fixtures found integer bounds serialized as JSON numbers
  (`1.0`/`3.0`), unlike the initial scalar unit fixture. The Codex mapper now
  preserves integer semantics, including fractional inward bounds and integral
  defaults. Both exact pins pass form/URL accept/decline/cancel, legacy cancellation
  and session teardown through production parser/schema/registry. Thirteen typed
  request cases, existing approval cases and 23 shared-registry/ACP cases pass;
  owning-package/caller analysis is clean. A real-WebSocket plugin case verifies
  detached reads issue no connection and foreign-session replies cannot settle a
  native form. Synthetic before/after renders pass; recording remains deferred.
  Architecture implementation review approved the complete production boundary
  without findings. No second pending owner or shared/wire contract was added.
- A later code review found unknown native auth status could enable sign-in.
  Unknown/omitted status now declares unavailability and stops both harness and
  session starts at inventory, with no OAuth RPC. Focused mapper/service coverage
  retains known-version and native-unsupported behavior without a new contract.
- OAuth #2000 merged at accepted head `20f2498313`, squash `1742753442`,
  with 20 terminal checks passing, Cubic zero-issue approval and completed
  current-head code/security reviews. The remaining tracker thread ends with
  Cubic's approval acknowledgement. Step-27 parent integration `690e33e95f`
  changes no bytes; all three conflicted incoming files exactly matched the
  already-integrated reviewed OAuth parent.

- Step-27 review corrections accept finite integral JSON count constraints and
  native titled multi-select items (`anyOf`, without item type). Both exact native
  schemas restrict single-select choices to enum/oneOf; they do not expose
  string-level anyOf. All 42 typed-request/approval cases and package analysis
  pass; both native pins pass the titled-array variant. Displayed labels may
  fall back to native names/values; opaque aliases protect submitted IDs.
  Connector catalog/setup split into 28/29 keeps future boundaries reviewable;
  remaining series total is 32 and final qualification is unchanged.
- Step 28 separates read-only native catalog discovery from setup across the
  plugin/wire/headless/client browser boundaries (now 29). Existing connector
  variants serve inventory without a contract change; setup requires its own
  reviewed action/result boundary. Total 32; final L4 scope is unchanged.
  Architecture plan review approved catalog mapping and server-only auth reads.
- Step-28 verification: all 69 focused inventory/authentication/plugin cases
  pass, package analysis is clean and normal DTO generation passes. Both exact
  native binaries return an available empty catalog through production API and
  repository mapping. Their authentication journeys issue no app/list calls;
  minimum session handoff and native expiry/denial/success remain verified.
  This does not qualify real authenticated offers, entitlement or setup.
  Architecture implementation review approved the catalog boundary; synthetic
  before/after inventory captures are prepared. Native recording stays deferred.
- Step-27 follow-up review: forwarded legacy titled enums retain matching
  enumNames. Native 0.139.0 omits enumNames, so its production snapshot falls
  back to native values; 0.160.1 forwards and displays the provided titles.
  The direct parser test verifies forwarded display names and native encoding.
  Ambiguous field headings/complete option labels
  explicitly decline; unsupported child warnings use the root display session,
  with global warnings retained for missing owners. All 45 directly affected
  typed-request/approval cases pass and package analysis is clean. Both pinned
  binaries pass native round trips with explicit normalized-label assertions.
  The earlier stale capability sentence was already corrected in `629d2cecfc`.
- Step-27 final schema review rejects blank labels and choice-array minima
  above the editor's available options. All 46 directly affected tests pass;
  package analysis is clean. The three long plan prose lines are wrapped within
  this production correction, without a separate bookkeeping review wave.
- Second/final step-27 architecture implementation review approved. Base
  `1742753442` already owns pending mutation/SSE in the shared registry;
  settlement extraction adds no owner. Relocation would widen this feature.
- Step 27 merged as `0beb720550` with 20/20 checks passing; current-head code
  and security reviews completed, Cubic approved. The pre-existing registry
  relocation request is declined with architecture evidence. Catalog integration
  changes no bytes: incoming conflicted files exactly match reviewed `10f44c1153`.
  Catalog before/after fixture images are published on orphan pr-media commit
  `579348b385d58962281b163e57f128251ea37965`.
- Step-28 review reconciles the top-level regression summary with the detailed
  implemented catalog section and capability document. Setup remains separate.
  Delivery rows use short references; the current state points to PR #2003.
- Step-28 server failure now preserves healthy connector discovery. Unsupported
  or live-session-required scopes still stop before catalog access. Server
  transport/decoder failures retain original local diagnostics and expose only
  that section as unavailable. All 45 affected repository/plugin cases pass;
  package analysis is clean. Earlier 25 authentication cases are unchanged.
- Step-29 plan and implementation architecture reviews approved. The local
  setup draft resolves native catalog destinations through distinct offer
  actions, validates HTTPS at the bridge boundary, and uses the existing client
  view action owner/UrlLauncher with no URL observables or new callback state.
  All 138 directly relevant wire/plugin/route/client/widget cases pass. Owning
  analyzers are clean. Both exact Codex binaries pass force-refetched empty
  native catalogs; original OAuth scope/completion behavior remains intact.
  Synthetic controls/opened-feedback renders pass and were inspected. Native
  recording and real connector/provider/package/L4 qualification remain pending.
- Step-28 diagnostic follow-up names harness or the actual native thread in
  failed server reads, retaining original causes/stacks. All 42 repository tests
  pass with both contexts asserted; package analysis is clean.
