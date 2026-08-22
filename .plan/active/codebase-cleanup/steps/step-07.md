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

Size, excluding this evidence file so the figure is an independent budget
measurement, via
`git diff --numstat "$(git merge-base HEAD origin/main)"...HEAD -- bridge/app`
against merge-base `2ae02d2e6`: **`+1,192 / -876` = 2,068 changed lines** in
`bridge/app`, above the 1,500 soft cap and the step's 500–900 target.

The overage is inherent to a move: 161 files are renamed and 309 referenced
them, and git counts a moved line as both an addition and a deletion, so
identical content is counted twice. 865 of the changed lines are rewritten
import directives across 248 files; the rest are regenerated Freezed/JSON parts
following their sources. No logic line changed, and splitting the move would
leave the tree half-flattened and non-compiling between PRs.

Documentation in the same PR (`bridge/ARCHITECTURE.md`, `bridge/app/AGENTS.md`,
`bridge/README.md`, the skill reference) accounts for the remainder of the
merge-base diff. Figures are measured at commit `334361312`; later review
commits shift them slightly, which is why the budget figure deliberately
excludes this record.
