# Step 38 — Desktop sign-in plan

Branch `desktop-sign-in/plan`. The PR landed after the series retired
(step 49), so this step finished outside the series.

## Decision

On 2026-09-25 the user reviewed the local sign-in page (current state,
directions A, B and C, and 12 scoping questions) and chose direction A, a
provider-first split window that includes Apple, with a waiting card that
offers Cancel, Open again and Copy link. They approved the responsive rule
that folds it into direction C's single column below about 820 pt. The other
scoping questions take the page's recommended defaults, which the user may
override.

## Outcome

The PR raised `.plan/active/desktop-sign-in/` (eight steps, client only). The
rebuild, its regression-doc updates and its L3 matrix run under that plan;
this series records no further work for review D12.
