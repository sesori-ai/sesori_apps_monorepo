---
name: sesori-plan-maker
description: Create or update practical, code-informed implementation plans. Use when the user asks for a plan, implementation approach, roadmap, PR breakdown, or changes to PLAN.md or TRACKER.md.
---

# sesori-plan-maker

Create the smallest useful plan grounded in the current repository. The user's
latest explicit direction always wins over an older plan or process preference.

## Planning

- Inspect relevant instructions, code, tests, history, and references before
  deciding how the work should change.
- Ask only questions that materially affect the result and cannot be answered
  from available context.
- Make current behavior, scope, concrete changes, ownership/data flow,
  compatibility, verification, and material risks clear enough to implement.
- Keep small plans in chat. Use `.plan/active/<slug>/` only when durable state
  will help a genuinely multi-step effort.
- Preserve useful structure when updating an existing plan. Do not invent
  stages, branches, worktrees, or artifacts that do not help the work.
- Let `PLAN.md` capture the goal, scope, current behavior, implementation,
  verification, material decisions/risks, and causal cleanup. Add `TRACKER.md`
  or step files only when they make execution easier.
- For a multi-PR series, fix the step order, total, titles, and complexity before
  execution. Keep steps coherent, with 1,500 changed lines as a soft cap.
- Raise a durable plan in the first step and move it from `.plan/active/` to
  `.plan/completed/` in the final step.
- Prefer simple safeguards for observed or plausible flows. Record accepted
  risk rather than growing broad machinery around theoretical edge cases.
