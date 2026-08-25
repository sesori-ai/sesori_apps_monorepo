# Bridge-Owned Prompt Queue — Tracker

| Step | PR title | Status | PR | Notes |
|---|---|---|---|---|
| 1/7 | 🌱 [bridge-owned-prompt-queue] docs: raise the bridge-owned prompt queue plan [step 1/7] | Merged | #946 | |
| 2/7 | ⚙️ [bridge-owned-prompt-queue] contracts: prompt ids and queued-prompt wire surface [step 2/7] | Merged | #948 | ACP stamps promptId on its acceptance echo already |
| 3/7 | ⚙️ [bridge-owned-prompt-queue] bridge: route and relay the queued-prompt surface [step 3/7] | Merged | #950 | archived-cancel guard added in review |
| 4/7 | 🚧 [bridge-owned-prompt-queue] claude: accept prompts at enqueue and own the queue [step 4/7] | Merged | #951 | echo-expectation and settle fences added in review |
| 5/7 | 🚧 [bridge-owned-prompt-queue] client: render the bridge queue and transform states seamlessly [step 5/7] | Merged | #952 | |
| 6/7 | 🌿 [bridge-owned-prompt-queue] docs: reconcile session-turns regression coverage [step 6/7] | Merged | #953 | |
| 7/7 | ⚙️ [bridge-owned-prompt-queue] verify: run recorded regression coverage and retire the plan [step 7/7] | This PR | — | on-device blink found during verification → fixed standalone in #958 |

## Coverage Run Record (Step 7)

Run date: 2026-08-18/19, all on merged `main` (post step 6). Session-turns L4
scope for the delivered queue behavior.

### Automated

Full CI matrix green on every merged step: shared (409 incl. queued-prompt
round-trips), bridge workspace (all plugin packages incl. claude 230 and
bridge app 2658), client `module_core` and `app` (999). The claude suites pin
accept-at-enqueue, queue exposure/events, dedupe pre- and post-dispatch,
per-item cancel, abort clearing, echo `promptId` attachment with
message-before-queue-update ordering, command synthetics, spawn-failure
surfacing, and the blocking initial turn.

### Live plugin (Claude CLI 2.1.233, slot-1 dev bridge, debug server)

- Steering accept while a turn ran: HTTP 200 in **10.5 ms / 2.6 ms** (was:
  held for the turn's remainder, then the phone's 30 s timeout).
- `POST /session/queued_prompts` listed entries immediately, FIFO.
- Cancel of a queued entry: 200; the cancelled prompt **never dispatched**
  (transcript contains no such turn).
- Duplicate `promptId` retry: 200 in 2.2 ms, no second entry, exactly one
  delivered turn.
- SSE ordering (warm and cold): `message.updated` carrying the `promptId`
  strictly **before** the `session.queued-prompts` removal.
- Abort while one turn ran and one was queued: returned in 2.6 s (not blocked
  behind queued work), interrupted the turn, and emptied the queue.
- Cold session (process torn down): ACK 10.5 ms; the queued entry stayed
  continuously listed through the ~3.6 s spawn until its echo landed.

### Client end to end (phone, production relay)

User-performed on-device sessions against merged `main`: steering a busy
session, sends to idle/stopped sessions, queued bubble visible through
harness spawn, cancel affordance. Found one defect — a one-frame blink at the
queued→sent handoff — fixed in **#958** (stable prompt row identity, with a
no-blank-frame widget regression test); final on-device confirmation follows
that merge.

### Not separately exercised (accepted reduction — see PLAN.md)

Enumerated with stand-in evidence in PLAN.md's recorded-reduction note: a
second simultaneous client observer, a scripted disconnect-mid-send retry, a
permission ask answered while a prompt sat queued, live FIFO dispatch of
two-plus simultaneously queued entries, scripted exit/re-enter and
lock/unlock passes, and a live send through a second plugin. The pending
on-device confirmation of the #958 handoff polish is a post-merge follow-up,
not part of this record.
