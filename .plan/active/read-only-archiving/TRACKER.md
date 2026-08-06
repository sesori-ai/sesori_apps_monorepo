# Read-Only Archiving: Tracker

## Current State

- **Plan slug:** `read-only-archiving`
- **Implementation base:** `origin/main` at `232974e1`
- **Series state:** Step 1/4 plan PR in preparation
- **Current step:** 1/4
- **Plan PR:** (to be opened)
- **Relationship:** prerequisite of `internal-chat-history`; that series does
  not start until this one has fully merged.
- **Next action:** open the step 1/4 plan PR.

## Delivery Steps

| Done | Step | Exact PR title | State |
|---|---|---|---|
| [ ] | 1/4 | `🌱 [read-only-archiving] Raise plan [step 1/4]` | in preparation |
| [ ] | 2/4 | `⚙️ [read-only-archiving] Reject unarchive and delete restore machinery [step 2/4]` | pending |
| [ ] | 3/4 | `🌿 [read-only-archiving] Enforce read-only archived sessions [step 3/4]` | pending |
| [ ] | 4/4 | `🌱 [read-only-archiving] Retire plan [step 4/4]` | pending |

## Execution Rules

- Merge in numeric order; each PR must remain independently valid at its own
  base.
- If step 3 trends past the 1,500-line soft cap it splits at the
  bridge/client boundary and the series total is restated before the first
  affected PR opens.
- Run focused tests, the owning package's tests, and the analyzer for each
  implementation step; run `architecture-implementation-review` (sub-agent)
  for steps 2 and 3.

## Verification Log

- (empty)

## Findings And Plan Deltas

- (empty)
