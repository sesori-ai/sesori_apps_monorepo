# Notifications

## Capability

The bridge turns session activity into push notifications so a mobile user away from the app learns that an agent asked
a question, requested permission, finished a turn, or that a bridge update exists. Mobile registers its device, honors
per-category preferences, renders foreground messages, and opens the right session on tap. Desktop never registers for
push: while the window is hidden or unfocused, it derives question and permission attention locally from its
authenticated relay stream and presents it through the desktop OS. Mobile provider delivery through Apple and Google is
external.

## Required Behavior

- Immediate notifications exist only for question-asked, permission-asked, and installation-update events. Completion
  fires after a debounced busy-to-idle transition, is blocked while a question or permission is pending, and is
  suppressed for a user abort until the group is busy again. A Claude session
  with background sub-agents stays busy until the last one and its wake-up turn
  settle, so completion fires once for the whole span; a main-agent-only stop
  (`keep`) does not suppress the completion the kept sub-agents later earn,
  while a full stop does.
- A child prompt is attributed to its display (root) session. Rate limiting is per category plus session, so a
  throttled completion never suppresses a more urgent question, and every notification for a session collapses to one
  identity derived identically by bridge, server, and client.
- A send failure is logged well enough to separate auth from transport failure and never fails the session flow that
  produced it.
- The client registers when authenticated, re-registers on token refresh, unregisters before logout, restores
  registration if logout fails, and never re-registers while logout is in flight.
- Registration sends the same device ID the preferences are stored under, so the server can associate this push token
  with this device and suppress a disabled category before it reaches the delivery provider. A device ID that cannot be
  read registers the token without one: that install stays unfiltered rather than losing push, and recovers on the next
  registration.
- Foreground rendering needs the category enabled plus title and body; an unknown category and a preference read
  failure both default to enabled. Preferences are per account and cleared on account switch.
- A notification opened while unauthenticated defers until authentication, then routes to its session; viewing a
  session cancels its notifications. Desktop retains an initial open only when `AuthSession` confirms that a locally
  valid session can be restored, and routes it only when its account binding matches the restored account. Missing or
  mismatched bindings and every open after an account-ending transition are discarded rather than inherited by a later
  login.
- Desktop attention listens directly to relay SSE without registering a push token. A permission-asked or
  question-asked event uses `displaySessionId` when present, resolves that session's title/project, and shows only while
  the desktop window is hidden or unfocused and the desktop-owned switch is enabled. Requests blocked by focus,
  preference, or restoring authentication remain pending and are reconsidered when that gate opens. Requests are
  tracked independently under the display session: per-session native writes are serialized, a matching reply or
  rejection cancels the session-scoped notification only after its last outstanding request settles, and a resolved
  request cannot reappear after an in-flight title lookup. Opening one restores/focuses the window and routes to that
  session. The attention service owns logout's fence, native-write settlement, and cancel-all sequence before
  credentials are cleared; any other account-ending auth transition clears alerts and fences a newly authenticated
  account's writes until that cleanup finishes. The preference defaults enabled, persists under desktop application
  data, and disabling it clears already-delivered alerts.
- Desktop local content is limited to the session title plus category-level permission/question copy. The hidden
  routing payload also carries session, project, and account identity so opens can be account-bound; none of that
  metadata is rendered. It never includes prompt, transcript, question, permission-description, or tool payload. The
  service subscribes before Linux initialization can emit launch callbacks and retries a transient initialization
  failure on a later eligible attention request. A failed title lookup or native notification operation is logged and
  cannot fail session work or desktop startup.
- Mobile payloads carry category, event type, session and project identity, and user-visible event content. Question and
  permission bodies use backend text; update bodies may include the version; completion uses the bounded session title
  and up to ten whitespace-delimited words of the latest assistant text. The completion title is read from the stored
  session at send time, so a session whose in-memory push state was pruned for idleness or lost to a bridge restart
  still names itself; only a session with no stored title falls back to generic completion copy.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because external notification delivery is not a product heartbeat. |
| L2 Routine | Automated and headless bridge, representative plugin, fake push client: current event-to-payload content mapping, collapse identity, project attribution, completion debounce, pending-interaction blocking, abort suppression, per-category rate limits, maintenance step isolation. Desktop unit/widget coverage: focused/disabled suppression and resume, asked/resolved classification, title lookup, category-only content, serialized multi-request writes and in-flight cancellation, initialization retry/Linux callback ordering, persisted toggle, locally-restorable and account-bound open routing, account-ending cleanup, and service-owned logout settle-before-cancel ordering. |
| L3 Release | Mobile client end to end on the release-target platform with a fake messaging source: registration including the device ID, token refresh, logout, preference-gated foreground rendering, per-account persistence, notification-open routing including deferral, cancellation on open. Desktop automated coverage: hidden/unfocused local alert, click-to-focus/session navigation, resolve cancellation, toggle silence, logout isolation, and no push registration. |
| L4 Extended | Packaged or external on the release-target client platform: real background or terminated-app delivery, disabling a category on one device suppressing its remote delivery there while another device still receives it, completion from another production plugin, account switch and logout isolation, a child prompt opening its root. |
| L5 Full | Both mobile platforms end to end: OS permission denied then granted, collapse and replace across repeated notifications for one session, system-update notifications, and long-run maintenance pruning under many sessions. |

## Exploration Guidance

Vary which event arrives first and how tightly events cluster, since debounce, blocking, and rate limits interact: a
question mid-turn, an abort just before idle, two sessions completing together, a child prompt on a busy root. Vary
app state, per-category preferences, and auth transitions around the tap. Use
benign question, permission, assistant, title, and project fixtures with a real
provider because current payload content leaves the encrypted channel.

## Failure Signals

- A completion arrives while a question or permission is pending, or after a
  full abort; a Claude session with a running background sub-agent fires a
  completion before the sub-agent's wake-up turn settles, or fires twice; a
  main-agent-only stop suppresses the completion of the kept sub-agents.
- Notifications for one session do not collapse, or a tap opens the wrong session or a child instead of its root.
- A question is suppressed by an unrelated completion cooldown.
- Delivery continues after logout, or a new account receives the prior account's notifications. Desktop registers a
  push token, alerts while focused or disabled, fails to reconsider still-pending attention after a gate opens, leaks
  request payload content, lets an older concurrent write replace newer attention, keeps or recreates a resolved alert,
  cancels while another display-session request remains pending, accepts a missing or mismatched account binding,
  carries alerts across an account-ending auth transition, loses a Linux launch callback during initialization, never
  retries a transient initialization failure, or fails to focus and open the display session when clicked.
- A disabled category renders in the foreground, an unknown category is dropped, or a send failure surfaces as a
  failed session action.
- Payload content or routing metadata differs from the current mapping.

## Known Limitations

- Provider delivery is external and best effort; a missing notification may be throttling or OS policy. Never record
  unobserved delivery as pass or claim a delivery rate.
- Current provider payloads can include question or permission text, a session
  title, an assistant-response prefix, an update version, and a project identity
  that may be a local path. The ten-word completion limit has no character bound
  for one long token. This is a known privacy limitation, not the desired target.
- Fakes cannot prove background or terminated-app handling, OS permission behavior, or collapse rendering.

## Sources

`bridge/app/test/push/`, `shared/sesori_shared/test/notifications/`, `client/module_core/test/services/`,
`client/module_core/test/routing/`, `client/app/test/core/platform/`, `client/module_desktop_core/test/services/`, and
`client/desktop/test/core/platform/`; production code under `bridge/app/lib/src/push/`,
`client/module_core/lib/src/services/`, `client/module_desktop_core/lib/src/services/`, and
`client/desktop/lib/core/platform/`; docs/SECURITY.md carries the push disclosure.
