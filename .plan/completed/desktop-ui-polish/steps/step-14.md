# Step 14 — Stop presenting harness modes as agents

## Scope

- **Client (D15).** `AgentModelButtons` shows the agent entry only when more
  than one agent is offered. It is shared, so phone and desktop follow the
  same rule.
- **Plugins.** Claude and Codex advertise only "Agent". Cursor, Copilot and
  OMP advertise only the default mode their CLI reports, or the first mode
  when no default is known. The reordering code that sorted the default first
  is gone, because only one entry is listed.
- **Inbound path unchanged.** A released mode name that still arrives, such as
  Plan or Ask, is honoured. Those branches carry a
  `COMPATIBILITY 2026-09-21 (v1.9.0)` marker: Claude's `plan` selection and its
  plan-exit agent reset, Codex's `"plan"` mapping, and the mode resolution of
  Cursor, Copilot and OMP. The retiring condition is that no catalog captured
  before this date can still be served.
- OpenCode is untouched. No wire shape, database or analytics change.

## Deviations From The Plan

- None in behaviour. The plan's live Claude Code turn was **not executed**; it
  stays an unexecuted cell for the final matrix. A plugin test covers the same
  path against the fake process: a session sent "Plan" and then "Agent" sets
  the permission mode to `plan` and then `default`.

## Automated Evidence

Measured checkpoint: commit `584f613d448b7f26c8a3888630ed577fe4588323` with a
clean working tree, Flutter 3.47.5 (Dart 3.13) from `.tool-versions`. Every
command below exited 0. The suites ran on the step's tree before its final
rebase, which brought in only step 13's review fixes. No log files were kept;
CI on the PR is the durable record. This file and the tracker row were added
afterwards as documentation only and were not re-measured.

```sh
for plugin in claude codex cursor copilot omp; do
  (cd bridge/sesori_plugin_$plugin && dart test && dart analyze --fatal-infos)
done
cd client/module_app_ui && flutter test --no-pub && dart analyze --fatal-infos
cd ../app && flutter test --no-pub && dart analyze --fatal-infos
cd ../desktop && flutter test --no-pub
```

- Plugins: Claude 322, Codex 461, Cursor 174, Copilot 18 and OMP 64 cases
  pass. Catalog expectations now list the single default entry. Existing cases
  that send "Plan" or "Ask" still pass unchanged, which proves the inbound
  path. OMP gains a case where the default mode is listed second and is still
  the one advertised.
- `app`: 776 cases pass. A new case proves the agent entry is absent with zero
  or one agent and present with two. Two new-session fixtures gained a second
  agent because their cases look for the agent entry.
- `module_app_ui`: 394 cases pass. `desktop`: 276 cases pass.
- `architecture-implementation-review` was not run: the step adds no class,
  moves no ownership and changes no contract shape.

## Size

**239 changed lines (157 additions and 82 deletions) across 23 files** at the
measured checkpoint. Of those lines, 83 are tests, 21 are documents and the
remaining 135 are production source. Reproduce from the root:

```sh
git diff --numstat ce0257f2e45730edf7289343b806cd0bfbd629e9 584f613d448b7f26c8a3888630ed577fe4588323
```

The step target was 600; the repository soft cap is 1,500. This file and the
tracker row come on top.

## Regression Documents

`docs/HARNESS_CAPABILITIES.md` gains "Agent selection and harness modes".
`session-creation-and-options.md` records the agent entry rule and the
honoured mode names.
