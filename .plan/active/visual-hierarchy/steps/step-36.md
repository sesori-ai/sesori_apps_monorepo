# Step 36 — Compaction row

## What changed

- The compaction part gains a nullable `summary` on the plugin contract and
  the `sesori_shared` wire model. A null summary means the harness keeps it
  private. The bridge no longer filters compaction parts out.
- Plugins map a finished compaction to that part. Each harness's own shapes
  stay inside its plugin:
  - Claude: live, the synthetic user frame that follows `compact_boundary`
    (verified on CLI 2.1.281); in history, the `isCompactSummary` record.
    Both use the same message id. Before this change, live showed the
    summary as a long user message and history hid it.
  - OpenCode: the text parts of a `summary: true` assistant message, both
    in history and live. The SSE mapper keeps a bounded set of summary
    message ids.
  - Pi: `compaction_end.result.summary` live and the compaction entry's
    summary in history.
  - Codex: the rollout `compacted` line. Its message is usually empty,
    because remote compaction stores the summary encrypted, so the summary
    is usually null.
- Pi and Codex keep the running `compact` tool card. The finished
  compaction part reuses that part id, so it replaces the card in place.
- The client `TranscriptBuilder` stops hiding compaction, so it ends a step
  group the way visible text does. `AssistantMessageCard` dispatches it to a
  new `CompactionPartWidget`: one quiet "Context compacted" row in the step
  style. When a summary exists, tapping the row opens it as Markdown in a
  reading-width `showPregoModal`; without one the row is inert.

## Deviations

- The plan assumed Pi already emitted the compaction part. No plugin
  emitted it, so every harness that marks compaction needed its own mapping.
- DeepSeek reports compaction only as a live status, with no message
  identity and no history record. It stays unmapped, because a live-only row
  would vanish on reload. Whether the ACP harnesses mark compaction was not
  probed. Both gaps are recorded in `docs/HARNESS_CAPABILITIES.md`.
- An older app decodes the part, ignores the summary, and renders nothing.
  Pi and Codex compactions therefore lose their finished `compact` tool card
  there. This is accepted as a minor, informational degradation.

## Verification

- Plugin tests pass: Claude (349), OpenCode (448), Pi, and Codex (472).
  They cover the mapping per harness, live and in history.
- `sesori_shared` tests pass (419). They include the legacy payload without
  a summary and a round trip with one.
- The bridge app event-mapper and history-capture tests pass. The event
  mapper now passes compaction parts through with their summary.
- `module_app_ui` `assistant_message_card_test.dart` passes (13). New cases
  cover the row opening the summary modal and the inert row without a
  summary. `module_core` session_detail tests pass (264).
- `dart analyze --fatal-infos` is clean in every touched package.
- Architecture review pass 1 found two issues: OpenCode summary tracking
  lived in the plugin impl, and Claude read `raw["isSynthetic"]`. Both are
  fixed.
- Fixture-only screenshots of the row and the modal, on phone and desktop
  in light and dark, are on `pr-media` under `visual-hierarchy/compaction-row/`.
- `docs/regression/tools-and-file-changes.md` records the row, its failure
  signals, and the older-client limitation.
