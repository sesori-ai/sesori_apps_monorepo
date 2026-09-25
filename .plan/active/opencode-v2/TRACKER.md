# OpenCode v2 Tracker

## Series

- Slug: `opencode-v2`
- Base: `main` at `fed841c2f9`
- Current step: 2/10 — detection/refusal in review ([#1711](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1711))
- Step 1 merged: [#1709](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1709)
- One-step-ahead checkpoint: Step 3 generated at `ed8d25e97e` on `opencode-v2-step-3`; no PR until Step 2 merges.
- Takeover: continue from `aqua-hummingbird`; preserve the existing published Step 2/3 history.
- Architecture review: first pass rejected 9 layering points; all applied (see PLAN.md Status)

## Steps

| Step | Complexity | Changed-line ceiling |
|---|---|---:|
| 1. Raise plan | 🌱 | 400 |
| 2. Detect v2 and refuse it honestly | 🌿 | 800 (557 authored + 170 generated at review) |
| 3. Generate v2 models | ⚙️ | 1,500 authored + generated |
| 4. v2 API and event stream | ⚙️ | 1,200 |
| 5. v2 read mapping and repository | 🚧 | 1,400 |
| 6. v2 live events, activity and service | 🚧 | 1,400 |
| 7. v2 writes and activation | 🚧 | 1,500 |
| 8. Managed runtime on v2 | 🌿 | 500 |
| 9. Reconcile docs | 🌱 | 400 |
| 10. Run coverage and retire | 🌱 | 300 |

GitHub remains authoritative for live PR state. The checkpoint above records the series handoff; update it when
advancing to the next PR. Generated-model churn is reported separately from authored changes.
