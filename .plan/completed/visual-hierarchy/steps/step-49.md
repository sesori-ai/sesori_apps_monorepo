# Step 49 — Retire the plan

Branch `visual-hierarchy/retire`. Documentation only. No code, wire,
database, string or user-visible change.

## Scope

- Records the final state of every step and the final matrix. A cell that was
  not executed is recorded as unexecuted, never as passed.
- Retires the plan to `.plan/completed/visual-hierarchy/` and points
  `docs/ROADMAP.md` at the new path.
- Checkpoint: `main` at `e86091abaef468a93f1dd12c782ada553d416c36`, after
  step 48 (#1735) merged.

## Step Outcomes

- **Done:** steps 1–36, 40–48 and 50, each with its evidence in
  `steps/step-NN.md` (step 1 is the plan itself).
- **Dropped:** step 39, the header backdrop. The user dropped it on
  2026-09-25 after comparing three backdrop strengths with today's headers;
  see [step 39](step-39.md). `glass-presentation.md` needs no backdrop entry.
- **Carried out of the plan, not done:** steps 37 and 38. Prototypes and
  mocks were shown to the user on 2026-09-25. Neither direction has been
  chosen yet; each becomes its own plan once the user picks one. No
  production code was written for either.
  - **Step 37, turn navigation.** Recommended direction: a pinned prompt
    header with a prompts sheet on the phone, and an outline pane on the
    desktop.
  - **Step 38, desktop sign-in.** Recommended direction A: a provider-first
    split window that includes Apple, and a waiting card with Cancel, Open
    again and Copy link.

## Final Matrix

| Cell | Result |
|---|---|
| Client and bridge packages, automated | Passed per step; every step's PR passed CI on its final head |
| Plugins, step 32 tool kinds, automated | Passed in step 32 |
| macOS desktop, L3 end to end | Unexecuted as one pass |
| iOS, L3 end to end | Unexecuted as one pass |
| Android, device smoke | Unexecuted |
| Windows and Linux, visual smoke | Unexecuted; only the CI builds ran |
| Plugins, step 32 live turns | Unexecuted as one pass |

This step ran no suites; the automated cells rest on each step's own
evidence and CI.

## Unexecuted Cells

- **macOS desktop and iOS, L3.** No single end-to-end pass against a live
  bridge was run over the merged series. Individual steps were reviewed live
  or through screenshots of the running app during their own rounds; the
  rest is covered by widget, cubit and bridge tests.
- **Android device smoke.** Not run. The `app` suite renders the shared
  screens, sheets and popovers.
- **Windows and Linux visual smoke.** Only the CI builds ran. Windows drive
  listing is proven by automated tests with a fake filesystem.
- **Step 32 live plugin turns.** Not run as one pass across Claude Code,
  OpenCode, Codex, Pi and an ACP harness; the mappers are covered by each
  plugin's automated tests.

## Acceptance

The user directed the retirement of this plan on 2026-09-25 with the cells
above unexecuted, so the plan retires. The acceptance permits retirement; it
does not claim that those cells passed.

## Regression Documents

None changed. Step 48 reconciled them with the merged series.

## Verification

Docs and plan only; no Dart suites run.
