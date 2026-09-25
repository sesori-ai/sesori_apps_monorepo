# Step 31 — Live transcript

Landed in two parts: part 1 (grouping, #1691) and part 2 (live row, thinking
tail and jump button).

## What changed

Part 1 — grouping:

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

Part 2 — live row:

- A running tool or sub-agent's label shimmers in place of the spinner, through
  `PregoShimmer`, which keeps it still under reduced motion and gives screen
  readers the plain label.
- Streaming thinking shows a shimmering "Thinking..." with one line of its
  latest words below it: the end of the text stays in view and the older start
  fades out. The three-line bottom-clipped preview is gone.
- A finished thought is one row, "Thought" and its first line, which opens the
  full text; the chevron and the second preview line are gone.
- `Transcript` carries `liveStep`, the newest running step. While the reader is
  scrolled away, the jump button names it and shimmers ("Running $ make check",
  "Thinking...", a sub-agent's description). The rows stay frozen, so the list
  runs the builder once more over the live inputs for the button. With nothing
  running it still says "Jump to latest".

## Deviations

- Split into two parts, as the plan allows.
- A group may span consecutive agent messages and renders in the first
  message's row, so steps split across messages still read as one run. An
  automation (system) message groups only within itself.
- No `module_app_ui` live-row scope and no on-screen tracking. The scope's only
  planned reader, the title sparkle, was dropped on 2026-09-24. The jump button
  already appears only while the reader is scrolled away from the newest edge,
  where the live row sits, so it names the live step whenever it shows.
- The thought card had already lost its border in an earlier step; part 2
  removes what was left of the card, the chevron and the second preview line.
- Cancelled and unknown tools count as finished, not failed.
- Part 1 was about 2,450 changed lines against a 1,200 estimate: about 750
  deletions, 650 tests and 90 generated localization. Part 2 is about 500.
- No architecture review for part 2: it adds only private widgets and a field on
  the existing `Transcript`, with no new scope or moved class.

## Verification

- `module_core` `transcript_builder_test.dart` passes (20 tests): grouping,
  message boundaries, hidden parts, statuses, sub-agent resolution, the
  running/finished split, summary counts and the live step.
- `module_app_ui` passes (489 tests). New in part 2: a running tool shimmers
  instead of spinning and stays still under reduced motion, a streaming thought
  shows its latest words on one line, a finished thought is one row, and the
  jump button names the running step while detached and returns to "Jump to
  latest" when it finishes.
- `app` passes (797 tests) and desktop `test/features` passes (67 tests).
- `dart analyze --fatal-infos` is clean in module_core, module_app_ui, app and
  desktop.
- Part 1 architecture implementation review: approved with no findings.
- `docs/regression/tools-and-file-changes.md` records the grouping, the live
  row, the thinking tail, the jump button and their failure signals.
