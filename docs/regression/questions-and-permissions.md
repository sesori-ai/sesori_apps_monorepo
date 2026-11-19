# Questions And Permissions

## Capability

A backend asks for a tool permission or a structured question, the request
reaches every connected surface under the right session, and the user's answer
reaches the backend so the turn continues.

## Required Behavior

- MCP server context can enrich a tool permission; authentication does not grant
  permission to execute it. Typed forms preserve native keys, values, optional
  omission and original-owner settlement. External-action consent uses its own
  request and opens no browser until explicitly requested. It is not an ordinary
  tool approval or a fabricated question. An older released client's legacy
  question reply and reject paths both cancel the typed request; they do not
  submit typed acceptance or semantic decline. The supported
  adapters and cumulative client/relay matrix are in
  [MCP management](mcp-management.md#regression-levels).
- A pending permission carries its tool, description, owning session, display
  root session, and whether an "always" answer is offered. A pending question
  carries its header, prompt, options, which options are the harness's default
  answer, and whether multiple or custom answers are allowed. An older bridge
  omits the default flag and its options arrive unselected.
- The question sheet shows default options selected on arrival, so the user can
  submit at once. A custom answer on an option list is a last "Other" option;
  picking it grows a text field below it and focuses it, and picking another
  single-choice option collapses it. A free-text-only question shows its field
  directly. Submit never ignores a tap: with "Other" picked and its field empty
  the field shows the reason; with a question unanswered the sheet moves to it
  and says why.
- Codex synchronous `request_user_input` requests preserve every question,
  header, ordered option and description. Replies preserve the original
  question IDs and answer ordering, including custom answers and declined rows.
- Codex `request_user_input_async` assistant messages create the same pending
  questions on mobile and desktop. Their options remain selectable and custom
  answers remain available. The tool's immediate `accepted` acknowledgement
  is not shown as a completed question/answer tool card and never counts as
  user input or permission approval.
- An async Codex question remains pending after its originating turn completes.
  Reply and reject send contextual user input to the owning conversation through
  normal turn submission, steering a running turn or starting a turn while idle
  without overriding its model or collaboration mode. A child question appears
  under its display root but the answer goes to that child.
- A question settles only after its backend submission succeeds; a failed async
  submission remains pending for retry. Competing replies or rejections submit
  only once while backend acceptance is pending. Explicit rejection tells Codex
  which questions were declined. Abort, thread close, disconnect and disposal retire
  connection-local async cards without starting new work to report cleanup.
  Historical transcript reads do not recreate already-finished question cards.
- Codex requests containing a secret-input question fail explicitly before any
  card is presented. Masked secret entry is not yet supported; these requests
  must never appear as ordinary plain-text input.
- Allow once, allow always, and reject each reach the backend with the meaning
  the user chose. Once is never escalated to a broader grant.
- Permission dialogs use the shared Prego action sheet in both themes. Like
  the question form, it floats on phone and is a centred dialog on desktop. It
  shows a generic action heading, the complete backend tool label and selectable,
  copyable Markdown description, then full-width stacked **Allow**, optional
  **Always approve**, and **Don’t allow** actions. **Allow** means once only.
  Code blocks in the description wrap rather than side-scroll, so no part of
  an approved command sits off-screen. A Codex command approval shows the
  exact command verbatim in such a block, then its working directory when
  sent, then Codex's reason; the needs-you card and push lead with the command's
  first line. The push body is plain text, without code-block indentation,
  fences or code-span backticks. Failure signal: a Codex approval showing only
  `exec` and a reason. Long details normally scroll above visible actions. When the viewport is
  cramped relative to the text scale, the whole sheet scrolls so every decision
  remains reachable; enlarged text can cause this breakpoint to be crossed.
  Keyboard and safe-area insets keep the floating surface clear of system UI.
  Scrim, swipe, or Escape dismissal leaves the request pending; external settlement closes
  it without a reply.
- MCP typed form requests use one shared overlay on both shells. Numeric typing
  remains raw until submission; optional omission stays distinct from false, zero
  and empty text. Validation retains drafts and focus, while closing sends no reply.
  Original-owner settlement advances the existing pending-list scheduler, including
  when SSE arrives before HTTP. See [MCP forms](mcp-management.md#session-forms).
- OpenCode v2 forms keep visible supported fields in native order. Replies use
  each field's native key and typed value: string/choice, string list, boolean,
  number or integer. String and multiselect answers matching an option label
  map to its native value; unmatched custom text is preserved. An unanswered
  field is omitted rather than invented.
  Numeric replies must be finite, integral for integer fields, and within native
  inclusive bounds. An invalid local conversion makes no reply request.
  A child form may display under its root, but the reply targets its native
  owner. Only successful replies consume pending constraints; a failure remains
  observable and is reconciled by native events or a full refresh.
- A plugin advertising ACP form elicitation maps supported string, string-enum,
  boolean, and finite string-choice array properties to questions and returns
  typed content under the backend's original property keys. An array whose
  `items.anyOf` entries carry string `const` values becomes an options-only
  checkbox question; selected display labels encode back to an array of those
  values. Duplicate titles remain distinguishable. Unsupported array shapes,
  including unconstrained, nested, and non-string choices, are declined without
  exposing labels or defaults in diagnostics.
- An ACP `number` or `integer` property becomes a custom-text question whose
  text shows its `minimum`/`maximum` bounds and whose numeric `default` is the
  suggested text. The trimmed answer encodes as a finite JSON number; text that
  does not parse (including a fraction for `integer`) or is not finite (`NaN`,
  `Infinity`, `1e999`) omits an optional property and
  declines the form when the property is required. OMP 18.18.3+ sends these
  from its built-in `ask` HTML forms (`<input type="number|range">`); declining
  them aborts the OMP turn, so a regression shows as a vanished question.
- Every ACP schema property remains a separate question in property order,
  unless the plugin pairs a choice property with a plain string "other"
  property: the pair is one question with a custom answer. A listed choice
  fills the choice property; custom text fills the paired property and
  satisfies a required choice. Only the OMP plugin pairs, by its `qN`/`qN__other`
  (ask tool) and `name`/`name__other` (HTML form from 18.20.0; `name_other` in
  18.18.3 to 18.19.0) naming; shared mapping knows no
  naming convention. Other ACP plugins keep a separate string property as its
  own custom-text question.
- An ACP schema `default` marks the matching option as the default: a
  string-choice value, the values of a choice array, `Yes`/`No` for a boolean,
  and "Use suggested text" for a string or number. OpenCode v2 form fields
  mark their native `default` the same way (choice values, multiselect values,
  boolean).
- In a multi-question ACP form, declining an optional question submits an empty
  answer slot and omits only that property. Each property's required flag is
  enforced independently: omitting a required property declines the form.
  A single-question decline still rejects the whole request. Reject returns
  `decline`; abort, process exit, and disposal return `cancel`.
- OMP advertises form support only on its live plugin connection. Its catalog
  and cleanup scratch connections keep form elicitation disabled. Supporting
  arrays in the shared mapper does not enable another plugin's advertisement.
- Pi extension `select`, `confirm`, `input`, and `editor` dialogs map to one
  single-select, Yes/No, or custom-answer question and return the exact Pi value,
  confirmation, or cancellation shape. For select, input, and editor dialogs,
  Pi's title is the user-facing prompt, so it remains fully readable in the
  scrollable question body instead of the ellipsized sheet heading. Confirm
  dialogs preserve their distinct title and message, while input hints and
  editor guidance remain visible with the prompt. Editor answers replace the full
  value; a bounded labelled prefill excerpt never implies that omitted text is
  retained.
- Pi mirrors upstream dialog expiry to retire the card, owns editor expiry,
  rejects pending cards on process/session cleanup, indexes imported children
  under their top-most display root and owning worktree project, and does not
  persist process-local dialog promises. Decorative extension UI is ignored;
  bounded `notify` messages use the existing toast event attributed to their
  owning session, so another session or an unrelated route does not present them.
- Antigravity converts valid `interaction_` permission requests into one single-choice question while preserving exact
  advertised labels and opaque option IDs; duplicate labels fail closed. Ordinary permissions expose exactly one
  unambiguous warning-free `allow_once` and an optional warning-free `reject_once`. Persistent `allow_always` choices
  are always excluded as a separate policy, and any choice of any kind with non-null `agy.security.warning` metadata is
  independently excluded. Invalid or ambiguous input cancels instead of guessing, escalating, or leaving hidden work.
- GitHub Copilot uses standard ACP permission requests correlated to their tool
  call. The client always presents Once and Reject for a pending permission and
  presents Always only when the request offers `allow_always`. The registry maps
  a choice to an exact offered ACP option; if Once or Reject has no matching
  option, it cancels rather than escalating or selecting another scope. The
  pinned CLI does not forward `ask_user` over ACP, so Copilot declares no
  question capability and Sesori never invents a custom question channel.
- Claude Code offers Always only when its `can_use_tool` request does not set
  `suppress_always_allow_rule` and carries either at least one `addRules`
  suggestion with rules or a `setMode` suggestion to `acceptEdits`. Always sends
  the rules back with the `session`
  destination, even when Claude suggested a settings file (Bash and Skill rules
  arrive as `localSettings`), so the same command runs again in that session
  without a request and Sesori never writes the user's settings files. When
  there is no rule but a `setMode` suggestion to `acceptEdits` (a file edit),
  Always sends that mode switch with the `session` destination: Claude switches
  the session to accept-edits, later edits in it run without a request, and a
  relaunched process starts in accept-edits. Choosing Plan still applies; the
  next Agent turn, or a bridge-started turn with no agent, returns to
  accept-edits. The grant lives in bridge memory, like the session rules, so a
  bridge restart ends it. While the grant holds, a grey "Accepting edits · Turn
  off" line fades in above the composer of that session, on the phone and the
  desktop, without moving the composer. The session's
  `POST /session/permissions` snapshot carries `editsAutoAccepted` and each
  change arrives as `session.edits-auto-accepted`, so opening or reconnecting
  shows the bridge's current value and a bridge restart clears it. Turn off
  hides the line at once and calls `POST /session/stop-accepting-edits`: the
  bridge first switches the running process back to asking (`default`) without
  waiting for queued prompts, then drops the grant, so the next edit, even in
  the same turn, asks again, and every surface's line fades out. If the switch
  fails, the grant stays, the route fails, and the line comes back with an
  error alert, so Turn off can be tried again. An older app never shows the line; a newer app on an older
  bridge reads the missing field as false and shows nothing. If the plugin
  stops after its idle timeout, the grant ends without an event, so a connected
  app keeps the line until its next snapshot. Any other mode (`bypassPermissions`,
  `plan`, `default`) and other suggestion types are never sent. A request with
  nothing to grant (an absent or empty suggestion list, or only such other
  suggestions) offers Once and Reject only.
- DeepSeek standard ACP permissions use explicit session IDs or exact tracked
  tool-call attribution, retained across parent turns. Ambiguity cancels; only
  unattributed requests use the ACP active-turn fallback. These permissions
  preserve the exact tool call ID and expose only the scopes the adapter offers;
  v1 does not offer allow-always.
  DeepSeek extension questions preserve ordered question IDs, single/multiple/
  custom answer variants, plan-review fixed choices, and supplemental free-form
  detail. Native input cancellation clears only earlier requests on the ordered
  stream; later requests survive even when they reuse a question ID. Abort,
  process exit, and disposal cancel pending requests and reject late replies.
  Phone QA on unchanged published adapter 0.1.4 proved two bounded live cases:
  API-triggered Stop rejected an earlier real permission and removed its open
  sheet, and a real question was cancelled while a distinct prompt submitted
  after Stop was written produced a new question that remained visible,
  answerable on the phone, and cleared normally. The permission sheet showed a generic tool label and opaque call ID,
  so cancellation passed but complete permission presentation did not. Desktop,
  cross-client observation, restart/reconnect, and alternate mobile platforms
  were not run.
- Grok runs in its normal ask mode without `--always-approve` or `--yolo`.
  Standard ACP permissions preserve the exact session, tool call, and offered
  option IDs; Once, Reject, and every scope the request actually advertises stay
  phone-mediated unless an existing explicit bridge auto-approval rule applies.
  Scoped-stop preflight preserves pending Grok requests when `confirm` rejects,
  when active-root `keep` is unsupported, and when idle-root child-only `keep`
  succeeds. Accepted named-child stop cancels only that child's pending ACP
  interaction; full snapshot stop cancels root and selected-child interactions.
  This input cleanup stays scoped; completion suppression for a fully stopped
  named child records the root ID and applies to the root session group.
  Process exit and disposal also cancel pending Grok requests rather than
  broadening or silently approving them. These guarantees have automated
  fixture coverage only: production-composition QA emitted zero standard
  permission requests under unchanged configuration, so live permission
  preservation, isolation, and cleanup remain unexecuted. Phone automation was
  blocked before any visible interaction, so no phone permission result is
  claimed. No native Grok question channel is claimed.
- A sessionless ACP request first resolves its top-level or nested
  `toolCall.toolCallId` against tracked calls. An exact match retains its session;
  an ambiguous match cancels rather than falling back to another active turn.
  Without tool-call attribution, a sessionless backend request uses the most
  recently dispatched active turn, or the last dispatched turn at its settlement
  boundary. Turns of different sessions run concurrently, so a backend that
  needs exact form correlation must attribute its requests by session ID or
  tool call. OMP supplies explicit session IDs on permissions and forms, so its
  independent session turns remain attributable while running concurrently.
- Deleting a tracked ACP parent retires pending input for its full descendant
  subtree, including a running grandchild of a finished child, so removed
  sessions cannot leave unanswered requests holding the plugin busy.
- Resolving a request retires it in the pending list, on every open surface, and
  in completion-notification suppression. Raising and resolving a request also
  refreshes the activity summary, so the session's awaiting-input state appears
  and clears without waiting for the turn to end. Each resolution is announced
  once; OpenCode v1 announces a reply the bridge cleared at once, even when
  OpenCode's own event never arrives, and drops that event when it does.
- A request the harness withdrew itself retires through the same clearing event
  as a cancellation, sends the harness nothing, and a late Sesori answer to it
  is refused. Codex `serverRequest/resolved`, ACP `$/cancel_request` (sent by
  OMP when steering supersedes a pending approval) and Claude
  `control_cancel_request` each retire only the request with that exact id; a
  JSON-RPC id may be an int or a string. OpenCode v2 sends no reply event when
  an interrupt drops a pending permission, so its `session.execution.interrupted`
  (reason user, superseded or inactivity) retires every pending permission of
  that session, including after Sesori's own Stop. When an ACP agent answers a
  `session/prompt` (any stop reason, or a JSON-RPC error), its turn is over, so
  every request still pending for that exact session retires the same way, before
  the session goes idle; children and other sessions keep theirs. A local prompt
  timeout retires nothing, because the agent may still be waiting. Failure
  signal: a Hermes approval left open past its 300 s timeout stays on screen
  after the turn ends. Every harness is listed in
  [Requests the harness withdrew](../HARNESS_CAPABILITIES.md#requests-the-harness-withdrew).
- ACP and Codex teardown attempts every pending backend resolution independently,
  logs responder or request-subscription failures, and still clears each stale
  client prompt. One failed resolution never skips later pending entries.
- Cursor acknowledges `generate_image` and `update_todos` extension requests
  before reinjecting them as notifications. A notification-mapping failure is
  logged and does not break later permission or question routing.
- Normalized question and permission replies or rejections feed the existing
  durable user-side activity marker. Lifecycle cleanup that emits those events
  to retire pending UI on abort, archive, thread close, process exit, disposal or
  a harness withdrawal can
  therefore advance the marker. Permission replies consumed by bridge
  auto-approval before normal event routing do not advance it.
- Child or sub-agent requests surface under their display root.
- Per-session pending lists are empty while a plugin is stopped or terminally
  failed and never start it. After restart, pending state is read from the newly
  active backend.
- An archived session refuses replies with the archived read-only rejection, and
  pending lists drop every request whose own session is archived. A request
  from an active sub-agent stays listed under an archived display root. Archiving
  a running root stops its sub-agents first, so that leaves only a sub-agent the
  stop did not reach (see [archiving](session-archiving-and-deletion.md)).
- Question rejection carries the owning session ID. Missing or null ownership is
  a malformed request rather than triggering a cross-session owner search.
- Question choices preserve their distinct selected styling, per-question
  decline semantics, and custom-answer focus/input behavior when their shared
  tappable sheet chrome changes.
- Mobile and desktop use the same session-detail pending-question and permission
  presentation. Opening a session on either surface presents the request over
  that session, sends replies through the owning session cubit, and dismisses it
  when the pending request settles; shell routing must not duplicate or bypass
  that ownership.
- While a session waits on the user, a pale amber needs-you card docks above
  its composer, as wide as the composer. There is one card per request type:
  questions, then permissions. Each names the pending count, shows the first
  request's opening line in ordinary text, a command included, with its Markdown
  resolved (a `**bold**` warning shows without its asterisks), and a tap anywhere
  on it, like its Answer or Review button, opens the existing modal. The card itself looks the same on phone
  and desktop: light uses a cream warning fill and dark a faint amber tint, each
  with a soft amber border, an amber icon and a darker amber label that clears
  4.5:1, over primary text. The buttons differ. On the phone every card's button is bright: the white secondary button
  in light, the white solid one in dark. On desktop only the first card's button
  is solid (black in light, white in dark) and a second card's is the quieter
  secondary button. Stacked buttons share a left edge.
  A card grows in above the composer and folds away when answered, holding the
  newest row's gap to the composer on every frame; reduced motion shows it at
  once. Read-only, archived and blocked sessions show no card.
- A request's card steps aside while its sheet or dialog is open: it folds away
  as the sheet rises (a sheet that opens on arrival never shows it), so the
  transcript has settled before the user answers. When the sheet closes because
  the request was answered, answered elsewhere or withdrawn, nothing in the
  transcript moves while it leaves. While another request of the same kind is
  still pending, such as parallel sub-agent permissions, the card stays folded
  and that request's sheet opens next, after an answer and after a withdrawal
  alike. Only dismissing a sheet without answering, a failed reply, or a next
  sheet that cannot open brings the card back, with a glide. A permission reply
  the harness answers with 404 (no longer pending, such as one another surface
  answered first) counts as answered, not failed: no toast and no reload, and
  the next pending request opens.
- When a request goes away together with a change to the transcript, such as an
  interrupted turn folding its running step, the transcript holds still while
  the card folds or the sheet leaves (200 ms) and then applies the change, so
  the two motions run one after the other rather than stacking. While the card
  folds, the transcript follows by its bottom inset alone and its rows are not
  rebuilt. With reduced motion, the card goes and the change applies at once,
  with no glide and no hold.
- These glides apply at the newest edge only. Scrolled away from it, a card
  growing or folding, the composer or any other bottom control changing
  height, or the keyboard opening or closing leaves the rows being read where
  they are on screen. A shrink larger than the distance scrolled settles the
  list at the newest edge, where it follows the latest messages again and Jump
  to latest goes away. A glide back to the newest edge is not held.
- When management blocks the session's harness, needs-you cards and new response
  dialogs are hidden. A dialog already open on either surface closes without
  answering or rejecting; its pending model remains until an authoritative
  refresh or settlement event. Cubit reply and rejection seams independently
  refuse stale callbacks,
  including completions from another surface, until interaction is usable again.

### Agent question pages

An agent's `send_page` call ([Sesori MCP](sesori-mcp.md)) becomes a pending
request of kind `page` on the session that shows it, which is the root session
for a sub-agent's page.

- The session needs the user as it does for a harness question. The needs-you
  card grows in with the generic wording, "1 request · <title> · Review",
  project summaries mark the session as awaiting input, and push says "Question
  requires input" with the title as its body. The page never opens by itself,
  either on arrival or after another request is answered. Only a tap on the
  card or its Review button opens it.
- The page slides up from the bottom over the session, covering it on a narrow
  window or as a wide panel over the dimmed session from 960 px. Reduced motion
  shows and hides it at once. A fixed header holds the title, "From <harness ·
  session>", Close and a Page actions menu with Dismiss page. The intro and the
  sections scroll below it. A sticky bar shows "<n> of <total> answered" with
  Submit, or Done on a page with no questions, and keeps one height in every
  state. Close, Escape or a tap on the dimmed area slides the page down and
  leaves it pending, and the card comes back. Picks and notes stay in memory
  per surface until the page settles, so reopening keeps them. They are not
  synced.
- Questions are single choice, multiple choice or text, and each one has an
  optional note. The page ends with an "Anything else?" note. A recommended
  option shows "Recommended" and is never preselected. A question of a kind the
  app doesn't know says "This question needs an updated Sesori app. You can
  submit without it." and never blocks Submit.
- Each image sits in a box at the size its file declared, with a height cap
  that narrows a tall image. It shimmers while loading and then fades in, so
  nothing below it moves. An image that can't load shows a neutral placeholder
  in the same box: a crossed-out photo icon that screen readers announce as
  "Image unavailable". Tapping a loaded image opens it in
  the chat's image viewer. Option images sit under the option's description.
- Submit with a required question unanswered (a note alone doesn't answer it)
  is refused in the app without asking the bridge. The page scrolls to the first
  flagged question, which says "Answer this question to submit.", and the bar
  says "1 question needs your attention". Answers the bridge refuses as invalid
  say "This answer wasn't accepted. Check it and submit again." An accepted
  Submit turns the page read-only, with "Answered" in the bar.
- Dismiss page settles the page as dismissed through `/question/reject`, and
  the bar shows "Dismissed".
- The first submit or dismiss on any surface wins. A page open on another
  surface turns read-only with that surface's own picks and "Answered on
  another device" (or "Dismissed"), and a later Submit there gets the same
  result. A failed submit or dismiss looks the page up again before it shows
  "Couldn't send your answers. Try again." or "Couldn't dismiss the page. Try
  again.", so a page settled meanwhile turns read-only without flashing the
  failure first. An open page also looks itself up again after a reconnect.
- Archiving hides the page's card with the session's other requests, and
  unarchiving brings it back. Submit and dismiss on an archived session's page
  are refused with 409 and send the agent no notice. The page shows the
  failure line and stays open. The page itself still opens, for example from its
  transcript line.
- An accepted Submit adds one Sesori Automation line, "You answered “Title”.",
  to the session that shows the page. A dismissal adds "You closed “Title”
  without answering." Either line shows a chevron, gives press feedback and has
  button semantics, with no extra screen-reader hint. On Android its text can't
  be selected while it is tappable. Tapping the line slides the same page up
  read-only, both live and after a reload, with the user's picks and notes
  filled in and the note row hidden where a note is empty. If the bridge no
  longer has the page, for example because the sub-agent session that sent it
  was deleted, the page reads "This page is no longer available." Apps without
  the reopen tap show the line as plain text.
- Released apps read the `page` kind as unknown. From v1.10.1 they show the
  "MCP request" sheet ("This client cannot complete this MCP request. You can
  cancel it here.") with Cancel request. Apps before v1.10.1 show a plain
  question titled with the page title, with one Cancel option whose description
  says that answering needs an updated app. Either answer dismisses the page.
- Pages live in the bridge database, whether pending, answered or dismissed.
  After a bridge restart or a desktop relaunch, a pending page comes back on
  the card and answering it delivers as usual. An answered page still reopens
  with its images. Deleting a session deletes its pages and their image copies.
- Each Submit or dismiss the bridge confirms reports `question_page_finished`
  once, as described in [analytics](analytics.md#required-behavior).

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated shared presentation and desktop shell coverage: question and permission modals render through the shared session-detail owner, and a pending desktop question opens over its session. A blocked fixture exposes no needs-you card or dialog; changing a loaded state to blocked closes an open dialog without a response. Live plugin, one representative plugin: a permission raised by a real turn appears as pending and one reply lets the turn proceed. |
| L2 Routine | Automated client: blocked question-answer and permission-reply entry points return refusal without remote dispatch. Live plugin, representative: question variants (single, multiple, custom, reject), typed ACP scalar and finite string-choice array forms where supported, unsupported-form decline, abort cancellation, per-session pending listing, repeated or unknown request ids answered without corrupting state. Automated Codex coverage: structured multi-question choices, explicit secret-input refusal, async answers during a turn and after completion, retry after failed submission, child routing, teardown, async acknowledgement omission from history, and `serverRequest/resolved` withdrawal by exact request id with a late reply refused. Automated Pi coverage: select/confirm/input/editor prompt placement, exact replies, and timeout cleanup. Automated DeepSeek coverage: exact two-session question correlation, permission once/reject, ordered multi/custom/free-form and plan-review answers, invalid-answer settlement, old-input → cancel → later-input ordering with reused question IDs and held prompt writes, abort, late reply, and disposal. Automated Claude accepting-edits coverage: the permissions snapshot and `session.edits-auto-accepted` event keep the line in sync, Turn off mid-turn switches the running process to `default`, and a failed switch keeps the grant and brings the line back with an alert. Automated question pages: `pending_page_service_test.dart` (required questions refused in the app, analytics only for confirmed outcomes), `pending_page_cubit_test.dart` (each lookup state, drafts kept across a close, settled elsewhere, a failed submit looking up first, reconnect lookups, images loaded once), `question_page_screen_test.dart` (validation scroll and reason, read-only reasons, the missing page, Done, the slide and the wide overlay), `session_detail_body_test.dart` (no auto-open, Review opens the page), `session_detail_message_list_test.dart` (the reopen tap), and in the bridge `agent_page_repository_test.dart` (first settle wins, cascade on delete) and `page_handlers_test.dart`. |
| L3 Release | Client end to end on each release-target client surface that exposes session detail, every supporting production plugin: every request kind the plugin exposes, per-plugin "always" availability, child attribution, archived-session refusal, and pending requests suppressing completion notifications until resolved. Copilot covers the always-visible Once/Reject actions, Always only when advertised, exact selected-or-cancelled ACP outcomes, and an honestly absent question capability. Grok covers a real ask-mode tool request, Once and Reject plus every advertised scope, exact session/tool correlation, abort cleanup, and no implicit auto-approval. Claude covers Always on a file edit showing the "Accepting edits · Turn off" line on phone and desktop, Turn off during a running turn fading it on both, and the next edit in that turn asking again. Question pages on a headless iOS simulator: a page with text and images arrives and the card grows in without the page opening; open, answer and submit, and the transcript line appears; Submit with a required question unanswered; dismiss, and its line appears; tap the answered line to reopen it read-only with the answers; restart the bridge with a page pending, then answer it. |
| L4 Extended | Client end to end on both product surfaces: disable/restart or invalidate authentication from the other surface while a question or permission dialog is open; no answer is sent, both surfaces converge on read-only, and refreshed pending state returns only after recovery. Relay integration, every supporting production plugin: per-session empty lists while stopped or terminally failed, pending state re-read after restart, competing replies to one request, two logical clients observing one request and its retirement, and reconnect inside the replay window. Question pages: a second surface submits first and the open page shows "Answered on another device"; archive while a page is open, then Submit is refused and no notice arrives; a deleted sub-agent's page shows "This page is no longer available." from its line on the root. |
| L5 Full | Headless bridge and live plugin for malformed requests and degenerate option sets; packaged or external on alternate client platforms for an older bridge not declaring "always". Every supporting production plugin where applicable. Claude accepting-edits compatibility: an older app on a newer bridge shows no line and keeps working, and a newer app on an older bridge shows no line. Question pages on released apps: the v1.14.1 app's "MCP request" sheet and Cancel request dismiss the page, and the Cancel option of an app before v1.10.1 does the same. |

### OMP ACP multi-select focus

For L2, exercise a live OMP `askDialog` through at least one supported client:
each question is one choice with an "Other" option. Select two options plus
"Other" text and confirm `qN` carries the array and `qN__other` the text; answer
a single choice with a listed option and with "Other" text. Also exercise
optional omission, required-field omission/rejection, and cancellation. Mapper, fake-ACP plugin, bridge shared
mapping/serialization, and widget tests cover the constituent paths; they do
not replace this live roundtrip.

## Exploration Guidance

Vary which backend raises the request and how it is provoked, the answer kind,
the answer order when several are outstanding, and whether the answer comes from
the request's own session view, a parent view, or a second client. Vary whether
the session is fresh, resumed after a bridge restart, or reopened cold. Prefer a
different combination than the previous recorded run. For Antigravity, vary an
ordinary permission and `interaction_` question, warning-bearing once/reject
options, persistent options without warnings, duplicate labels/IDs, malformed
answers, two sessions and process cleanup. For Copilot, provoke a
real tool permission, exercise Once and Reject plus Always when surfaced, include
an upstream option set lacking `allow_once` or reject to confirm safe
cancellation, abort with a request pending, and confirm the management/session
capability surfaces do not claim questions. For Grok, provoke permissions from
an ordinary text turn, exercise Once and Reject plus every scope actually
advertised, vary two sessions and tool calls, abort with a request pending, and
repeat after process restart without enabling approval-bypass launch flags.
For DeepSeek, abort with input pending, immediately provoke another question,
and confirm the later request remains answerable. Automated stream fixtures also
exercise reused question IDs and old-input → cancel → later-input ordering while
the prompt write is held, proving cancellation does not remove the later request.

## Failure Signals

- A needs-you card floats at the top of the chat, hides the composer or the
  newest message, or a tap on its body or button fails to open the modal.
- The transcript jumps, glides or closes a gap while an answered, withdrawn or
  interrupted request's sheet leaves, or an interrupted turn's step fold runs at
  the same time as the card's fold.
- A blocked chat shows a needs-you card, opens a response dialog, or accepts a
  late answer/rejection callback. A dialog remains open through the transition,
  closes by answering, clears pending data before either an authoritative
  settlement event or refresh, or reappears before interaction prerequisites
  recover.
- A permission or question reply stalls behind a prompt sent to the same busy
  session instead of the accepted bridge send releasing its session lane
  immediately. For DeepSeek, the underlying `session/prompt` remains pending
  through turn settlement, but ACP server requests and replies continue
  concurrently on the same transport.
- A request never appears, appears under the wrong session, omits options the
  backend actually offered, races ahead of its accepted user message and
  preceding tool card while the prompt frame is still flushing, or surfaces as
  pending after that writing turn was aborted.
- An answer does not reach the backend, arrives with a different scope than the
  user chose, or leaves the turn blocked.
- A permission dialog clips request details, makes decision actions unreachable
  on a small screen or with enlarged text, offers Always when unavailable, or
  treats a passive dismissal as approval/rejection.
- An ACP form answer changes scalar type, uses a display label instead of the
  backend value, reaches the wrong session, or remains pending after abort.
- An ACP array form loses a selected value, encodes only the first selection,
  merges identical custom/option text, changes property order, inserts an
  unanswered optional field, or accepts omission of a required property.
  An OMP scratch connection advertises interactive forms.
- A Pi select, input, or editor dialog leaves its user-facing prompt only in the
  ellipsized sheet heading, or any Pi dialog loses its confirm message, input
  hint, multiline input, or editor guidance; silently retains truncated editor
  prefill; replies with the wrong wire variant; survives timeout/process cleanup;
  or appears outside its imported display root or owning project.
- A DeepSeek question loses supplemental detail, changes answer ordering or
  scope, accepts custom plan-review input, survives abort/process cleanup, or
  an ordered input cancellation clears a later reused-ID question. A Stop that
  clears an earlier request also removes a later admitted request, or a cleared
  permission/question sheet remains actionable.
- A resolved request stays visible, keeps suppressing notifications, or returns
  after reconnect, or one reply is announced twice.
- One failed backend resolution prevents another pending prompt from clearing,
  or a Cursor notification-mapping failure breaks later approval routing.
- Clearing prompts during a transport drop leaves the plugin reporting idle
  instead of unknown work state, so a safe stop proceeds where it should be
  refused.
- A reply routed with the wrong request kind (a question id sent as a
  permission, or the reverse) discards the still-pending prompt instead of
  being rejected, leaving the turn blocked with no clearable prompt.
- A manually routed reply/rejection fails to advance the existing activity
  marker, or an auto-approved permission reply advances it.
- Reading pending state starts an intentionally stopped backend.
- An archived session accepts a reply, or its own pending question or permission
  is still listed.
- A question page opens by itself, shifts content as its images load, or
  accepts a Submit with a required question unanswered. A page answered on
  another surface stays editable, or a second submit sends a second notice.
- An archived session's page accepts answers or sends a notice.
- The transcript line of an answered or closed page ignores a tap, reopens the
  page editable or without its answers, or a missing page gives no reason.
- A released app offers no way to cancel a page, or a pending page is gone after
  a bridge restart.
- Antigravity displays or dispatches a persistent choice, displays any warning-bearing choice, escalates Once, changes
  an opaque option ID, guesses an ambiguous label, or leaves malformed input pending after cancellation/cleanup.
- Copilot offers a question surface or waits for a Sesori answer to an upstream
  `ask_user` interaction that the CLI did not forward over ACP.
- A Grok request is silently approved by launch policy, loses its session or tool
  correlation, maps to an unoffered scope, survives abort/process cleanup, or
  one session's answer resolves another session's request.

## Known Limitations

- "Always" scope is backend defined; some backends persist it only for the
  current session, and some expose it only when the backend offers it.
- No bridge policy auto-answers questions; only permissions can be auto-approved.
- OpenCode v2 hidden/external fields are not rendered, and conditional `when`
  rules are not evaluated by the shared question UI. Numeric fields use text
  entry, not specialized controls. Native required/conditional/external
  validation remains authoritative; a form needing those native interactions
  may need to be completed in OpenCode's own interface. A form with no supported
  visible fields is logged and not presented as an empty answerable card.
- A live OMP 18.19.0 single-choice `askDialog` roundtrip (default, listed
  option, "Other" text, decline) has run on the iOS simulator. OMP multi-select
  has automated mapper/plugin/bridge/widget coverage but no live roundtrip yet;
  that check remains required before claiming complete L2 coverage.
- Plugin scope follows currently registered plugins and their declared
  capabilities, not a fixed list. A plugin that does not expose a request kind
  is not a failure.
- GitHub Copilot CLI currently does not forward `ask_user` over ACP
  (`github/copilot-cli#2109`); only its standard permission requests are in scope.
- Antigravity intentionally omits persistent approvals and independently filters every non-null security-warning
  choice. This is a Sesori safety policy, not a claim that the upstream method or scope is unsupported.
- Grok permission scopes are tool/account dependent. A scope not advertised by
  the live request is absent capability, not failed coverage; Once and Reject
  remain required.
- The shared client models only whether Always is available. Once and Reject stay
  visible even when an unusual ACP request omits their exact option; choosing one
  then cancels safely rather than selecting a broader or different scope.
- Untested Hermes gap (remove this entry once verified): no Hermes permission
  request was ever observed. The tested provider completed file tools without
  emitting an ACP permission request, so once/reject/always handling and
  two-session correlation are unexercised for this harness.

## Sources

- Bridge pending-interaction and archived-validator services; per-plugin
  approval registries; shared pending permission/question and reply models.
- Shared client permission and question surfaces, availability gating and
  auto-dismiss behavior: `client/module_core/lib/src/cubits/session_detail/` and
  `client/module_app_ui/lib/src/features/session_detail/`, composed by
  `client/app/lib/features/session_detail/` and
  `client/desktop/lib/features/sessions/desktop_session_detail_screen.dart`.
- OpenCode v2: `bridge/sesori_plugin_opencode/lib/src/v2/mappers/v2_form_answer_mapper.dart`,
  `bridge/sesori_plugin_opencode/lib/src/v2/mappers/v2_form_answer_validator.dart`,
  `bridge/sesori_plugin_opencode/lib/src/v2/repositories/v2_model_mapper.dart`,
  `bridge/sesori_plugin_opencode/test/v2/v2_form_answer_test.dart`, and
  `bridge/sesori_plugin_opencode/test/v2/v2_service_writes_test.dart`.
- `bridge/sesori_plugin_antigravity/lib/src/services/antigravity_interaction_service.dart`, its mapper/registry tests,
  and the shared ACP pending registry.
- `bridge/sesori_plugin_copilot/lib/src/copilot_plugin_impl.dart`,
  `bridge/sesori_plugin_grok/`, and the shared ACP approval registry.
- ACP array ownership and focused tests:
  `bridge/sesori_plugin_acp/lib/src/repositories/mappers/acp_elicitation_mapper.dart`,
  `bridge/sesori_plugin_acp/test/acp_elicitation_test.dart`,
  `bridge/sesori_plugin_omp/test/omp_plugin_test.dart`,
  `bridge/app/test/bridge/repositories/question_repository_test.dart`, and
  `client/module_app_ui/test/features/session_detail/widgets/question_modal_test.dart`.
- Question pages: `AgentPageService`, `AgentPageRepository` and
  `lookup_page_handler.dart`/`submit_page_handler.dart` under `bridge/app/lib/src/`;
  `PendingPageService` and `PendingPageCubit` in `client/module_core`; and
  `client/module_app_ui/lib/src/features/session_detail/question_page/`.
- Owning tests for pending interaction, reply routes, and pending state without
  a started backend.
