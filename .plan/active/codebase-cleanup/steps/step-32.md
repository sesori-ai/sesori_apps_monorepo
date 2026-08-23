# Step 32 — List cubits and relay plumbing

The list cubits and relay stack retained several exact implementation copies.
This step consolidates the shared seams while leaving typed state and reconnect
lifecycle differences explicit.

## Re-verification against `main`

- The session/project `_reconnectIfNeeded` methods remained equivalent,
  including their silent timeout handling.
- Four project loaded-state paths repeated order, unseen projection, and emit.
- Stale refresh, active refresh, route-listener, and retry wrappers remain
  intentionally local because they own typed cubit state or distinct request
  parameters.
- Session archive and delete are not equivalent optimistic removals: archive
  mutates a returned session before filtering, while delete removes an item and
  has different response and cleanup-rejection handling.
- Relay HTTP verbs still repeated the same connection, send, and auth mapping,
  but their public body, query, header, timeout, and sensitivity contracts differ.
- Relay request IDs had two exact per-owner implementations.
- Reconnect-delay cancellation was the one exact repeated ConnectionService
  cleanup. The planned stale-attempt, teardown, and backoff helpers would combine
  call sites with different close codes, state publication, or timing, so they
  were not introduced.
- Relay framing, view sends, and controller close mechanics remained duplicated.
- `ClockProvider` and `RelayClientFactory` still had unnecessary DI registrations
  despite constructor defaults supporting production and direct test overrides.

## What changed

- Added `ConnectionService.reconnectAndAwaitOutcome` and migrated both list
  cubits to it, making reconnect timeout failures locally observable.
- Added project-only `_emitOrdered` for the four equivalent loaded-state updates.
- Consolidated RelayHttpApiClient verbs behind one private request path while
  preserving every public signature and sensitivity flag.
- Added one request-ID generator instance per relay HTTP client and connection
  service, preserving independent counters.
- Consolidated reconnect-delay cancellation without moving reconnect gates or
  teardown/state timing.
- Reused shared `frame`/`unframe` in RelayClient while retaining plaintext size
  checks, encryptor/channel race checks, and exact handshake replay frames.
- Consolidated best-effort view sends and controller close mechanics while
  preserving SSE detachment and diagnostic contexts.
- Corrected the stale bridge-offline handshake documentation.
- Removed DI registrations for the two constructor-default test seams and
  regenerated Injectable output.

Change-budget totals exclude this evidence file and use the merge base with
`origin/main`:

```bash
BASE=$(git merge-base HEAD origin/main)
git diff --numstat "$BASE"...HEAD -- client/module_core/lib
git diff --numstat "$BASE"...HEAD -- client/module_core/test
```

| Scope | Additions | Deletions |
| --- | ---: | ---: |
| Production/lib, including generated DI output | 221 | 319 |
| Tests | 131 | 20 |

## Behavior

No user-visible or database behavior changes. HTTP request shapes, auth error
mapping, sensitive-response redaction, request-ID format, reconnect outcomes,
encrypted wire bytes, handshake replay, list ordering, and optimistic list
actions retain their prior semantics. No wire or persisted contract changed.

## Verification

```bash
cd client/module_core && dart run build_runner build --delete-conflicting-outputs
cd client/module_core && dart analyze --fatal-infos
cd client/module_core && dart test test/cubits/session_list test/cubits/project_list test/capabilities test/api/client/relay_http_client_test.dart  # 245 passing
cd shared/sesori_shared && dart test test/protocol/framing_test.dart                 # 5 passing
cd shared/sesori_shared && dart analyze --fatal-infos                               # clean
cd client/app && flutter test test/capabilities test/core/api                       # 77 passing
cd client/app && flutter test test/features/session_list                            # 87 passing
cd client/app && flutter test test/features/project_list                            # 89 passing (post-CI fix)
cd client/app && flutter analyze --fatal-infos                                      # clean
cd client/module_desktop_core && dart analyze --fatal-infos                         # clean
cd client/desktop && flutter analyze --fatal-infos                                  # clean
git diff --check                                                                    # clean
```

The pinned formatter formatted compatible files and hit its known Dart 3.13
enhanced-enum crash in `relay_client.dart`; all analyzers remain clean.

Mobile CI initially failed on `client/app`
`project_list_nav_bar_test.dart` ("pulling the disconnected page down
re-attempts the bridge connection"): that app-level test still stubbed and
verified the removed direct `reconnect()` call. It now stubs and verifies
`reconnectAndAwaitOutcome(timeout: 15s)`.

Architecture implementation review approved the new service contract, request
ID ownership, DI construction, shared framing boundary, and cubit integration
with no findings. A separate correctness review found no plausible regressions.
