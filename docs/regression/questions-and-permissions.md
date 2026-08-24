# Questions And Permissions

## Capability

A backend asks for a tool permission or a structured question, the request
reaches every connected surface under the right session, and the user's answer
reaches the backend so the turn continues.

## Required Behavior

- A pending permission carries its tool, description, owning session, display
  root session, and whether an "always" answer is offered. A pending question
  carries its header, prompt, options, and whether multiple or custom answers
  are allowed.
- Allow once, allow always, and reject each reach the backend with the meaning
  the user chose. Once is never escalated to a broader grant.
- A plugin advertising ACP form elicitation maps supported string, string-enum,
  and boolean properties to questions and returns typed content under the
  backend's original property keys. Reject returns `decline`; abort, process
  exit, and disposal return `cancel`; unsupported schemas are declined without
  exposing prompt/default content in diagnostics.
- Pi extension `select`, `confirm`, `input`, and `editor` dialogs map to one
  single-select, Yes/No, or custom-answer question and return the exact Pi value,
  confirmation, or cancellation shape. Editor answers replace the full value;
  a bounded labelled prefill excerpt never implies that omitted text is retained.
- Pi mirrors upstream dialog expiry to retire the card, owns editor expiry,
  rejects pending cards on process/session cleanup, indexes imported children
  under their top-most display root and owning worktree project, and does not
  persist process-local dialog promises. Decorative extension UI is ignored;
  bounded `notify` messages use the existing toast event.
- A sessionless backend request is attributed to the most recently dispatched
  active turn, falling back to the last dispatched turn at its settlement
  boundary. A backend requiring exact form correlation must serialize prompts
  process-wide so another session cannot become the attribution target.
- Resolving a request retires it in the pending list, on every open surface, and
  in completion-notification suppression. Raising and resolving a request also
  refreshes the activity summary, so the session's awaiting-input state appears
  and clears without waiting for the turn to end.
- Normalized question and permission replies or rejections feed the existing
  durable user-side activity marker. Lifecycle cleanup that emits those events
  to retire pending UI on abort, thread close, process exit, or disposal can
  therefore advance the marker. Permission replies consumed by bridge
  auto-approval before normal event routing do not advance it.
- Child or sub-agent requests surface under their display root.
- Per-session pending lists are empty while a plugin is stopped or terminally
  failed and never start it. A project-wide question list reports unavailable
  when no plugin is active; after restart, pending state is read from the newly
  active backend.
- An archived session refuses replies with the archived read-only rejection.
- Question rejection carries the owning session ID. Missing or null ownership is
  a malformed request rather than triggering a cross-session owner search.
- Question choices preserve their distinct selected styling, per-question
  decline semantics, and custom-answer focus/input behavior when their shared
  tappable sheet chrome changes.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Live plugin, one representative plugin: a permission raised by a real turn appears as pending and one reply lets the turn proceed. |
| L2 Routine | Live plugin, representative: question variants (single, multiple, custom, reject), typed ACP scalar forms where supported, unsupported-form decline, abort cancellation, per-session and per-project pending listing, repeated or unknown request ids answered without corrupting state. Automated Pi coverage: select/confirm/input/editor exact replies and timeout cleanup. |
| L3 Release | Client end to end on the release-target client platform, every supporting production plugin: both request kinds per plugin, per-plugin "always" availability, child attribution, archived-session refusal, and pending requests suppressing completion notifications until resolved. |
| L4 Extended | Relay integration, every supporting production plugin: per-session empty lists while stopped or terminally failed, project-wide question unavailability with no active plugin, pending state re-read after restart, competing replies to one request, two logical clients observing one request and its retirement, and reconnect inside the replay window. |
| L5 Full | Headless bridge and live plugin for malformed requests and degenerate option sets; packaged or external on alternate client platforms for an older bridge not declaring "always". Every supporting production plugin where applicable. |

## Exploration Guidance

Vary which backend raises the request and how it is provoked, the answer kind,
the answer order when several are outstanding, and whether the answer comes from
the request's own session view, a parent view, or a second client. Vary whether
the session is fresh, resumed after a bridge restart, or reopened cold. Prefer a
different combination than the previous recorded run.

## Failure Signals

- A permission or question reply stalls behind a prompt sent to the same busy
  session (the send must be accepted at enqueue and release the session lane
  immediately).
- A request never appears, appears under the wrong session, or omits options the
  backend actually offered.
- An answer does not reach the backend, arrives with a different scope than the
  user chose, or leaves the turn blocked.
- An ACP form answer changes scalar type, uses a display label instead of the
  backend value, reaches the wrong session, or remains pending after abort.
- A Pi dialog loses multiline input, silently retains truncated editor prefill,
  replies with the wrong wire variant, survives timeout/process cleanup, or
  appears outside its imported display root or owning project.
- A resolved request stays visible, keeps suppressing notifications, or returns
  after reconnect.
- A manually routed reply/rejection fails to advance the existing activity
  marker, or an auto-approved permission reply advances it.
- Reading pending state starts an intentionally stopped backend.
- An archived session accepts a reply.

## Known Limitations

- "Always" scope is backend defined; some backends persist it only for the
  current session, and some expose it only when the backend offers it.
- No bridge policy auto-answers questions; only permissions can be auto-approved.
- Plugin scope follows currently registered plugins and their declared
  capabilities, not a fixed list. A plugin that does not expose a request kind
  is not a failure.
- Untested Hermes gap (remove this entry once verified): no Hermes permission
  request was ever observed. The tested provider completed file tools without
  emitting an ACP permission request, so once/reject/always handling and
  two-session correlation are unexercised for this harness.

## Sources

- Bridge pending-interaction and archived-validator services; per-plugin
  approval registries; shared pending permission/question and reply models.
- Client permission and question surfaces and their auto-dismiss behavior.
- Owning tests for pending interaction, reply routes, and pending state without
  a started backend.
