# Step 11/13: Show a launching row in the session lists

PR #1891. The tracker row describes what this step built and how it was
verified.

## Deferred

These review findings were declined on #1891 because the damage was small next
to the change they needed. Step 13/14 picked them up; see `step-13.md`.

| Finding | Flow | Why deferred |
|---|---|---|
| Codex `PRRT_kwDORscidM6p7z1Q`: a resolved launch above a still-waiting older one settles only as part of a fully resolved tail | Two launches in one project at once, with the newer one resolving first | Only a one-time row shift for that rare pair; nothing is lost |
| Codex `PRRT_kwDORscidM6p7z1f` and cubic `p6XdO`/`p6Xde`: a launch failure alert replaces an open archive Undo alert | A background create fails inside the few-second Undo window | The archived session stays restorable from Archived; the fix is cross-source alert queueing |
| Codex `PRRT_kwDORscidM6p6jgb`: move launch-row reconciliation from `SessionListFilteredContent` into a cubit | Structural; its concrete Archived-toggle flow was fixed | Cubits may not depend on cubits, so `SessionListCubit` would take the launch service: about 20 construction sites and an architecture change |
