# Step 6a — Stream OpenCode v2 Compaction Into The Live Row

Branch `compaction-progress/opencode`. This covers the bridge OpenCode v2
adapter, which serves the managed runtime and any 2.x on `PATH`. There is no
client, wire or database change, because step 4's row already renders each
state. Step 6 was split into 6a and 6b (the v1 adapter) because the two
adapters share no compaction code and together exceed the step's line target.
This PR also adds the phase-2 detail to the plan, section 5.

## Scope Delivered

- `V2MessageMapper` maps each native compaction status onto one system
  message with one compaction part, `partId(messageId, 0)`, so the row keeps
  its id as it settles:
  - **running:** `running(summary)`, with an empty summary read as none.
    `time.completed` is null.
  - **completed:** `completed(summary, freedTokens: null, trigger)`, where
    `reason` maps `auto`→auto, `manual`→manual and unknown→none.
  - **failed:** `failed(error.message)`. This replaces the old error message.
    `time.completed` is the creation time, so a named compaction still
    settles its prompt.
- `V2EventMapper.mapMessageSnapshot` reports `SessionCompacted` only for a
  completed part. `mapCompactionDelta` turns a native delta into a `text`
  part delta on the running part, or into nothing.
- The new `OpenCodeV2CompactionTracker` keeps each session's running part.
  `OpenCodeV2Service` records every compaction snapshot it fetches, routes
  deltas through the tracker and clears it in `reset()`. A delta with no
  recorded running part (after a bridge reconnect mid-compaction) first
  loads the running snapshot, so the strip resumes.
  `OpenCodeV2Plugin.create` injects it.
- Docs:
  - `HARNESS_CAPABILITIES.md`: the OpenCode v2 compaction row now records the
    live row, the strip, the failure note and the trigger, and that no freed
    count is shown.
  - `tools-and-file-changes.md`: the OpenCode v2 live row, the
    resume-after-reload limit, the Q5 old-app line and coverage.
- Plan: phase-2 detail for steps 6a, 6b and 7, budget rows, and the
  plan-review record.

## Deviations And Accepted Limits

- **No freed count on v2.** The completed message's `tokens` is the usage of
  the summary call itself, not the context before and after compaction.
- **Strip after a reload or reconnect.** OpenCode stores no partial summary,
  so after a reload or bridge reconnect mid-compaction the strip resumes with
  the next words. When the running snapshot cannot load, the deltas are
  dropped and the row appears when the compaction settles. If the stream is
  down when the compaction ends, the row stays running until the next
  transcript read, like any live part stranded by that outage.
- **Older apps (Q5).** While the summary streams, an app at v1.9.0 or older
  buffers the words for a part it never shows. It shows neither "Working…"
  nor a row until the compaction ends and the turn continues. This is
  accepted, with no old-client code.

## Evidence

Dart 3.13.4 from Flutter 3.47.5-stable first on `PATH`.

- **`bridge/`:** `dart analyze --fatal-infos` found no issues.
- **`bridge/sesori_plugin_opencode`:** `dart analyze --fatal-infos` found no
  issues, and `dart test test/v2` passed all 136 tests. The tests cover:
  - every status mapping and the trigger table, with the stable part id;
  - `SessionCompacted` reported only for a completed part;
  - deltas reaching only the running row;
  - a service flow (start, delta, end, then a late delta that goes nowhere)
    that settles in place as completed with trigger auto;
  - a first delta after a reconnect loading and publishing the running row
    once.
- **Formatting:** `dart format` was applied only to the touched hunks.
- **PR media:** fixture widget renders of the running, completed and failed
  row, plus a GIF of the strip and timer, on `pr-media` under
  `compaction-progress/opencode/`.

## Reviews

- **`architecture-plan-review` of phase 2:** rejected, with two blocking
  findings for 6b and two non-blocking findings for 7. All were applied
  directly; see the plan's review record.
- **`architecture-implementation-review` of `origin/main...a759b1d107`:**
  approved, with no findings.

## Size

About 725 changed lines against `origin/main`: 304 lines of plan detail, about 85 of this file, 138 of
production code, 174 of tests and 22 of docs. Nothing is generated.
