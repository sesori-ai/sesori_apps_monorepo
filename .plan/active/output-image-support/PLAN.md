# Output Image Support

## Status

- **Plan slug:** `output-image-support`
- **Status:** Step 1/13 plan PR open
- **Plan date:** 2026-07-31
- **Plan delivery:** this document, `TRACKER.md`, and the durable Plan Maker
  delivery rules are Step 1/13
- **Implementation base:** `origin/main` at
  `9d2c1e9e79ab80fa8824b9d803a74798eb71140d`
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Delivery:** one planning PR, eleven sequential independently valid
  bridge-plugin PRs, and one plan-retirement PR

## Goal

Display safe, bounded output images from Codex and standards-compliant ACP
agents in the existing Sesori message UI, both while a turn is live and after
history is reloaded.

The implementation covers:

- Codex first-class `imageGeneration` items;
- image content returned by Codex MCP and dynamic tools;
- persisted Codex image-generation and tool-output records;
- standard ACP image `ContentBlock`s in assistant message chunks;
- standard ACP image content in tool calls and tool-call updates; and
- ACP `session/load` replay of the same assistant and tool images.

Cursor's proprietary `cursor/generate_image` path-only extension remains out of
scope. Cursor inherits the generic ACP behavior only when it emits standard ACP
image content.

## Success Criteria

1. A completed Codex first-class image generation renders its inline PNG live
   and after history reload, using the same message and part identity.
2. Inline images returned by Codex MCP/dynamic tools render as attachments on
   their existing tool cards without losing text, error, title, or status.
3. A standard ACP assistant stream preserves `text -> image -> text` order live
   and after `session/load` replay.
4. ACP tool updates obey the protocol's collection-replacement semantics:
   omitted content preserves prior content, while present content replaces it,
   including empty and image-only collections.
5. Live and replay paths consume the same backend-local parsers, mapping policy,
   and state trackers rather than independently interpreting image content.
6. Inline images are restricted to BMP, GIF, JPEG, PNG, and WebP; at most four
   images and 5 MiB decoded aggregate are forwarded per logical assistant
   message or tool attachment collection.
7. Invalid, unsupported, or over-budget images degrade safely to bounded
   metadata within the four-item prefix; later candidates are dropped.
8. No local path, remote URL, source URI, image payload, prompt, transcript,
   entity identifier, or raw parser error enters logs or crosses a contract that
   did not already carry it.
9. No Codex runtime bump and no shared wire, relay, database, client UI, or
   analytics change is required.
10. Every implementation PR remains independently buildable and targets no more
    than 1,500 changed lines as a soft cap, counting additions plus deletions,
    generated output, and tests against that PR's base.

## Current Behavior And Evidence

### Existing Sesori attachment path

PR #618 (`f57ab64a`) already provides the complete backend-neutral path:

- `bridge/sesori_plugin_interface/lib/src/models/plugin_message.dart` defines
  `PluginMessageAttachment`, `PluginMessagePart.attachment`, and
  `PluginToolState.attachments`.
- `bridge/app/lib/src/bridge/plugin_to_shared_mapping.dart` maps plugin
  attachments into the shared wire model.
- `shared/sesori_shared/lib/src/models/sesori/message_part.dart` defines the
  5 MiB decoded inline-image limit and backward-compatible tool attachment
  decoding.
- `client/app/lib/features/session_detail/widgets/file_part_widget.dart`
  renders bounded inline raster images.
- `client/app/lib/features/session_detail/widgets/tool_part_widget.dart`
  renders tool attachments.

The feature therefore belongs in the backend plugins. It does not require a new
shared attachment variant or client renderer.

### Codex

- The managed runtime is Codex `0.145.0`; the minimum accepted PATH runtime is
  `0.139.0` (`codex_runtime_manifest.dart`). Both versions expose app-server
  `ThreadItem.type=imageGeneration` with `id`, `status`, `revisedPrompt`,
  `result`, and optional `savedPath`.
- The corresponding rollout response item is
  `type=image_generation_call`, with raw base64 PNG in `result`.
- Image-generation status values are `in_progress`, `completed`, and `failed`.
- MCP results expose standard image entries with `data` and `mimeType`.
- Dynamic and persisted function-call output images use data-image URLs in
  `inputImage` / `input_image` entries.
- `bridge/sesori_plugin_codex/lib/src/codex_event_mapper.dart` currently drops
  first-class image generation and ignores MCP/dynamic image entries.
- `bridge/sesori_plugin_codex/lib/src/api/models/codex_rollout_dto.dart`
  currently represents distinct rollout payload variants as one flattened set
  of nullable fields. Extending that shape would add more invalid field
  combinations, so this plan seals it before adding persisted images.

Upstream references:

- <https://developers.openai.com/codex/image-generation.md>
- <https://github.com/openai/codex/blob/rust-v0.145.0/codex-rs/app-server-protocol/schema/typescript/ImageGenerationItem.ts>
- <https://github.com/openai/codex/blob/rust-v0.145.0/codex-rs/app-server-protocol/schema/typescript/v2/ThreadItem.ts>
- <https://github.com/openai/codex/blob/rust-v0.145.0/codex-rs/app-server-protocol/schema/typescript/ResponseItem.ts>

### ACP and Cursor

- ACP v1 uses MCP-compatible `ContentBlock`s. An image block contains required
  base64 `data`, required `mimeType`, and an optional `uri`.
- `agent_message_chunk.content` carries a `ContentBlock` directly.
- Tool content wraps the block as
  `{type: content, content: <ContentBlock>}`.
- `tool_call_update.content` explicitly replaces the prior content collection;
  omitted fields are partial updates.
- `session/load` replays the same `session/update` notifications used live.
- `bridge/sesori_plugin_acp/lib/src/acp_content.dart` currently extracts text
  from raw maps, while `AcpEventMapper` and `AcpReplayCollector` separately own
  live and replay state.
- `bridge/sesori_plugin_cursor/lib/src/cursor_event_mapper.dart` intentionally
  drops `cursor/generate_image`, whose payload is a host-local path without the
  standard ACP session/content identity needed for safe replay.

Upstream references:

- <https://agentclientprotocol.com/protocol/v1/content>
- <https://agentclientprotocol.com/protocol/v1/tool-calls>
- <https://github.com/agentclientprotocol/agent-client-protocol/releases/latest/download/schema.json>

## Locked Scope And Product Decisions

### Included

- Inline output images only.
- Codex first-class generation, MCP results, dynamic tool results, rollout
  history, and live rollout enrichment.
- Standard ACP assistant-message and tool-result image blocks, live and replay.
- Metadata fallback for recognized images that cannot be forwarded inline.
- Backend-local typed parsing, mapping, limits, state, tests, and generated code.

### Excluded

- Prompt/input-image composition or capability advertisement.
- ACP thought images and replayed user images.
- Audio, embedded resources, resource links, PDFs, SVG, and video.
- Remote image fetching or forwarding remote URLs for user launch.
- Reading local files or forwarding local paths.
- Codex `imageView` and Cursor `cursor/generate_image`.
- Shared protocol, relay, persistence, or client rendering changes.
- Product analytics. This is passive rendering with no authoritative user
  action to measure, and content/tool metadata is privacy-sensitive.

## Security And Transport Policy

Each plugin applies the same policy at its backend boundary without introducing
a new cross-plugin framework:

1. Normalize MIME metadata to a bounded display value and allow inline payloads
   only for `image/bmp`, `image/gif`, `image/jpeg`, `image/png`, and
   `image/webp`.
2. Preflight encoded length before normalization, normalize/validate base64, and
   confirm decoded length against the remaining budget.
3. Forward no more than four image attachments per logical assistant message or
   complete tool content collection.
4. Forward no more than 5 MiB decoded inline data in aggregate for that scope.
5. Convert invalid, unsupported, individually oversized, or aggregate-overflow
   candidates in the bounded prefix to `PluginMessageAttachment.metadata`.
6. Drop candidates after the four-item prefix.
7. Derive an optional display filename only through
   `normalizePluginMessageAttachmentFilename`. A Codex `savedPath`, ACP `uri`,
   or data/remote URL is never otherwise stored, logged, fetched, or forwarded.
8. Emit at most one privacy-safe degradation warning per mapped
   message/collection and reason category. Logs contain no payload values, URLs,
   paths, prompts, transcript text, IDs, or raw caught errors.

The plugins retain encoded data only as long as required by their existing
event/history models. Trackers retain counters, suffix state, and budgets rather
than decoded image bytes.

## Final Architecture

### Codex API boundary

`lib/src/api/models/codex_rollout_dto.dart` ends with a two-level sealed model:

- the outer rollout envelope represents session metadata, turn context,
  response item, compacted, and unknown records; and
- its response-item variant contains a sealed message, reasoning,
  function/custom call, function/custom output, web-search, image-generation,
  or unknown value.

The outer and inner discriminator states are nested, not independent. Every
variant carries only the non-null fields valid for that wire shape. Rollout
content is separately sealed into text, summary, input-image, and unknown
variants. Existing scalar-string tool output remains a dated compatibility
normalization at this API boundary.

App-server image-bearing items are parsed by generated DTOs under
`lib/src/api/models/` and a zero-collaborator parser under
`lib/src/api/parsers/`. The parser covers first-class generation, MCP result
content, and dynamic tool output with typed status enums. It is introduced only
when the existing MCP/dynamic production branches consume it.

### Codex repository mapping and composition

- `CodexRolloutToolMapper` moves to `lib/src/repositories/mappers/`.
- `CodexImageAttachmentMapper` lives beside it and owns all Codex image
  normalization, limits, metadata fallback, and basename-only handling.
- `CodexRolloutToolMapper` requires the image mapper and carries persisted tool
  attachments with text/status output.
- `CodexEventMapper` requires the app-server parser, image mapper, and rollout
  mapper; it does not parse new image fields from raw maps.
- `CodexMessageRepository` requires the rollout mapper and reuses its normalized
  results for history.
- `CodexPlugin` is the composition root. It constructs one parser and mapper set
  and injects every direct consumer. No constructor default creates a hidden
  production dependency.

First-class image generation uses the item ID as the message ID and
`$itemId-tool` as the part ID, with tool name `image_generation`. Started and
completed notifications upsert the same part. An identified rollout item uses
the same identity; an id-less historical record uses the existing deterministic
replay fallback and is not emitted as live rollout enrichment.

### ACP API and repository boundaries

- Generated standard ContentBlock and tool-content DTOs live under
  `lib/src/api/models/`.
- `AcpContentMapper` lives under `lib/src/repositories/mappers/` and absorbs the
  existing text, raw-output, name/status, and content-wrapper mapping currently
  held in root `acp_content.dart`.
- The mapper is the sole policy boundary for tool content. It emits sealed
  mutations: replace, update-output, or unchanged. Live and replay consumers do
  not inspect content presence independently.
- `AcpContentMapper` has no collaborators. It is explicitly required by
  `AcpEventMapper`, `AcpPlugin`, and `AcpReplayCollector`; Cursor composition
  creates one instance and supplies both live and replay owners. The mapper is
  exported because these constructors are part of the in-repository ACP package
  API. DTOs and trackers remain internal.

### ACP state ownership

`AcpContentTracker`, under `lib/src/repositories/trackers/`, owns only one
assistant message's ordered text/image segmentation, image count, byte budget,
and current part suffix. Its append operation returns typed text-delta or image
mutations. Its snapshot contains counters and budget state, not content bytes.

Both `AcpEventMapper` and `AcpReplayCollector` construct this zero-collaborator
tracker as per-message child state and immediately replace their prior content
ordering decisions with tracker mutations. The first text part retains
`$messageId-text`; text after an image uses `$messageId-text-N`, and images use
`$messageId-image-N`.

`AcpToolContentTracker`, in the same tracker directory, owns one tool's mapped
output and attachments. Both `_LiveTool` and `_ToolDraft` store it. They apply
only mapper-produced mutations, so omission, replacement, empty clearing,
image-only replacement, and `rawOutput` fallback cannot drift between live and
replay.

Live content is materialized before replay content in the delivery sequence,
but replay adopts each tracker and mapping policy in the same PR as live. The
final replay PR adds only image-part/attachment materialization and parity
coverage; it does not introduce another interpretation of content.

## Delivery Rules

- The series has exactly thirteen steps. Every PR title uses the fixed
  `[output-image-support] ... [step <x>/13]` form below.
- Step 1 raises this plan and tracker and codifies the Plan Maker's durable-plan
  lifecycle and line-budget rules. It runs documentation validation, not Dart
  or Flutter suites.
- Step 13 retires the completed plan by moving
  `.plan/active/output-image-support/` to
  `.plan/completed/output-image-support/`. It contains no production changes.
- Steps form one ordered dependency chain. A successor may target its immediate
  predecessor while both are open, but merges must occur in numeric order and
  every PR must be independently valid at its own base.
- Count additions plus deletions from `git diff --numstat`, including generated
  code and tests. Target no more than 1,500 changed lines per PR as a soft cap.
- Do not combine neighboring steps because one lands below estimate. If a step
  is projected to exceed the soft cap after codegen, first find a smaller
  independently valid split and update this plan. If no coherent split is
  practical, record the reason before opening the PR; never separate generated
  output, constructor migrations, production behavior, and the tests required
  to prove that behavior.
- Generated Freezed/JSON files change only through code generation.
- Internal plugin package contracts update every in-repository caller in
  lockstep. Do not add compatibility shims.
- Every new production parser, mapper, or tracker has a production consumer in
  the PR that introduces it.
- Live and replay adopt shared decision/state boundaries together even when
  replay image rendering is intentionally materialized later.
- Keep backend-specific image semantics inside the owning plugin. Do not add a
  shared abstraction solely to deduplicate two small backend adapters.
- Run `aristotle-impl-review` for each architecture-bearing implementation step,
  scoped to that PR's branch against its base. Do not use it for the Step 1 or
  Step 13 documentation-only lifecycle PRs.

## Delivery Sequence

| Step | Branch | Exact PR title | Estimate | Review boundary |
|---|---|---|---:|---|
| 1/13 | `investigate-opencode-image-support` | `[output-image-support] docs: plan output image support [step 1/13]` | 450-700 | Durable plan/tracker plus Plan Maker delivery rules. |
| 2/13 | `output-image-support-codex-rollout-content` | `[output-image-support] refactor(codex): seal rollout content [step 2/13]` | 1,200-1,500 | Content variants, mapper move, and explicit dependency wiring without image behavior. |
| 3/13 | `output-image-support-codex-rollout-envelopes` | `[output-image-support] refactor(codex): seal rollout envelopes [step 3/13]` | 900-1,350 | Permanent outer rollout envelope; no behavior change. |
| 4/13 | `output-image-support-codex-response-items` | `[output-image-support] refactor(codex): seal response items [step 4/13]` | 1,100-1,500 | Permanent nested response-item variants and exhaustive consumers. |
| 5/13 | `output-image-support-codex-image-events` | `[output-image-support] refactor(codex): type image-bearing events [step 5/13]` | 1,200-1,500 | Typed app-server boundary consumed by existing MCP/dynamic text mapping. |
| 6/13 | `output-image-support-codex-live-images` | `[output-image-support] feat(codex): surface live output images [step 6/13]` | 900-1,400 | Secure image mapper and live first-class/MCP/dynamic attachments. |
| 7/13 | `output-image-support-codex-image-history` | `[output-image-support] feat(codex): restore output image history [step 7/13]` | 1,100-1,500 | Rollout/history images and live/history convergence. |
| 8/13 | `output-image-support-acp-content-blocks` | `[output-image-support] refactor(acp): type content blocks [step 8/13]` | 1,300-1,500 | Content DTO/mapper, explicit composition, and live/replay text consumers. |
| 9/13 | `output-image-support-acp-content-mapping` | `[output-image-support] refactor(acp): centralize tool content mapping [step 9/13]` | 1,100-1,500 | Tool DTOs and one shared behavior-preserving content policy. |
| 10/13 | `output-image-support-acp-message-images` | `[output-image-support] feat(acp): surface live message images [step 10/13]` | 1,100-1,500 | Message tracker adopted live/replay; live image materialization. |
| 11/13 | `output-image-support-acp-tool-images` | `⚙️ [output-image-support] feat(acp): surface live tool images [step 11/13]` | 1,200-1,500 | Tool tracker adopted live/replay; live attachment materialization. |
| 12/13 | `output-image-support-acp-image-replay` | `[output-image-support] feat(acp): restore output image replay [step 12/13]` | 900-1,400 | Replay materialization and end-to-end parity proof only. |
| 13/13 | `output-image-support-retire-plan` | `[output-image-support] docs: retire output image support plan [step 13/13]` | 50-200 | Record completion and move the plan tree from active to completed. |

## Step Details And Verification

### Step 1/13 — Deliver The Plan

- Add `.plan/active/output-image-support/PLAN.md` and `TRACKER.md`, and update
  `.opencode/agents/sesori-plan-maker.md` with the durable-plan lifecycle and
  1,500-line soft-cap rules requested for future plans.
- Validate fixed slug, titles, totals, estimates, dependencies, and Markdown.
- Run `git diff --check`. No Dart/Flutter suites or implementation review.

### Step 2/13 — Seal Codex Rollout Content

- Replace `CodexRolloutContentType` plus flattened content fields with generated
  input/output/summary text, input-image, and unknown variants.
- Preserve current text/reasoning/tool output and malformed-item recovery.
- Move `CodexRolloutToolMapper` under `repositories/mappers` and inject it into
  event/history consumers from `CodexPlugin`.
- Parse persisted input-image without surfacing it yet.
- Run Codex codegen, focused DTO/mapper/repository tests, full Codex tests, fatal
  analysis, and implementation architecture review.

### Step 3/13 — Seal Codex Rollout Envelopes

- Introduce the permanent sealed outer line/payload envelope for session
  metadata, turn context, response item, compacted, and unknown records.
- Update catalog, tailer, mapper, and repository consumers atomically.
- Preserve the existing response-item representation inside its new envelope
  until Step 4; this PR permanently removes only outer discriminator mismatch.
- Run Codex codegen, structural/catalog/tailer tests, full Codex tests, fatal
  analysis, and implementation architecture review.

### Step 4/13 — Seal Codex Response Items

- Replace the nested response-item representation with generated message,
  reasoning, function/custom call/output, web-search, and unknown variants.
- Keep image generation unknown until Step 7, so this remains behavior-neutral.
- Retain argument/output compatibility at the API boundary and privacy-safe
  malformed-record diagnostics.
- Run Codex codegen, exhaustive DTO/mapper/history tests, full Codex tests, fatal
  analysis, and implementation architecture review.

### Step 5/13 — Type Codex Image-Bearing Events

- Add generated app-server DTOs and a zero-collaborator parser for first-class
  image generation, MCP text/image content, and dynamic text/image/audio output.
- Add typed image/tool status enums with unknown fallback.
- Immediately migrate existing MCP and dynamic text/status/error mapping to the
  parser, preserving output behavior. Explicitly drop image-generation/image
  fields until Step 6 so the parser is never unused production scaffolding.
- Wire the parser from `CodexPlugin`; update every constructor caller in
  lockstep.
- Run codegen, parser/event regression tests, full Codex tests, fatal analysis,
  and implementation architecture review.

### Step 6/13 — Surface Live Codex Images

- Add `CodexImageAttachmentMapper` under `repositories/mappers` with the locked
  security, MIME, count, byte, metadata, basename, and logging policy.
- Map first-class started/completed/failed generation to one stable tool part.
- Add MCP and dynamic image attachments while preserving text and errors.
- Keep `imageView`, remote URLs, audio, and local paths unsupported.
- Run focused mapper/event limits and privacy tests, full Codex tests, fatal
  analysis, and implementation architecture review.

### Step 7/13 — Restore Codex Image History

- Add typed rollout `image_generation_call` and map it through the same image
  mapper as live events.
- Carry persisted `input_image` tool attachments through rollout results,
  canonical live enrichment, and `CodexMessageRepository` history.
- Prove stable live/history IDs and that later app-server updates cannot erase
  richer rollout attachments.
- Run Codex codegen, rollout/history/convergence tests, full Codex tests, fatal
  analysis, and implementation architecture review.

### Step 8/13 — Type ACP Content Blocks

- Add generated text/image/unsupported/unknown ContentBlock DTOs under
  `api/models` and `AcpContentMapper` under `repositories/mappers`.
- Wire the mapper into both live and replay text paths immediately, preserving
  current text behavior and updating all ACP/Cursor constructor consumers.
- Validate individual image candidates and basename-only URI metadata, but do
  not materialize image parts before the tracker exists.
- Export only the mapper required by the in-repository public constructors.
- Run ACP codegen, mapper/live/replay text regressions, ACP and affected Cursor
  tests, fatal analysis in both packages, and implementation architecture review.

### Step 9/13 — Centralize ACP Tool Content Mapping

- Add typed content/diff/terminal/unknown tool-content DTOs.
- Move existing root `acp_content.dart` behavior into `AcpContentMapper` and
  delete the superseded root file.
- Make both live and replay tool text paths consume one behavior-preserving
  mapper result; no image attachment is materialized yet.
- Preserve tool name, title, status, raw output, clipping, and diff signaling.
- Run codegen, mapper/event/replay regressions, ACP and affected Cursor tests,
  fatal analysis, and implementation architecture review.

### Step 10/13 — Surface Live ACP Message Images

- Add zero-collaborator `AcpContentTracker` and use it immediately in both
  `AcpEventMapper` and `AcpReplayCollector`, removing prior assistant content
  parsing/ordering ownership.
- Live mapping materializes bounded image file parts and preserves mixed order,
  message IDs, id-less envelopes, halt rules, and exact cleanup.
- Replay records the same tracker mutations and text segmentation immediately;
  Step 12 merely turns already-mapped image mutations into replay parts.
- Prove Cursor still drops `cursor/generate_image` while inheriting standard ACP
  message images.
- Run tracker/event/replay structural tests, ACP and Cursor suites, fatal
  analysis, and implementation architecture review.

### Step 11/13 — Surface Live ACP Tool Images

- Add zero-collaborator `AcpToolContentTracker`.
- Make `AcpContentMapper` emit sealed replace/update-output/unchanged mutations.
- Adopt the tracker in both `_LiveTool` and `_ToolDraft` in this PR, deleting all
  independent replacement/preservation decisions.
- Materialize live attachments; replay stores the same normalized final state
  but omits attachment rendering until Step 12.
- Prove omitted-content preservation, present-content replacement, empty clear,
  image-only replacement, raw-output fallback, limits, and diff behavior.
- Run tracker/mapper/event/replay tests, ACP and Cursor suites, fatal analysis,
  and implementation architecture review.

### Step 12/13 — Restore ACP Image Replay

- Materialize the already-recorded assistant image mutations as ordered file
  parts and the already-tracked tool attachments in replay output.
- Preserve halt classification only for pure text, initial-user identity reuse,
  model/provider stamping, message-ID grouping, and chronological tool
  boundaries.
- Add collector parity tables and an end-to-end `getSessionMessages` test using
  the dedicated replay client.
- Run focused replay/history tests, full ACP and Cursor tests, fatal analysis,
  and implementation architecture review.

### Step 13/13 — Retire The Plan

- After Step 12 merges and its verification is complete, update the tracker with
  the final merged PR and verification evidence.
- Move `.plan/active/output-image-support/` to
  `.plan/completed/output-image-support/` in the same commit.
- Confirm all thirteen PRs merged in order and run `git diff --check`. This
  documentation-only lifecycle step requires no Dart/Flutter suites or
  implementation architecture review.

## Compatibility

- The client/bridge attachment wire contract remains the one introduced by PR
  #618. Older peers retain its existing defaults and graceful degradation.
- A new app with an older bridge continues to receive no images from these
  plugins; existing text/tool flows remain usable.
- An older app with the new bridge follows the already-established attachment
  compatibility behavior; this plan adds no wire discriminator.
- Internal Dart package APIs update all monorepo consumers in lockstep, with no
  deprecated aliases or optional compatibility parameters.

## Material Risks And Mitigations

| Risk | Mitigation |
|---|---|
| Generated Freezed diffs exceed the review budget. | Keep content, outer envelope, inner response items, and app-server DTOs in distinct PRs; count generated lines before opening each PR. |
| Malformed or oversized base64 causes memory/relay pressure. | Preflight encoded size, normalize once, enforce exact decoded aggregate limits, and degrade before plugin-to-wire mapping. |
| Live and history produce different IDs or attachment state. | Share repository mappers/trackers and add explicit convergence tests before each history/replay step completes. |
| ACP text after an image appends before the image. | `AcpContentTracker` closes the current text segment on every recognized image and assigns deterministic later suffixes. |
| Partial ACP tool updates erase or accumulate attachments incorrectly. | One mapper emits sealed content mutations; one tracker applies them in both live and replay paths. |
| Backend paths or URLs leak to the phone/logs. | Never read/forward source locations; derive only normalized basenames and assert absence in tests/log capture. |
| Preparatory PR introduces unused architecture. | Every parser/mapper/tracker is production-consumed in the PR that adds it; behavior can remain intentionally text-only until the next feature boundary. |

## Plan Review Record

Architecture review rejected earlier drafts for extending invalid flattened
rollout state, mixing API/mapping/tracker layers, duplicating ACP replacement
policy, ambiguous constructor ownership, temporarily unused production
abstractions, and live/replay asymmetry. Those findings are incorporated here:

- rollout and ContentBlock wire variants are typed at API boundaries;
- repository mappers and trackers live in explicit layer directories;
- constructors and composition ownership are named;
- live and replay adopt common policy/state in the same steps; and
- parser/mapper/tracker classes gain production consumers immediately.

The corrected draft was not re-reviewed merely to obtain an approval verdict,
in accordance with the repository plan-review process. Step 1 review should
therefore evaluate this committed plan on its merits rather than treating an
earlier draft rejection as approval of this revision.
