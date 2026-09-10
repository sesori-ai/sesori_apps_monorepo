# Codex actual-plugin QA

## Tile and replay — 2026-09-08

- Production head: `1dd2cd34a84843df6b29a5478a7f2e5eeba3e5a0`.
- Managed runtime: Codex 0.153.4; real `CodexPlugin.composed` and production WebSocket client.
- Existing auth/model unchanged; newly owned scratch sessions only. No relay, phone, or desktop QA claimed.
- Passed: forked and nonforked native children; exact call-ID tile/link/prompt correlation;
  generic-to-subtask replacement with stable part ID; no copied-parent or encrypted-envelope prompt.
- Passed: native parent completion while children remain busy, delayed root idle,
  initial completed tiles, and identical IDs, links, prompts, and status after fresh disconnected cold replay.
- Passed: terminating only the owned native process emitted a cancelled tile and root idle.
- Unexecuted live: duplicate display names, plaintext input variant, differently-terminal resumed child.
  Synthetic coverage is not represented as live evidence.
- Native direct-child resume failed before creating a turn:
  `turn/start: direct app-server input is not allowed for multi-agent v2 sub-agents`.
  This does not establish a limitation on parent-mediated native messaging.
- Owned runtime resources stopped; existing processes and config were untouched. Scratch sessions remain private.
- Private structural evidence: `/tmp/codex-step6-plugin-qa-1788905216125/summary.json`.
  Raw captures remain private. An initial invalid hyphenated task-name attempt was corrected to underscores;
  its rejection is not counted as a production pass.

## Scoped-stop policy — 2026-09-10

- Baseline: scoped-stop PR #1421 squash-merged as `77165f784ff36438c32c997b793a7f22ffac89d1`.
- Managed Codex 0.153.4 ran through real `CodexPlugin.composed`, production WebSocket transport,
  unchanged auth/model, and newly owned bounded `/tmp` trees. Every stop used `plugin.abortSession`.
- Passed executed policy scope: side-effect-free root confirmation reported three descendants and a running root;
  named-child confirmation reported its one grandchild. Both declared main-agent-only support and changed no status,
  terminal, or empty pending-input snapshot.
- Passed root `keep`: only the root gained authoritative `turn_aborted`; all three descendants stayed busy.
  Follow-up confirmation reported the root idle with three running descendants.
- Passed named-child full stop: the named child and its grandchild gained authoritative `turn_aborted` and settled
  non-busy; ancestor and sibling stayed busy. Passed root full stop: root, both children, and grandchild did the same.
- Every accepted atomic-opt-in response reported `subAgentsHandled: false`. Codex stop is immutable-snapshot,
  exact-thread fanout, not native atomic subtree cancellation. Existing client fallback therefore remains active and
  aborts observed busy child sessions; a descendant spawned after the snapshot can escape that request.
- Overall result: **Pass** for executed actual-plugin policy scope; **Partial** for the live policy matrix.
  No pending question or permission surfaced, so live confirm preservation and cancellation of pending input remain
  unexecuted. Focused Step 8 automation covers them but is not counted as live-plugin evidence.
- Runtime survived every case. Natural sleep expiry, disconnect, process death, and teardown were not accepted as stop
  proof. Final owned cleanup found no outstanding active work, owned process, or open file.
- No relay, phone, desktop, client-dialog, notification-delivery, auth/model-variant, or failure-settlement QA is
  claimed. Raw prompts, transcripts, credentials, identifiers, and runtime payloads remain private.
- Privacy-safe structural evidence: `/tmp/codex-step9-policy-qa-1789060924499/summary.json`.
