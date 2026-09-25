# Step 42 — A real busy indicator

Branch `visual-hierarchy/busy-indicator`. Client only.

## What changed

- Every live row of the transcript leads with the turning outline sparkle
  (`PregoAiLoader`): a running tool, a running sub-agent and streaming thinking,
  which already had it. The tool and sub-agent icons return once the step
  finishes.
- The live label's shimmer is now visible in both themes. `PregoShimmer` gained
  an optional `baseColor`: a live label is drawn in the tertiary text colour and
  a primary-text band sweeps across it. The old white band over light text was
  invisible in dark mode and faint in light mode.
- While the session works, no step is live and no assistant text streams, a
  "Working…" live row with the same sparkle closes the transcript: before the
  first token and between steps. Streaming text already shows progress, so the
  row hides while the streaming buffer holds text. A starting step takes its
  place; the working row eases its height and fades
  out rather than jumping, and eases back when the step ends. A retry row
  replaces it, and a pending question or permission hides it because the
  session waits on the user. The busy test is the existing `hasActiveWork`;
  the message list gets it as a plain `isBusy` input and freezes it with the
  rest of its snapshot while the reader is scrolled away.
- The desktop title leads with the turning sparkle again while the session runs
  (as step 7 had it), in the status slot the awaiting glyph uses. The title
  shimmer is dropped rather than recoloured: the title is primary text, so a
  primary band cannot show on it, and the sparkle plus the transcript's live row
  already say the session works. `DesktopPageToolbar` lost its `isRunning`
  input.
- Reduced motion keeps the sparkles and labels still, with no size animation.
- The phone keeps its top-bar activity indicator.

## Deviations from the plan

- The plan left "visible in dark mode or dropped" open for the title shimmer;
  it is dropped.
- A session waiting on a question or permission shows no "Working…" row; the
  plan named only `hasActiveWork`.

## Verification

- `module_app_ui`: `test/features/session_detail` and `test/widgets`, all
  passed, including the new test: the working row shows while busy with no live
  step, a live step replaces it with the sparkle leading its label, it returns
  when the step finishes, it hides while text streams, and it leaves when idle
  or when a retry row shows.
- `module_prego` `test/components`: passed.
- `desktop` full suite: passed. `app` `test/features/session_detail`: passed.
- `dart analyze --fatal-infos` is clean in module_prego, module_app_ui, app and
  desktop.
- Fixture-only before and after renders, desktop and phone, dark and light, and
  a motion GIF of the desktop title and live rows are in the PR.
