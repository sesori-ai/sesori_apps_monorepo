# Step 7/45 — Flatten the duplicated bridge layer tree

**PR:** _pending_

## Re-verification against `main`

No file-level collisions between the two trees; the only directory overlap,
`repositories/models`, has disjoint filenames. 161 files moved, 309 files
referenced them.

One plan deviation, and a review correction to it. The plan said to assign the
mixed `runtime/` directory a layer, so this step first moved
`plugin_runtime.dart` into `api/` as the below-repository seam repositories call
through. Review showed that was wrong: the file imports
`runtime/plugin_generation_factory.dart`, so Layer 1 would depend upward on
composition, and `PluginRuntime` owns generations, leases, lifecycle
transitions and start/stop decisions — lifecycle machinery, not a data source.
It stays in `runtime/`, and the architecture document now describes `runtime/`
honestly as the subsystem owning both process lifecycle and plugin generation
lifecycle, with `PluginRuntime` as its seam. That trades a documentation
ambiguity for no layering violation, which is the right way round.

`control/` was deliberately not touched: `docs/desktop/PLAN.md` records
`ControlChannelServer`, `ControlMessageDispatcher` and the trackers as shipped
Phase-2 deliverables of the paused desktop workstream.

## Verification

`bridge/app`: `dart analyze --fatal-infos` clean, `dart test` 2,684 passed.
Codegen regenerated; `dart fix --code=directives_ordering` applied. Renames plus
their imports only — no logic change.

Size, measured with
`git diff --numstat "$(git merge-base HEAD origin/main)"...HEAD` against
merge-base `2ae02d2e6`: `+1,413 / -1,066` = 2,479 changed lines, above the
1,500 soft cap and the step's 500–900 target. The overage is inherent to the
change: 161 files are renamed and 309 files referenced them, and git counts a
moved line as both an addition and a deletion, so the same content is counted
twice. 865 of the changed lines are rewritten import directives across 248
files; the rest are the regenerated Freezed/JSON parts that follow their
sources and the two rewritten architecture documents. No logic line changed, and
splitting the move would leave the tree half-flattened and non-compiling between
PRs.
