# Permission Auto-Approval

## Capability

A bridge-wide setting ("YOLO mode") answers every permission request
automatically with a one-time approval, so unattended work continues with no
user present. It is a bridge policy, not a client feature.

## Required Behavior

- The setting is persisted bridge configuration, readable and writable from the
  bridge's own control surfaces and from a client settings surface. The
  committed value is authoritative for what is reported back.
- While enabled, an arriving permission is approved once, is not delivered to
  clients as answerable, and its reply is not surfaced as user activity.
- Enabling also resolves already-pending permissions, including child-session
  ones, and the same sweep runs when a backend event stream reconnects.
- A pending-permission snapshot served while the setting is on is resolved
  through auto-approval first: approved requests disappear from the response,
  and a request auto-approval could not answer stays visible and answerable
  instead of being hidden behind a stale awaiting-input badge.
- Each request is approved at most once. A failed approval is not recorded as
  approved and can be retried.
- Questions are never auto-answered.
- Disabling restores user-answered behavior for later requests without changing
  already-approved ones.
- A current client paired with a bridge that predates the setting still works and
  shows the capability as unsupported rather than pretending to control it.
- The client settings surface describes the setting in one plain sentence
  ("Sesori approves every permission request for you, so the agent never stops
  to ask."), with no warning tone.
- While the setting is on, every session page shows a neutral "YOLO" chip in
  the composer's model row. Tapping it explains the setting and opens the
  settings surface that holds the toggle. The client loads the flag on every
  bridge connect, and a change saved from this client's Settings updates open
  session pages at once.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Headless bridge, no plugin: the setting round-trips through bridge configuration and is reported from the committed value. |
| L2 Routine | Live plugin, one representative plugin: with the setting enabled, a real permission-raising turn completes with no user answer and nothing answerable delivered. |
| L3 Release | Live plugin, headless with no simulator or device, every permission-capable production plugin: live approval, the enable-time sweep of already-pending requests, child-session requests, and confirmation that questions still require an answer. |
| L4 Extended | Relay integration, every permission-capable production plugin: enabling with several requests outstanding across plugins, event-stream reconnect and plugin-restart sweeps, toggling during an active turn, approval failure and retry, and a second logical client seeing nothing answerable. |
| L5 Full | Client end to end on the release-target client platform, representative plugin: the client settings surface including in-progress, failed, and uncertain outcomes; an older bridge reported unsupported; persistence across a bridge restart; the session-page YOLO chip appearing and disappearing with the setting, and its explanation opening Settings on phone and desktop. |

## Exploration Guidance

Vary the moment of enabling relative to the request: before the turn, during a
turn with requests already pending, and just after a backend reconnect. Vary the
plugin and what the request is for, where the setting is changed, and whether
child sessions are involved. Confirm the negative case, questions still waiting,
in the same run.

## Failure Signals

- A permission reaches a client as answerable while the setting is on.
- A pending request survives enabling or a backend reconnect.
- A question is answered automatically.
- The auto-approval reply appears as user activity or triggers a completion
  notification as if a user acted.
- The reported setting differs from the persisted value, or a failed write is
  reported as success.
- Turning the setting off does not restore user answering.
- The session page shows no YOLO chip after a connect while the setting is on,
  or keeps showing it after this client turned the setting off.

## Known Limitations

- Auto-approval always uses one-time approval, never a persistent grant, so
  backends re-ask for equivalent operations.
- The sweep discovers requests through sessions the bridge knows are awaiting
  input; requests it cannot enumerate are not covered.
- The setting removes the human safety gate. Never enable it where an unreviewed
  destructive action would matter.
- A change made from the bridge's own command surface applies on the next start.
- The session-page chip shows the client's last-known value. A change made on
  another client or from the bridge shows after the next reconnect or Settings
  visit.

## Sources

- Bridge permission auto-approval and settings services, settings repository and
  route, orchestrator permission handling, bridge config command.
- Shared settings model; client bridge-settings surface, bridge-settings
  service, session-page YOLO chip, and their owning tests.
