# Codex actual-plugin QA — 2026-09-08

- Production head: `1dd2cd34a84843df6b29a5478a7f2e5eeba3e5a0`.
- Managed runtime: Codex 0.153.4; real `CodexPlugin.composed` and production WebSocket client.
- Existing auth/model unchanged; newly owned scratch sessions only. No relay/phone/desktop QA claimed.
- Passed: forked and nonforked native children; exact call-ID tile/link/prompt correlation;
  generic-to-subtask replacement with stable part ID; no copied-parent or encrypted-envelope prompt.
- Passed: native parent completion while children remain busy, delayed root idle,
  initial completed tiles, and identical IDs/links/prompts/status after fresh disconnected cold replay.
- Passed: terminating only the owned native process emitted cancelled tile and root idle.
- Unexecuted live: duplicate display names, plaintext input variant, differently-terminal resumed child.
  Corresponding synthetic coverage is not represented as live evidence.
- Native direct-child resume attempt failed before creating a turn:
  `turn/start: direct app-server input is not allowed for multi-agent v2 sub-agents`.
  This does not establish a limitation on parent-mediated native messaging.
- Owned runtime resources stopped; existing processes/config were untouched. Scratch sessions retained privately.
- Private structural evidence: `/tmp/codex-step6-plugin-qa-1788905216125/summary.json`.
  Raw captures remain private. An initial invalid hyphenated task-name attempt was corrected to underscores;
  its rejection is not counted as a production pass.
