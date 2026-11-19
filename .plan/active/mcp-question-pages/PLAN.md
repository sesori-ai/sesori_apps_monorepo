# Agents ask the user through Sesori pages (MCP question pages)

Status: active. Based on origin/main `3a9f8d9300`, 2026-11-18.
Product version 1.14.2 (bridge and client). The current public release is v1.14.1.

## Goal

An agent in any Sesori session calls a new `sesori_bridge` tool, `send_page`, and
the user gets a page in the Sesori app on whichever device they pick up. The page
carries Markdown text, images, informative sections and questions with native
option and note controls. A real Submit sends the answers back into the session as
a Sesori notice. While a page is unanswered, the session shows as needing the
user, exactly like a pending harness question. Pages survive a bridge restart,
and an answered page can be reopened read-only from its line in the chat.

Presentation is mostly standardized but flexible. The agent composes sections,
headings, Markdown bodies, images and questions; the app owns layout and style.
Requests don't block: the tool returns at once, there is no cap on pages per
session, and pages are not serialized.

## Decisions

### Product (user, 2026-11-18)

1. **Where the page opens:** full screen, sliding up over the session like file
   previews, with a sticky Submit bar, and sliding down to close. Desktop shows it
   as a wide overlay.
2. **Arrival:** only the needs-you card grows in above the composer. The page
   never opens by itself.
3. **After Submit:** the chat shows one Sesori Automation line, "You answered
   “Title”.". Tapping it reopens that page full screen with the same slide-up,
   read-only, with the user's picks and notes filled in. A dismissed page's line
   ("You closed “Title” without answering.") reopens the same way. Older apps
   show the line without a tap. If the page no longer exists, the tap answers
   with a short reason; a tap is never ignored.
4. **Needs-you card:** the generic wording and strings, "1 request · Title ·
   Review", unchanged. No page-specific label.
5. **Analytics:** one bounded event on a confirmed submit or dismiss.
6. **Persistence across a bridge restart is in phase 1**, in its own PR. Pages
   can wait for days, and relaunching the desktop app restarts its bridge. The
   read-only reopen also depends on it.

### Engineering

1. **Reuse the pending-question pipeline with a new kind,
   `QuestionInteractionKind.page`.** The kind travels as a marker
   `PendingQuestion`, exactly as MCP forms and external actions do. The page
   content travels on its own request-scoped routes. See
   **Reuse versus new kind**.
2. **The bridge keeps pages in a Drift table**, `agent_pages`, holding pending,
   answered and dismissed pages. Rows cascade with the session row.
3. **Images are copied when the page is sent** into a page-images root. The root
   is a `PromptUploadRepository` instance, as the transcripts root is. It is not
   swept by age, and it is deleted with the session. Images are served through
   the existing `POST /filesystem/file` image outcome, so there is no new image
   route and no cache.
4. **No web view and no JavaScript in phase 1.** Markdown renders natively, with
   no inline images and no network loads.
5. **The first submit wins.** Settling is a conditional update
   (`WHERE status = pending`), so later surfaces get `alreadySettled`.
6. **The answer arrives as a Sesori notice** through `SessionNoticeService`. It
   goes to the root (display) session, as approval outcomes do.
7. **The notice frame carries an optional page reference.** The bridge reads it
   back from the transcript into an optional reference on the shared text part,
   so the reopen tap works both live and after a reload. Old apps ignore the
   field.
   - The lighter-looking alternative was a sheet of answers built from the
     notice. It would still need the answers on the wire, plus a second answer
     view.
   - The reopen reuses the read-only page screen, and persistence (product
     decision 6) already provides the answered rows.
8. **The rule that a scheduled run's session hears notices after its turn moves
   into `SessionNoticeService`.** The page service and the scheduled-task service
   then share it instead of each picking a timing.
9. **`send_page` advertises `readOnlyHint: true`.** It changes nothing on the
   user's machine apart from copying images into Sesori's own folder. Copilot
   then doesn't ask the user twice, once to allow the call and again on the page.

## Current behaviour

- **MCP server.**
  - `SesoriMcpServer` is a loopback endpoint with a 1 MiB request cap
    (`maxRequestBytes`).
  - `SesoriMcpRequestDispatcher`
    (`bridge/app/lib/src/routing/sesori_mcp/sesori_mcp_request_dispatcher.dart`)
    is a hand-written JSON-RPC handler. Its `initialize` instructions (:116–120)
    say the tools are for scheduled tasks.
  - Tools live in the `SesoriMcpTool` enum (`sesori_mcp_tool.dart`): wire name,
    description, `readOnly` and input schema. Their arguments are Freezed models
    in `models/sesori_mcp_tool_arguments.dart`.
  - Results are text only. An `isError` result reports a failure the agent can
    fix.
- **Approvals, the model to mirror.**
  - `AgentApprovalRepository`
    (`bridge/app/lib/src/repositories/agent_approval_repository.dart`) keeps an
    in-memory map keyed `sesori-approval-<random>` and an events stream (asked,
    settled). `take({requestId, reply})` settles a request once.
  - The orchestrator maps those events to `permissionAsked` and
    `permissionReplied` in `_deliverAgentApprovalEvent` (`orchestrator.dart:2281`,
    wired at :1459–1482), then rebuilds the projects summary.
  - `agent_approval_mapper.dart` builds the wire shape.
  - `ReplyToPermissionHandler` returns `NotAgentApproval` for plugin requests and
    falls through to the plugin.
- **Needs-you overlay.** `SessionRepository.markAwaitingInput({projects,
  rootSessionIds})` (`session_repository.dart:1512`) is generic and skips
  archived rows. Its only caller is
  `ScheduledTaskAgentService.markAwaitingApproval` (:260), reached from the async
  `Orchestrator._buildProjectsSummary` (:2365–2374).
- **Notices.**
  - `SessionNoticeService.deliver({sessionId, notice, timing})` never throws and
    skips archived or deleted sessions. It is built inline as an argument to
    `ScheduledTaskAgentService` (`orchestrator.dart:835`).
  - The frame comes from `buildSessionNotice({summary, guidance})` and is read
    back by `parseSessionNotice({text})`
    (`bridge/sesori_bridge_foundation/lib/src/system_context.dart:71–96`):
    `[SESORI NOTICE]\n…\n[FOR THE AGENT]\n…\n[END SESORI NOTICE]`.
  - The bridge turns a notice prompt into a `MessageSender.sesori` row whose text
    part holds only the summary. It does this on reload
    (`plugin_message_mapper.dart:95–140`, `withoutNoticeFrame`) and live
    (`orchestrator.dart:2142`).
  - The client shows the row as a "Sesori Automation" card
    (`system_message_card.dart`).
  - `ScheduledTaskAgentService.settle` (:231–251) picks `afterTurn` for a
    scheduled run's session and `intoRunningTurn` otherwise. It targets
    `displaySessionId ?? sessionId`.
- **Question pipeline wire.**
  - Model: `PendingQuestion{id, sessionID, displaySessionId, questions,
    interactionKind}` and `QuestionInteractionKind {question, form,
    externalAction, unknown}`, with `unknownEnumValue: unknown` and
    `@Default(question)`.
  - Routes: `POST /session/questions`, `/question/reply` and `/question/reject`.
  - SSE: `questionAsked`, `questionReplied` and `questionRejected`.
  - `GetSessionQuestionsHandler` reads only `QuestionRepository`. The archive
    filter (`pending_interaction_support.dart:88`) covers plugin questions only.
- **Typed-kind precedent.** MCP forms put a marker `PendingQuestion`
  (`interactionKind: form`) into the question pipeline. They carry their content
  on `POST /session/forms`, `/form/reply` and `/form/decline`, with a sealed
  `FormReplyResult` whose fallback is `unknown`. Legacy question routes can only
  cancel a form.
- **Released-app fallback.**
  - Since v1.10.1, any kind the app doesn't handle shows as an "MCP request"
    sheet with "This client cannot complete this MCP request." and "Cancel
    request" (`question_modal.dart:321–349`).
  - The needs-you card shows "1 request", the marker's first question, and
    "Review" (`session_detail_loaded_view.dart:151–170`).
  - Apps before v1.10.1 render the marker's `QuestionInfo` as a plain question.
- **Wire unions.** `MessagePart` (`message_part.dart:95`) has no fallback union.
  A new part type would break released apps, so the reference goes on the
  existing text part as an optional field.
- **Client arrival.**
  - Questions open by themselves when they arrive (`session_detail_body.dart:285`).
  - Typed kinds dispatch at :1329 (form) and :1358 (external action).
  - Each shell builds `PendingFormCubit` from `getIt`
    (`app/.../session_detail_screen.dart:156`,
    `desktop/.../desktop_session_detail_screen.dart:99`).
- **Push.** "Question requires input", with the first question as the body
  (`push_notification_content_builder.dart:39–45`).
- **Media.**
  - `POST /filesystem/file` → `FilesystemRepository.readPreviewFile` (:194)
    serves any absolute path to the user's own devices. png, jpg, gif and webp
    images up to 20 MiB come back as `FilePreviewImage`, deflated and
    E2E-encrypted.
  - `PromptUploadRepository` (`save`, `deleteSessions`) has two instances
    (`orchestrator.dart:392–402`). Uploads are swept after 30 days; transcripts
    are never swept. `SessionDeletionService` (:79, :89) deletes both roots'
    session folders.
  - `AttachmentThumbnailBuilder.detectSupportedMime({bytes})` sniffs image
    types and already decodes image headers.
- **Database.** `AppDatabase` is at schema 30 (`api/database/database.dart:58`).
  Per-session tables cascade with `SessionTable`
  (`session_interruptions_table.dart:11`, `side_chat_exchanges_table.dart:18`).
- **Markdown in chat.** `flutter_markdown_plus`, whose `MarkdownMessageImage`
  loads http(s), resource and data URIs. Pages must not reuse that image builder.
- **Harness injection** (`docs/HARNESS_CAPABILITIES.md:172`, "Sesori agent
  tools").
  - Injected: Claude Code, Codex, Pi, Oh My Pi, Grok, GitHub Copilot.
  - Off or unverified: Antigravity, Hermes, Cursor.
  - Unsupported: DeepSeek. OpenCode has no per-session seam.

## Reuse versus new kind

**Chosen: a new `QuestionInteractionKind.page` that rides the existing
pending-question pipeline as a marker. Page content, submit and lookup go on
their own typed routes.**

What the pipeline already gives, to new and released apps alike:

- the needs-you card, whose wording product decision 4 keeps;
- the list's awaiting state and the session lane;
- push, and suppression of the completion push;
- retirement on every surface through `questionReplied` and `questionRejected`;
- the modal scheduler.

Older apps degrade honestly:

- Released apps from v1.10.1 show the "cannot complete" sheet with "Cancel
  request", with no new code.
- Apps before v1.10.1 show a plain question with one Cancel option.
- Cancelling dismisses the page either way, and the agent hears that the user
  closed it without answering.

Rejected:

- **Plain `interactionKind.question`.** `QuestionInfo` can't carry images,
  sections or Markdown option bodies. Extending it would burden every harness
  question, and keeping a degraded duplicate is permanent compatibility
  machinery.
- **A wholly separate kind with its own SSE and list state.** It duplicates the
  pipeline, and released apps would show a session needing the user with nothing
  to answer.

## Proposed design

### Page schema (what the agent sends)

```
send_page {
  title,                         // ≤ 200 chars
  intro?,                        // Markdown
  sections: [{
    heading?, body?,             // body is Markdown
    images?: [{ path, caption? }],
    questions?: [{
      id, title, body?, images?,
      kind: single | multiple | text,
      options?: [{ id, label, description?, image?, recommended?: bool }],
      required?: bool            // default false
    }]
  }]
}
```

- Every question gets a note field, and the page ends with an "Anything else?"
  note.
- A page with no questions is allowed. It is informative, and Submit reads
  "Done".
- Caps: a 200-character title, 20 images, 50 questions, and 12 options per
  question. The whole call stays within the 1 MiB MCP body. There is no cap on
  pages per session.
- Parsing is strict: Freezed models and `additionalProperties: false`.
  Question ids must be unique within a page and option ids within their
  question, since an answer names both. A violation returns an `isError` result
  that names the field.
- `recommended` shows a small label and is never preselected.

### Wire (shared)

- **Kind.** `QuestionInteractionKind.page`. Released apps parse it as `unknown`.
- **Page.** `PendingPage{id, sessionId, displaySessionId?, title, intro?,
  sections}`, built from `PageSection`, `PageQuestion`, `PageOption` and
  `PageImage{path, width, height, caption?}`. `path` points at the bridge's
  copy. `PageQuestion{id, title, body?, images, kind, isRequired}` carries a
  sealed `PageQuestionKind`: `single{options}`, `multiple{options}`, `text`, or
  the fallback `unknown`, so only choice questions hold options.
- **Submit.** `POST /page/submit` takes `SubmitPageRequest{requestId, sessionId,
  answers: List<PageAnswer{questionId, value?, note?}>, note?}`. The sealed
  `PageAnswerValue` is `choice{optionId}`, `choices{optionIds}`, `text{text}`,
  or the fallback `unknown`; a null value with a note is a note-only answer. It
  returns the sealed `PageSubmitResult`: `accepted`, `alreadySettled`,
  `invalid{questionIds}`, or the fallback `unknown`.
- **Lookup.** `POST /page {sessionId, requestId}` returns the sealed
  `PageLookupResponse`: `pending{page}`, `answered{page, answers, note?}`,
  `dismissed{page}`, `missing`, or the fallback `unknown`. It is the only route
  that opens a page, editable or read-only. It matches on `requestId` with
  `sessionId` equal to either the page's `session_id` or its `root_session_id`,
  because the notice row sits on the root session while a sub-agent's page
  stores the sub-agent's session. It ignores archive state; the archive refusal
  on submit and dismiss is the single gate.
- **Dismiss.** It reuses `/question/reject`. If an older app replies on
  `/question/reply` with a page id, the page is dismissed ("legacy routes only
  cancel").
- **Notice reference.** `MessagePartText` gains `String? noticePageRequestId`.
  Nullable is honest, since almost every text part has no reference. A future
  reference kind would be another optional key. Released apps ignore the key,
  and new apps on old bridges never receive it.
- **Marker.** `QuestionInfo(header: title, question: title, options: [Cancel],
  multiple: false, custom: false)`. The Cancel option's description says that
  answering needs an updated Sesori app and that cancelling tells the agent you
  didn't answer. Ids take the form `sesori-page-<random>`. The marker carries:
  `// COMPATIBILITY 2026-11-18 (v1.14.2): apps before v1.10.1 render this marker as a plain question, so it offers one Cancel option. Remove the option once no supported app predates v1.10.1.`

### Bridge

- **Persistence.** The `agent_pages` Drift table moves the schema from 30 to 31
  through a generated migration step.
  - Columns: `id` (primary key), `session_id` (referencing `SessionTable` with
    `onDelete: cascade`), `root_session_id`, `page_json` (the `PendingPage`,
    through a converter), `status` (an enum of `pending`, `answered` and
    `dismissed`), `outcome_json?` (the `AgentPageOutcome`: answers and note, or
    dismissed), `created_at` and `settled_at?`. There is no
    `display_session_id` column: it is `page_json`'s, and `root_session_id`
    already holds `displaySessionId ?? sessionId`.
  - An index on (`status`, `root_session_id`), so the awaiting-roots query
    seeks on `status`.
  - `AgentPagesDao` owns the queries.
- **`AgentPageRepository`** (new) depends on `AgentPagesDao` and owns the events
  stream: `AgentPageAsked{page}` and `AgentPageSettled{page, outcome}`, whose
  outcome is answered or dismissed.
  - `add`, which mints the `sesori-page-<random>` id, as the approval
    repository does, and returns the `PendingPage`.
  - `pendingPages({sessionId})`.
  - `find({id})`: the stored page with its status and answers.
  - `settle({id, outcome})`: a conditional update. It returns the settled page,
    or null when the page was already settled, and only the winner emits an
    event.
  - `awaitingRootSessionIds()`: one indexed query.
- **Page images.** A third `PromptUploadRepository` instance sits at a new
  `sesoriPageImagesDirectory()`. It is not swept, and `SessionDeletionService`
  deletes its session folders too.
- **`repositories/mappers/agent_page_mapper.dart`** builds the marker
  `PendingQuestion` from a `PendingPage`, as `agent_approval_mapper.dart` does.
- **`AgentPageService`** (new). It takes `AgentPageRepository`,
  `SessionRepository`, `FilesystemRepository`, the page-images
  `PromptUploadRepository`, `AttachmentThumbnailBuilder`,
  `ArchivedSessionValidator`, `SessionNoticeService` and
  `AgentPageAnswerNoticeBuilder`.
  - **`send`**:
    1. Resolves the caller's family root through
       `SessionRepository.resolveSessionFamily`, as `_propose` does, and checks
       the caps.
    2. Reads each image through a new
       `FilesystemRepository.readImageFile({absolutePath})`. It returns a typed
       outcome (bytes and mime, or missing, denied, too large or unsupported) and
       shares its classification with `readPreviewFile`.
    3. Enforces 20 MiB per image and 50 MiB per page.
    4. Reads dimensions with a new
       `AttachmentThumbnailBuilder.readDimensions({bytes})`.
    5. Copies the bytes into the page-images root and adds the page.
  - **`pendingQuestions({sessionId})`** leaves out archived sessions, so an
    archived session shows no marker.
  - **`lookup({sessionId, requestId})`** opens every page, pending or settled,
    with the session scoping described under Wire.
  - **`submit`**:
    1. Refuses archived sessions through `ArchivedSessionValidator`.
    2. Validates required questions and option ids.
    3. Settles as `answered`.
    4. Delivers the answer notice without awaiting it.
  - **`dismiss`** runs the same archive check, settles as `dismissed`, and
    delivers the dismissal notice.
  - **No session lane.** The conditional update is atomic, and pages touch no
    plugin state that the lane orders.
  - **Interception.** Reply and reject interception returns a sealed result
    (`NotAgentPage`, `AgentPageReplyDismissed` or `AgentPageAlreadySettled`),
    mirroring `NotAgentApproval`. `AgentPageDismissed` is already the
    repository's outcome variant. `AgentPageAlreadySettled` answers 404 "no
    longer pending", the existing contract for a request answered elsewhere, so
    only the dismiss that wins succeeds and the client never counts a false
    dismiss.
- **`AgentPageAnswerNoticeBuilder`** (new and pure) builds both notices.
  - **Answer notice.** The summary is "You answered “Title”.". The guidance
    carries everything in full: question ids and titles, chosen option ids and
    labels, text answers, notes and the "Anything else" note, all marked as the
    user's own words. It names the sub-agent session when a sub-agent asked, and
    asks for a one-line acknowledgement (for Grok).
  - **Dismissal notice.** The summary is "You closed “Title” without
    answering.", and the guidance says not to resend unless the user asks.
- **Frame reference.**
  - `SessionNotice` (`repositories/models/session_notice.dart:4`) gains
    `String? pageRequestId`. `AgentPageAnswerNoticeBuilder` sets it, and
    `SessionNoticeService.deliver` passes it on to `buildSessionNotice`.
  - `buildSessionNotice` writes the reference at a fixed position: the first
    line after `[FOR THE AGENT]`.
  - `parseSessionNotice` in `sesori_bridge_foundation` returns a
    foundation-local record, `({String summary, String? pageRequestId})`, so
    foundation still doesn't depend on `sesori_shared`.
  - It reads the reference only at that fixed position. The guidance embeds the
    user's free-text notes, so scanning the whole agent part could match a
    spoofed line.
  - Frames without the line parse as before.
  - `withoutNoticeFrame` becomes an extension on the shared `MessagePart` in
    `plugin_message_mapper.dart`. It returns
    `MessagePartText.copyWith(text: summary, noticePageRequestId: …)`, applied
    after `toShared` on reload (:101) and after `_mapper.mapMessagePart` live
    (`orchestrator.dart:2142–2144`). The guard at :97 adapts to the record. The
    reference never touches the plugin interface.
- **MCP tool `send_page`.** It joins the enum with Freezed arguments and
  `readOnly: true`, and returns at once with "Sent “Title” to the user. Sesori
  will message this session with their answer." The server instructions and
  tool descriptions widen to "scheduled tasks and asking the user".
- **Orchestrator.**
  - `_deliverAgentApprovalEvent` becomes `_deliverAgentRequestEvent`, which also
    maps page events to `questionAsked`, `questionReplied` and
    `questionRejected`.
  - `_buildProjectsSummary` combines approval and page root ids into one
    `markAwaitingInput` call, and `markAwaitingApproval` goes.
  - One `SessionNoticeService` is built and passed to both services.
- **Handlers.**
  - `GetSessionQuestionsHandler` gains `AgentPageService` and merges its
    filtered markers.
  - Reply and reject intercept page ids through the sealed result and fall
    through to the plugin on `NotAgentPage`.
  - New handlers serve `/page/submit` and `/page`.
- **Notice timing.** `SessionNoticeService` takes `ScheduledTaskRepository` and
  picks `afterTurn` for a scheduled run's session itself.
  - `deliver` loses its `timing` parameter, and `ScheduledTaskAgentService`
    loses `isRun`.
  - `ScheduledTaskAgentService` keeps `_taskRepository` for `_ownTaskId`.
  - `SessionNoticeTiming` becomes private.
- **Logging.** Ids and outcomes only, never content or answers.

### Client

- **module_core.**
  - **API and repository.** `SessionApi` and the existing client
    `SessionRepository` (beside the form methods, `session_repository.dart:280`)
    gain `lookupPage` and `submitPage`.
  - **`PendingPageService`** is stateless, like `PendingFormService`. It looks
    up, validates and submits, and it dismisses through the existing question
    reject. It depends on `SessionRepository` and `ProductAnalyticsService`,
    and sends the analytics event when it sees the authoritative `accepted` or a
    confirmed dismissal.
  - **`PageDraftRepository`** (new, in memory) keeps drafts keyed by request id
    (`get`, `save`, `remove`).
  - **`PendingPageCubit`** depends on `PendingPageService`,
    `PageDraftRepository`, `FilePreviewRepository` (for image bytes) and
    `ConnectionService`.
    - It opens every page through the lookup. `pending` opens for editing;
      `answered` and `dismissed` open read-only; `missing` shows the reason.
      Its factory takes `({requestId, sessionId})`, like
      `PendingFormCubitFactory`.
    - States: loading, editing, submitting, read-only, missing and failure.
      Read-only covers an answered or dismissed page, a page answered on another
      device, and a page this surface just submitted.
    - It removes the draft when the page settles: on its own submit result, or
      on `questionReplied` or `questionRejected` for that id.
  - **Analytics** follow the add-analytics checklist.
    - The event is a closed model in `foundation/models/product_analytics/`,
      sent by `PendingPageService` through `ProductAnalyticsService`.
    - Parameters: the outcome (answered or dismissed), a question-count bucket
      (0, 1, 2–5, 6+) and `has_images`.
    - No ids, titles or content.
    - **Release gate.** The app release that ships question pages waits until
      the `question_page_finished` warehouse rollout is done: sesori_auth_server#122
      is deployed (merged 778fc4b079), the BigQuery apply with
      `--apply-schedules` has run, the export image is rolled, the manual export
      and assertions have passed, and the SOPS record is updated. A desktop
      client that sends the event between the #122 deploy and the image roll
      blocks the whole auth export.
- **module_app_ui.**
  - **The page screen** slides up over the session, using the file-preview
    `PageRouteBuilder` pattern (easeOutCubic in, easeInCubic out). Desktop shows
    it as a wide overlay. It is built from section, question, option and image
    widgets.
    - Options reuse the question sheet's styling: a clearable radio for single
      choice, checkboxes for multiple choice.
    - Markdown uses the chat styles, with an image builder that renders nothing.
    - A sticky bar shows "n of N answered" and Submit. A required question left
      unanswered is scrolled to with the reason, and unanswered optional
      questions are sent as "no answer".
    - The top bar's menu holds "Dismiss page".
    - The app chrome names the agent's session as the source, and page content
      can't draw over it.
  - **Read-only mode** is the same screen with the picks and notes filled in and
    the controls disabled. In place of Submit, the bar shows "Answered",
    "Answered on another device" or "Dismissed".
  - **Images.** Each image keeps a box at its declared aspect ratio, shows a
    shimmer, then cross-fades in, so nothing below it jumps. Tapping opens the
    existing image viewer. A failed load shows a neutral placeholder that keeps
    the box.
  - **Dispatch.** `session_detail_body.dart` adds the page kind beside form and
    external action. It doesn't open by itself: arrival only grows the needs-you
    card, whose "Review" opens the page. The card is unchanged.
  - **Reopen.**
    - `session_detail_message_list.dart` (:1869–1882) reads
      `noticePageRequestId` from the `MessageWithParts` and passes an optional
      `onTap` to `SystemMessageCard`.
    - The tap calls a page opener from `SessionDetailPresentationScope`, and the
      page screen slides up at once. The cubit's lookup decides the mode.
    - A `missing` result renders on the screen as a short reason ("This page is
      no longer available."), so the tap always gets an answer. The card itself
      fetches nothing.
  - **Shells.** Each one provides a `PendingPageCubit` factory through
    `SessionDetailPresentationScope` from `getIt`, as it does
    `PendingFormCubitFactory`.

## Security

- Page content is untrusted text from the agent. Phase 1 renders it natively,
  with no web view, no JS, and no network or data-URI images. Images come only
  from the declared `images` fields.
- Links open only when the user taps them, through the existing link handlers.
- Page content can't reach the relay, tokens or other routes. Native widgets
  render it as data.
- Image reads expose nothing new. `/filesystem/file` already serves any absolute
  path to the user's paired devices, and the agent can read those files anyway.
  Only sniffed images are copied, and the copies are owner-only.
- Arguments parse strictly, size caps apply, and logs carry no content.
- The persisted row keeps page text and answers in the bridge's existing local
  database, with the same protection as session rows.

## Media

- png, jpg, gif and webp, sniffed rather than trusted by extension. Limits are
  20 MiB per image and 50 MiB per page.
- Copies live in the page-images root for the session's lifetime, so a page
  answered weeks ago still reopens with its images.
- Images load through the encrypted relay via the existing `/filesystem/file`
  image outcome.
- Video waits for a later phase. It needs a streaming or ranged route, since a
  relay frame caps at 64 MiB.

## Multiple surfaces

- Every surface receives `questionAsked` and can open the page.
- The conditional settle means the first submit or dismiss wins. Later surfaces
  get `alreadySettled`, and an open page turns read-only with "Answered on
  another device".
- Drafts are per surface, in memory and not synced.

## Lifecycle

- **Archive.** The service filter hides the marker, and unarchiving restores it.
  Submit and dismiss are refused with the archived rejection and send no notice.
  The lookup still opens the page.
- **Delete.** Rows cascade with the session row, and `SessionDeletionService`
  deletes the session's image folder.
- **Bridge restart or desktop relaunch.** Pending pages reload from the database
  and come back as markers, and answering after a restart delivers as usual.
  A page open on a client repeats its lookup when the client reconnects.
- **Bridge auto-update.** It installs in place and runs the new code from the
  next start.

## Harness parity

- Injected harnesses get the tool through the existing injection: Claude Code,
  Codex, Pi, Oh My Pi, Grok and GitHub Copilot. No harness needs its own code.
- The gaps follow the "Sesori agent tools" row:
  - Antigravity, Hermes and Cursor are off or unverified.
  - DeepSeek is unsupported.
  - OpenCode has no per-session seam.
- `docs/HARNESS_CAPABILITIES.md` gets a "Question pages" line in the same
  pattern, including answer timing: harnesses that can be steered mid-turn get
  the answer during the turn, and harnesses that have to stop the turn get it
  afterwards.
- A live check per injected harness confirms that a large nested `send_page`
  call is accepted and that the answer notice arrives.

## Token cost

- About 400 tokens of tool description in every injected session.
- The answer notice grows with the answers, at one compact line per question.
  The reference line costs a few tokens.

## Complexity budget

New state:

- the `agent_pages` table and the repository's events stream;
- the client draft map.

Deliberately not added:

- an in-memory page cache;
- a new image route or image cache;
- any code specific to one harness;
- a cap on the number of pages;
- a web view;
- synced drafts;
- a new `MessagePart` type.

## Cleanup assessment

- Remove `ScheduledTaskAgentService.markAwaitingApproval`.
- Remove `deliver`'s `timing` parameter and `isRun`. Make `SessionNoticeTiming`
  (`repositories/models/session_notice.dart:7`) private, and share one
  `SessionNoticeService`.
- Rename `_deliverAgentApprovalEvent` to `_deliverAgentRequestEvent` and
  generalise it.
- Reword the MCP server instructions and the `_answerFollows` text so they go
  beyond scheduled tasks.

## PR breakdown

Slug `mcp-question-pages`, with a durable plan in `.plan/active/`. Sizes count
authored lines, with generated lines listed separately.

| Step | PR | Size | After | Status |
|---|---|---|---|---|
| 1/10 | 🌱 Raise the plan | ~450 docs | — | In PR |
| 2/10 | 🌿 Shared wire: `page` kind, page DTOs, submit and lookup requests and results, `MessagePartText.noticePageRequestId`, JSON tests | ~280 + ~1,200 generated | 1 | In PR #2813 |
| 3/10 | ⚙️ Bridge page store: `agent_pages` table, migration 30→31, DAO, `AgentPageRepository`, page-images root and deletion, tests | ~450 + ~1,200 generated | 2 | In PR #2814 |
| 4/10 | 🚧 Bridge send path: `AgentPageService.send` (image reads, dimensions, copies), `send_page`, marker mapper, questions-list merge with archive filter, reply/reject interception plus dismissal notice, SSE mapping, needs-you union, notice-timing move, sesori-mcp.md, HARNESS_CAPABILITIES | ~900–1,100 | 3 | In PR #2816 |
| 5/10 | ⚙️ Bridge answers: lookup and submit routes, answer notice builder, `SessionNotice.pageRequestId`, fixed-position frame reference, parse into the shared text part on both strip paths, archive refusal, tests | ~550–750 | 4 | In PR #2817 |
| 6/10 | ⚙️ Client core: API, repository methods, `PendingPageService`, `PageDraftRepository`, `PendingPageCubit` (editing and read-only), analytics event, tests | ~700–900 | 2 | In PR #2815 |
| 7/10 | 🚧 Client page screen: screen and widgets, image boxes, read-only mode, dispatch from the needs-you card, both shells, ARB, widget tests, fixture visuals and recording | ~1,000–1,300 | 6 | Planned |
| 8/10 | 🌿 Client reopen: tappable Sesori card with a page reference, lookup, missing-page reason, tests, visuals | ~250–400 | 7 | Planned |
| 9/10 | 🌱 Regression docs reconcile: questions-and-permissions, sesori-mcp, file-previews if touched | ~150 | 5, 8 | Planned |
| 10/10 | Headless iOS simulator and live-harness verification, then retire the plan | docs | 9 | Planned |

After step 2, the bridge steps (3 to 5) and the client steps (6 to 8) run in
parallel, since they touch disjoint packages. The feature only becomes usable
once steps 5 and 8 have merged. Until then the code ships unused, all within one
release.

## Risks

- **Large nested schemas.** A harness may flatten or reject deep MCP argument
  objects. The step 4 live check covers each harness, and the schema nests at
  most two levels below sections.
- **Notice-timing move.** A scheduled run's session must still hear approval
  outcomes after its turn. The existing tests stay, moved with the rule.
- **Session row foreign key.** The cascade needs a `SessionTable` row for the
  calling session. `send` resolves the family first, and
  `resolveSessionFamily` throws `notFound` when the row is missing
  (`session_repository.dart:183–188`). `send` then fails with an `isError`
  result.
- **Frame-reference parsing.** Frames written before step 5 have no reference
  line and must still parse. Tests cover both shapes.
- **Released-app fallback.** Check the marker once against v1.14.1.
- **Feel.** Images must not shift content, the needs-you card must glide in, and
  the read-only reopen must slide in like the editable page. Record arrival,
  open, answer, submit and reopen.

## Verification

- Each PR runs the relevant tests and analyzes the packages it touches.
- Device checks run only on a headless iOS simulator: `xcrun simctl boot` on the
  slot `sesori-local-testing` assigns, never Simulator.app. Matrix:
  - a page with text and images arrives, and the card grows in; then open,
    answer and submit, and the notice line appears;
  - Submit with a required question unanswered;
  - dismiss, and the dismissal line appears;
  - tapping the answered line reopens the page read-only with the answers;
  - a second simulator submits first, and this one shows "Answered on another
    device";
  - archive while a page is open;
  - restart the bridge with a page pending, then answer it;
  - a deleted session's reference shows the missing-page reason;
  - the v1.14.1 app's fallback sheet and Cancel.
- Live `send_page` checks on Claude Code, Codex, Pi, Oh My Pi, Grok and GitHub
  Copilot run through the local proxy, with an isolated HOME and config and
  auto-update off.

## Later phases (rough intent only)

- **Sandboxed HTML blocks**, where native sections fall short. They need a CSP of
  `default-src 'none'`, `data:` images only, no navigation, no JS channels and a
  non-persistent store, which is stricter than today's file-preview HTML.
- **Video**, through a streaming or ranged media route.
- **A richer style set:** callouts, columns or grids, collapsible sections, and
  theme colour tokens.
- **Open:** whether custom HTML questions may return their own values.

## Architecture plan review

**Round 1 (2026-11-18):** rejected on five clarifications, with no design flaw.

- Confirmed: the notice-timing move into `SessionNoticeService`, the split
  between repository and service, the marker in the question pipeline, the
  needs-you union, `_deliverAgentRequestEvent`, and push reuse.
- Applied: an archive filter in the service covering both markers and content;
  settling with an outcome, with an archive check on both submit and dismiss;
  drafts moved to `PageDraftRepository`; named client collaborators; a listed
  bridge constructor; typed image reads; one shared notice service.

**Round 2 (2026-11-18, persistence and reopen):** rejected on six findings,
with no design flaw.

- Confirmed: the DAO → repository → service layering, the cascade, the
  conditional settle, the third upload root, a nullable field on the text part,
  and the client module placement.
- Applied without re-review:
  - The reference now maps on the shared part in the bridge mapper, through a
    foundation-local parse record, `SessionNotice.pageRequestId`, and a parse
    at a fixed position only.
  - `String? noticePageRequestId` replaces the single-variant union.
  - `/session/pages` is dropped. The lookup opens every page, with the
    session/root scoping spelled out.
  - The reopen path is specified, through the message list and the
    presentation scope, and the card fetches nothing.
  - Analytics are owned by `PendingPageService`.
  - The upsert alternative is removed: a missing row fails `send`.
