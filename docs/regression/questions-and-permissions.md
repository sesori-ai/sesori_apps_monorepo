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
- Resolving a request retires it in the pending list, on every open surface, and
  in completion-notification suppression.
- Child or sub-agent requests surface under their display root.
- Listing pending state never starts a stopped backend.
- An archived session refuses replies with the archived read-only rejection.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Live plugin, one representative plugin: a permission raised by a real turn appears as pending and one reply lets the turn proceed. |
| L2 Routine | Live plugin, representative: question variants (single, multiple, custom, reject), per-session and per-project pending listing, repeated or unknown request ids answered without corrupting state. |
| L3 Release | Client end to end on the release-target client platform, every supporting production plugin: both request kinds per plugin, per-plugin "always" availability, child attribution, archived-session refusal, and pending requests suppressing completion notifications until resolved. |
| L4 Extended | Relay integration, every supporting production plugin: pending state after plugin restart, stop, or terminal failure; competing replies to one request; two logical clients observing one request and its retirement; reconnect inside the replay window; listing while the backend is stopped. |
| L5 Full | Headless bridge and live plugin for malformed requests and degenerate option sets; packaged or external on alternate client platforms for an older client omitting the rejection owner and an older bridge not declaring "always". Every supporting production plugin where applicable. |

## Exploration Guidance

Vary which backend raises the request and how it is provoked, the answer kind,
the answer order when several are outstanding, and whether the answer comes from
the request's own session view, a parent view, or a second client. Vary whether
the session is fresh, resumed after a bridge restart, or reopened cold. Prefer a
different combination than the previous recorded run.

## Failure Signals

- A request never appears, appears under the wrong session, or omits options the
  backend actually offered.
- An answer does not reach the backend, arrives with a different scope than the
  user chose, or leaves the turn blocked.
- A resolved request stays visible, keeps suppressing notifications, or returns
  after reconnect.
- Reading pending state starts an intentionally stopped backend.
- An archived session accepts a reply.

## Known Limitations

- "Always" scope is backend defined; some backends persist it only for the
  current session, and some expose it only when the backend offers it.
- No bridge policy auto-answers questions; only permissions can be auto-approved.
- Plugin scope follows currently registered plugins and their declared
  capabilities, not a fixed list. A plugin that does not expose a request kind
  is not a failure.

## Sources

- Bridge pending-interaction and archived-validator services; per-plugin
  approval registries; shared pending permission/question and reply models.
- Client permission and question surfaces and their auto-dismiss behavior.
- Owning tests for pending interaction, reply routes, and pending state without
  a started backend.
