# Stage S01: Additive Contracts

## 0. Stage Metadata

- **Stage ID:** S01
- **Status:** Pending
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `main`
- **PR count:** 1
- **Manual checkpoints:** 0

## 1. Outcome

Shared bridge/client contracts can represent connection-scoped project presence
and a non-null PR history while preserving old/new peer interoperability. No
bridge scheduling, client sending, persistence, or UI behavior activates in this
stage.

## 2. Entry Criteria and Baseline

- The approved plan has been delivered.
- The worker has fetched `main`, assessed drift from
  `e766684e0fdc22256419b7b99691021c9f14732d`, and committed the exact assessed
  tip as the S01/W01 baseline in `TRACKER.md` before creating the branch.
- Shared, bridge, and client workspaces resolve from that pinned baseline.
- The version declared by bridge/mobile has been re-read for compatibility
  markers; it was `1.5.0` at plan audit.

## 3. Invariants and Non-Goals

- Changes are additive on the shared wire/model contract.
- `Session.pullRequest` remains unchanged.
- Missing history maps honestly to a non-null empty list at shared decode.
- An unknown project-view message remains connection-safe for old bridges.
- Generated Freezed/JSON files are regenerated, never hand-edited.
- No bridge component routes `RelayProjectView` yet.
- No client sends `RelayProjectView` yet.
- No schema, GitHub, branch-watcher, timer, or UI work is included.

## 4. Execution Waves

| Wave | ID | PR | Repository | Base | Can run in parallel | Merge barrier |
|---|---|---|---|---|---|---|
| W01 | S01-W01-P01 | Add additive PR-monitor contracts | `sesori-ai/sesori_apps_monorepo` | `main` | N/A | Must merge before S02 begins |

## 5. Integration and Manual Verification

- Round-trip both relay variants and sessions with empty/non-empty history.
- Decode old session JSON that omits history and assert an empty non-null list.
- Prove bridge and client exhaustive handling/compilation remains valid.
- Run all shared tests plus downstream bridge/mobile/desktop analysis and tests
  listed in the PR step.
- No separate manual checkpoint is justified; contract behavior is fully
  deterministic and automated.

## 6. Exit Criteria

- S01-W01-P01 is merged to `main`.
- Shared generated outputs match source annotations.
- Old/new contract tests and downstream consumer verification pass.
- `TRACKER.md` records the PR URL and checked state on the implementation branch;
  plan execution advances to S02/W01 only after merge reaches `main`.

## 7. Stage-Specific Detail

The new client sender intentionally waits until S03. This creates a release-safe
decode-before-send window: any bridge released after S01 can parse the control
message, while clients released before S03 continue using request-driven PR
refresh unchanged.
