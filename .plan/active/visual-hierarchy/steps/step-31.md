# Step 31 — Live transcript (part 1 of 2: grouping)

## What changed

- A pure `TranscriptBuilder` in `module_core`, beside `session_detail_state.dart`,
  turns the loaded messages into blocks per message: runs of visible parts,
  and groups of consecutive tool, thinking and sub-agent steps. Visible text, a
  file, an agent or a retry part ends a group, as do user and error messages.
  Hidden parts (step markers, snapshots, patches, compaction, empty text) never
  split a group. Each step carries one status: running, finished or failed.
- A group's summary counts finished steps by kind in order of first appearance,
  plus failures: "Thought · 3 steps · 1 sub-agent · 1 failed". Tools are a plain
  step count until step 32 adds tool kinds.
- `TranscriptGroupWidget` renders a group as one summary row that eases its
  finished steps open, and each running step below it as its own row until it
  finishes and folds into the summary. The disclosure animation and the
  header-still scroll compensation moved out of the shell tool into the shared
  `TranscriptDisclosure`, used by both the group and the tool row.
- Finished rows say nothing: the tool "Done" label and the sub-agent status
  labels are gone. A failed tool or sub-agent keeps one signal, its red icon.
  A generic tool's output opens in the same panel as a shell command instead of
  inline with the blue "Show more", which is removed.
- Sub-agent child-session matching moved from `SubtaskPartWidget` into the
  builder, which resolves each sub-agent's child and status once.
- The message list builds the transcript in build, from the same snapshot it
  renders; nothing new enters the cubit. Phone and desktop share all of it.

## Deviations

- Split into two parts, as the plan allows. Part 2 adds the shimmering live
  label, the streaming thinking tail, the removal of the thought card box and
  the jump button showing an off-screen live row. Until then a running step
  shows the existing spinner row and thinking keeps its card inside the group.
- A group may span consecutive agent messages and renders in the first
  message's row, so steps split across messages still read as one run. An
  automation (system) message groups only within itself.
- The `module_app_ui` live-row scope is not in part 1. Its only planned reader,
  the title sparkle, was dropped on 2026-09-24, so part 2 keeps the on-screen
  flag as message-list widget state unless a reader appears.
- Cancelled and unknown tools count as finished, not failed.
- Part 1 is about 2,400 changed lines against a 1,200 estimate: about 750 are
  deletions (the old tool output block, Show more and status helpers), about
  650 are tests and about 90 generated localization. No clean smaller split
  exists without an interim transcript that has groups but keeps the old rows.

## Verification

- `module_core` `transcript_builder_test.dart` passes (19 tests): grouping,
  message boundaries, hidden parts, statuses, sub-agent resolution, the
  running/finished split and summary counts.
- `module_app_ui` passes (485 tests), including the new
  `transcript_group_widget_test.dart`: the summary expands and collapses with
  animation, reduced motion opens it at once, a running step is a live row that
  folds in, and a group of only running steps has no summary.
- `app` passes (796 tests) and desktop `test/features` passes (67 tests).
- `dart analyze --fatal-infos` is clean in module_core, module_app_ui, app and
  desktop.
- Architecture implementation review: approved with no findings on the first
  pass.
- `docs/regression/tools-and-file-changes.md` records the grouping, its failure
  signals, and the removed Done and Show more.
