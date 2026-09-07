# DeepSeek atomic scoped stop

## Decision and delivery

The user approved an owned adapter change and release before bridge completion.
Use native atomic cancellation, not a bridge stop fence. Original #1346 merged at
`2cc1485d7cc3c180cfd949cbed85d579a708f191`; adapter 0.1.4 and this consumer close
its request-time snapshot limitation.

Fixed scoped-stop subseries (existing final regression/E2E/retirement gates stay):
1. `⚙️ [claude-inline-subtasks] DeepSeek scoped sub-agent stops [step 1/4]` — #1346, merged.
2. `🚧 [claude-inline-subtasks] DeepSeek atomic subtree cancellation [step 2/4]` — adapter #17, merged.
3. `🌱 [claude-inline-subtasks] Prepare DeepSeek atomic-stop 0.1.4 release [step 3/4]`
   — adapter #18 merged; v0.1.4 published and independently verified.
4. `⚙️ [claude-inline-subtasks] DeepSeek stop covers in-flight child launches [step 4/4]`
   — bridge consumer and verified pin implemented here; final E2E stays separate.

Human merges each PR. Use the existing native checkout; never create a worktree.
Finish DeepSeek E2E after these steps, then Codex. Automatic runtime upgrades are
separately owned. Package tests do not discharge the phone/desktop matrix.

## Native authority

Add `deepseek/session/stop` with a discriminated request:
- `{kind: "session", sessionId}` targets a bridge-owned resident activity.
- `{kind: "child", sessionId, childSessionId}` requires the exact direct parent;
  an ended but retained ancestor may still have live delegated descendants.

Return `{workKept: boolean}`. It means genuinely retained work, not pending
cancellation settlement. Do not return session IDs for retrospective bridge
cleanup. No terminal state is fabricated by this response.

Validate named authority before side effects. In one synchronous span, capture
its live delegated subtree, signal the named cancellable activity, cancel
continuable descendants within that authority, and cancel live subagent jobs
owned by those launchers. No await between capture and cancellation signals;
never kill bash, unrelated, parent, sibling, or unowned jobs. Reuse root cancellation
bookkeeping without waiting for prompt/Activation disposal. Continue independent
branches on a cancellation-hook failure, log useful original context and surface
an explicit failure with retained cause rather than false success.

Execution kind is read synchronously from
`ctx.get("sessionProjections").snapshot(child.agent.session).values.subagent`.
Require `session.header.origin === "subagent"` and descriptor
`identity.seq >= (session.header.seedLength ?? 0)`. Only own-suffix `continuable`
identity authorizes effective individual stop. STOP should clear already-accepted
inbox work through public `Agent.cancel` with `keepInbox: false` under validated
live authority; verify the pinned API rather than assuming the old manager helper
has those semantics. Existing keep/single-child interrupt behavior is unchanged.
Presentation `mode` and successful no-op manager `interrupt` are not evidence. An independently named
live child lacking this identity, or a one-shot without an exact authorized job
binding, is retained; do not widen to its parent. Parent cancellation can cover
foreground descendants through their existing tool signal. Owned background fork
jobs need explicit targeted job cancellation because their controllers are separate.
For an in-scope launcher, cancelling its complete subagent-job set covers its
background one-shots without a per-child binding; individual child targeting must
not use that broader operation against an out-of-scope parent. Pending settlement
of covered work is not retention. Prove the pinned foreground/background producer
cases rather than infer coverage from merely one matching-owner job.

Atomicity evidence is pinned source and a reachable I/O interleaving, not yet a
live reproduction: native child registration precedes queued ACP announcements;
continuable admission checks the launching tool signal immediately before submit;
foreground publication forwards parent abort synchronously; accepted background
forks are in the synchronous owned job registry. Tests must prove these claims
using pinned harness components and controlled admission/output barriers. If they
fail, stop rather than adding a speculative fence.

## Input cancellation: one ordered request channel

Move the cancellation race inside the existing native `#queueInteraction` task,
so its output tail does not remain blocked on an unanswered raw RPC after abort.
Keep the pre-send abort check. Only an interaction actually sent installs the
request-local abort callback; remove it when that interaction resolves/rejects.

That callback sends `deepseek/input/cancel` as a **server request**, not a
notification, with `{sessionId}` and an empty acknowledgement. Queue it immediately
through the existing SDK `extMethod` writer; observe/log failure, but do not wait
for its acknowledgement to accept stop or release the aborted interaction tail.
No pending-input map or cancellation ledger is introduced in the adapter.

The existing SDK write queue and per-record interaction tail establish:
old input request -> input-cancel control request -> next input request.
A queued interaction that has not sent checks its aborted signal and sends nothing.
The next interaction cannot start before the previous queued task settles. The
control request is already queued before that settlement releases the tail.
Question IDs may be reused; correctness does not depend on their uniqueness.

In the bridge, all three messages use `AcpStdioClient.serverRequests`, not the
separate notification stream or direct response-completer path. Existing explicit
session attribution and prompt-write buffering preserve their order together.
`DeepSeekApprovalRegistry` parses the control request through the backend-local
API/DTO boundary, synchronously cancels that session's pending inputs at that
ordered point, and acknowledges with a typed empty response. No queue generation
or prompt state is changed by this input-only control. Requests admitted afterward
survive. Do not add a merged-stream dispatcher or infer ordering across controllers.

## Bridge stop flow and queue ownership

Shared policy remains in `AcpPlugin`; only DeepSeek opts in. Before any await,
prepare the named session and currently known running descendants with the existing
queue/write cancellation bookkeeping. This is a request-time operation: discard
only the work currently present, using the existing generation checks. Do not
repeat preparation after the RPC. Later prompts use the new generation normally.

Then dispatch exactly one tree-stop request, with no preceding standard cancel
frame. The call must enqueue its native request before yielding to later turn
admission. Native authority, not the bridge snapshot, determines physical targets.
No response-time generation bump, queue sweep, or session-wide approval cleanup is
allowed. State absent at dispatch is never retrospectively claimed by this stop.
Late input cleanup belongs solely to the ordered native input-cancel request above.

Use a backend-neutral immutable session/child target and protected mechanism hook
under shared policy. `DeepSeekAcpApi -> DeepSeekSessionRepository ->
DeepSeekSessionService -> DeepSeekPlugin` owns native DTO/result translation.
Tracker-visible `confirm` rejection and every unsupported `keep` remain
side-effect free. An accepted `confirm` with no visible children uses native atomic
authority to cover admissions ahead of delayed lifecycle frames; `keep` retains its
existing transport. A queued, undispatched prompt is cleared before dispatch and
does not replace an ended child's retained exact-parent authority. A terminal
child with its own accepted bridge prompt is independently resident: an ancestor
stop excludes that child branch from request-time cleanup and reports it as
retained. The bridge passes every persisted descendant backend id into the plugin,
including nested descendants and ids absent after tracker reset. The atomic result
returns exact handled and unhandled ids for public-id mapping: current clients
fanout directly to known independent work, while full native coverage suppresses
second stops for children whose lifecycle announcement lands during STOP.
Whole-plugin stop uses the same tree path and existing authoritative-idle budget.
Replace only the opted-in stop snapshot fanout/coverage reconstruction. Keep
snapshots required by confirm/keep; no compatibility shims for internal callers.

## Protocol, release and complexity budget

Keep extension v2 and all existing native/bridge v1/v2 corpus bytes unchanged.
Add separate `protocol/scoped-stop/v1/` schema/fixtures for the new endpoint and
server request, then freeze matching consumer evidence with source manifests.
Publish adapter 0.1.4, confirmed absent before release prep; keep the harness pin.
Publish and verify native artifacts before raising the bridge minimum/target and
all six hashes. No temporary old-runtime fallback. Existing-consumer release
conformance proves only retained v2 behavior, never the new endpoint. Check the
new server request against that release gate rather than assuming compatibility.

New persistent state: zero. New long-lived coordination state: zero. Reuse native
sessions/children/jobs/projections, bridge turn state and approval registry. Target
lists and failures are request-local; the input abort callback is interaction-local
and removed on settlement. No stop maps, epochs, timers, registries or admission
cutoffs. The native step landed at 840 changed lines after review fixes. The bridge
estimate was 250–600 lines; the initially reviewed consumer landed at 1,369 under
the ~1,500 soft cap. Mandatory PR findings then required a generated Freezed union
and an additive compatibility response through bridge and client to prevent a
second descendant fanout. After that review round the PR was 2,160 lines: 588
generated, 834 tests/fixtures, 380 docs/plans, and 358 production. Current-head
review then required native authority for accepted `confirm` and resident-versus-
queued prompt targeting; after that review round the PR was 2,259 lines: 588
generated, 885 tests/fixtures, 422 docs/plans, and 364 production. The next
current-head review required partial-handling ids so independently resumed children
remain exact fanout targets without re-stopping covered delegated work. After that
review round at head `775aa393a217c8dbadf6e612216555320ca620fc` the PR
was 2,584 lines: 611 generated, 1,063 tests/fixtures, 456 docs/plans, and 454
production. With merge base `b43758e1b304d7f119787163875b78b38b1b25f1`,
`git diff --numstat b43758e1b304d7f119787163875b78b38b1b25f1...775aa393a217c8dbadf6e612216555320ca620fc`
reproduces this self-inclusive committed measurement. Its 325-line increase is 23
generated, 178 tests/fixtures, 34 docs/plans, and 90 production lines. The
following review required conservative coverage after tracker reset, client-less
retained-work accuracy, post-stop lookup avoidance, and OpenCode handled ids. The
pinned implementation head `2dd4fb076e16378b3fccdb2bda3ffd2b906f24f9`,
against merge base `b43758e1b304d7f119787163875b78b38b1b25f1`, measures
+2,468/-239 = 2,707 lines: 611 generated, 1,136 tests/fixtures, 494 docs/plans,
and 466 production. `git diff --numstat b43758e1b304d7f119787163875b78b38b1b25f1...2dd4fb076e16378b3fccdb2bda3ffd2b906f24f9`
reproduces it. The range includes prior tracker/design measurement records in its
docs/plan subtotal and excludes subsequent non-implementation evidence/wrapping
commits beginning with `52761ce4de`, which records the 2,707 figure here and in the
tracker. Its 123-line increase is 73
tests/fixtures, 38 docs/plans, and 12 production lines. The next review required a
bridge catalog snapshot plus exact unhandled ids to preserve both delayed native
coverage and nested independent fanout; it also proved OpenCode's handled-id claim
was not authoritative and restored legacy fanout. The pinned implementation head
`afd3695acdedc99a6d1790c5377bcb8c2be0f123`, against the same merge base,
measures +2,990/-273 = 3,263 lines: 629 generated, 1,507 tests/fixtures, 535
docs/plans, and 592 production. `git diff --numstat b43758e1b304d7f119787163875b78b38b1b25f1...afd3695acdedc99a6d1790c5377bcb8c2be0f123`
reproduces it. This range includes all earlier measurement records in its docs/plan
subtotal and excludes subsequent non-implementation evidence/wrapping commits
beginning with `d298a41507`, which records the 3,263 figure.
Its 556-line increase is 18 generated, 371 tests/fixtures, 41 docs/plans, and 126
production lines. Splitting the response or partial-handling mapping from atomic STOP
would leave the first PR vulnerable to re-stopping later work or missing independent
work, while splitting the generated parser or admission-race fixes from their
consumer would retain a duplicate schema or known escape path. The overrun is
therefore accepted as one coherent, independently safe contract; every reviewed
measurement remains recorded rather than rewritten.

## Verification and review record

Architecture review supported native authority, layering, atomic admission proof,
job filtering, and additive/native-first delivery. It rejected two unspecified
boundaries: response cleanup ownership and execution-kind authority. The concrete
choices above address those findings. Native implementation review approved adapter
#17 with no findings. Consumer architecture reviews approved the atomic policy,
layering, additive response path, retained authority, and generated transport union.
The conservative-coverage incremental review approved with no findings. The final
catalog-snapshot and exact-unhandled-response incremental review also approved with
no findings.

Native tests: delayed root/nested announcements; pending continuable admission;
foreground handoff; pending/published background fork jobs; exact named scope;
missing/inherited versus own descriptor identity; later user work; partial failure;
idle/ended targets; cancellation of a pending permission/question without output
deadlock. Do not substitute bridge notification fakes for authoritative tests.

Bridge tests: no-known-child still invokes tree stop; no separate standard cancel;
known old queued turns dropped before dispatch and later queued turns preserved;
old input -> control -> new input in one chunk, including reused question IDs,
notification backlog and prompt-write buffering; response delivered before request
stream drainage; visible-child confirm rejection and hidden-child accepted confirm;
queued prompt versus resident child authority; independently resumed child plus a
covered delegated sibling and partial client fanout; cleared process-local ancestry;
client-less retained work; fully handled bridge lookup avoidance; nested exact
unhandled fanout; lifecycle announcement during STOP; OpenCode legacy fanout when
child-stop outcomes are not authoritative; keep behavior; foreground retention; RPC
failure; busy state after acceptance; whole-plugin stop. Verify new minimum/digests
and frozen corpora. Run owning analyzers/tests; CI owns the full matrix.

Authoritative native and consumer package coverage passes, so the temporary
late-launch limitation is removed from capability/regression docs. Final
phone/desktop E2E remains a separate gate. No storage cleanup or migration is
needed. Do not expand into backend catalog scans, cold ancestry repair, unrelated
job teardown, or general transport refactoring.
