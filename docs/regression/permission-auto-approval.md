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
- A session can override the bridge setting with its own choice, "ask" or
  "YOLO"; clearing the override makes it follow the bridge setting again. The
  bridge persists the override with the session and reports it on the session.
  A child session follows its nearest ancestor's override. Only sessions whose
  effective mode is YOLO are auto-approved: an asking session keeps its
  requests answerable while the bridge setting is on, and a YOLO session is
  auto-approved while the bridge setting is off.
- Switching a session to YOLO resolves its already-pending permissions at once.
  Other surfaces learn about the change through the normal session update.
- Setting an override on a session the bridge does not know fails with a
  structured "session not found" error. A bridge that predates overrides
  reports that it does not support them, so clients never offer the choice.
- A current client paired with a bridge that predates the setting still works and
  shows the capability as unsupported rather than pretending to control it.
- The client settings surface describes the setting in one plain sentence
  ("Sesori approves every permission request for you, so the agent never stops
  to ask."), with no warning tone. Its row and the YOLO chip share one YOLO
  icon, a shield with an x, distinct from the fast-mode bolt.
- On a bridge that supports overrides, every session page shows the session's
  approval mode in the composer's model row: a warning-coloured shield with
  "YOLO" while the session is effectively YOLO, and a quiet outline shield,
  named "Ask for approval", while it asks. Touch rows show only the glyph.
  Its menu offers "Ask for approval" and "Approve everything (YOLO)", marks the
  option matching the bridge setting "(default)", and shows YOLO in the warning
  colour. On a top-level session, picking the default option clears the
  override, so the session follows later changes to the bridge setting; picking
  the other option stores it as an override. A child session always stores its
  pick as an explicit override, so it wins over an ancestor's. A failed change
  keeps the acknowledged mode and says so.
- On a bridge that predates overrides, the session page shows a "YOLO" chip
  only while the setting is on. Tapping it explains the setting and opens the
  settings surface that holds the toggle; it offers no per-session choice.
- The client loads the setting on every bridge connect, and a change saved from
  this client's Settings updates open session pages at once.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Headless bridge, no plugin: the setting round-trips through bridge configuration and is reported from the committed value; a session override can be set, read back on the session, and cleared, and survives a bridge restart. |
| L2 Routine | Live plugin, one representative plugin: with the setting enabled, a real permission-raising turn completes with no user answer and nothing answerable delivered; a session overridden to "ask" still asks, and a session overridden to YOLO with the setting off does not. |
| L3 Release | Live plugin, headless with no simulator or device, every permission-capable production plugin: live approval, the enable-time sweep of already-pending requests, child-session requests, and confirmation that questions still require an answer. |
| L4 Extended | Relay integration, every permission-capable production plugin: enabling with several requests outstanding across plugins, event-stream reconnect and plugin-restart sweeps, toggling during an active turn, approval failure and retry, and a second logical client seeing nothing answerable. |
| L5 Full | Client end to end on the release-target client platform, representative plugin: the client settings surface including in-progress, failed, and uncertain outcomes; an older bridge reported unsupported; persistence across a bridge restart; the session-page approval chip switching a session between asking and YOLO from its menu, and clearing to the bridge default; on an older bridge the read-only YOLO chip appearing and disappearing with the setting, and its explanation opening Settings on phone and desktop. |

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
- A session overridden to "ask" is auto-approved, a session overridden to YOLO
  is not, or a child session ignores its parent's override.
- Switching a session to YOLO leaves its pending requests waiting.
- A session override is lost on bridge restart or catalog import, or another
  surface keeps showing the old value.
- The session page's approval chip disagrees with the session's acknowledged
  mode, or picking the bridge's default leaves an override stored.
- An older bridge shows a per-session menu, shows no YOLO chip after a connect
  while the setting is on, or keeps showing it after this client turned the
  setting off.

## Known Limitations

- Auto-approval always uses one-time approval, never a persistent grant, so
  backends re-ask for equivalent operations.
- The sweep discovers requests through sessions the bridge knows are awaiting
  input; requests it cannot enumerate are not covered.
- The setting removes the human safety gate. Never enable it where an unreviewed
  destructive action would matter.
- A change made from the bridge's own command surface applies on the next start.
- The session-page chip shows the client's last-known bridge setting. A change
  to the bridge setting made on another client or from the bridge shows after
  the next reconnect or Settings visit; a session override shows at once.
- The chip reads only the session's own override. A child session without one
  shows the bridge default even when the bridge applies its parent's override.
  Picking a mode on the child still always takes effect.

## Sources

- Bridge permission auto-approval and settings services, settings repository and
  route, orchestrator permission handling, bridge config command, session
  approval-override route, session table and mutation dispatcher.
- Shared settings and session approval-override models; client bridge-settings surface, bridge-settings
  service, session-page approval and YOLO chips, session approval service, and
  their owning tests.
