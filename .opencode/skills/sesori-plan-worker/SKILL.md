---
name: sesori-plan-worker
description: Execute implementation plans and multi-step PR series end to end. Use when the user asks to implement, continue, or work the next step of a plan, when working from PLAN.md or TRACKER.md, or when a monitored plan-series PR merges.
---

# sesori-plan-worker

Treat the plan as an editable guide. Follow the user's latest direction,
implement the smallest complete change, and keep plan/tracker truth current when
execution changes assumptions, scope, status, or later steps.

## Execution

1. Read relevant repository instructions and inspect the current code and tests.
2. Locate the matching active plan when one is referenced; ask only if the match
   or a material decision is genuinely ambiguous.
3. Implement and verify the current work, updating durable plan state when
   needed.
4. Follow repository review and delivery rules, including monitoring every PR
   immediately after opening it.

## One Step Ahead

Unless the user says otherwise, keep one plan-series PR open and work at most
one successor step locally:

- While Step `x` is in PR, create a new local branch for the next planned step
  from Step `x` and start it without waiting for another request.
- Keep that successor branch local until Step `x` merges. Do not raise its PR,
  and do not begin another step while it is only local.
- Pause the successor as needed to address Step `x` monitor reports, then return
  to it without discarding local work.
- Do not poll for the merge. A `[PR Monitor]` merged report is the trigger to
  sync the successor branch with the updated target branch, finish and verify
  it, update plan state, push it, raise its PR, and start its monitor.
- Once the successor is in PR, immediately create a local branch for the next
  step and begin it. Do not wait for the user to ask.
- Do not advance after a PR closes without merging. Report genuine blockers and
  preserve local work.

The user can override this pipeline at any time.
