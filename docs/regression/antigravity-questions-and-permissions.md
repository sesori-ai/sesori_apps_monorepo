# Antigravity Questions and Permission Replies

## Status and scope

Internal, unregistered interaction foundations. These tests exercise injected connection-scoped peers, not a live
Antigravity plugin. Shared ACP registry integration belongs to Step 8; activation belongs to Step 9. No new client
contract, database change, persistent approval, OAuth execution, or credential/history access is included.

## Required behavior

- The plugin Layer-2 mapper decodes `session/request_permission` into generated typed DTOs before policy. Unknown
  methods receive a JSON-RPC method-not-found error rather than an invented permission response.
- Requests require nonblank session/tool-call IDs and title. Session/tool-call/option IDs are bounded to 256
  characters, option labels to 512, and titles to 4096. The external option list is bounded to 32 before DTO expansion.
  Invalid shapes, oversized fields and duplicate option IDs cancel without leaving an invisible pending entry.
- The interaction service selects only advertised `allow_once` or `reject_once` choices without a non-null
  `agy.security.warning` value. Persistent or unknown kinds are excluded. A normal permission requires exactly one usable allow-once
  choice and at most one reject-once choice; no answer is sent before a user reply or lifecycle cancellation.
- Ordinary approval returns the exact advertised allow-once ID. Reject returns the advertised reject-once ID when
  present, otherwise ACP cancellation. An `always` reply never grants a persistent or once-only approval. Permission
  snapshots do not advertise always-allow. No missing option ID is synthesized. Permission headers use the standard
  ACP tool category, not the opaque call ID; absent/future categories display the honest fallback `tool`.
- A valid `interaction_` tool-call request becomes one single-choice question with at least two safe choices.
  Advertised labels and opaque IDs are preserved; duplicate safe labels are rejected, never renumbered or repaired.
  Reject-kind choices remain selectable answers, distinct from dismissing the question.
- Only one exact advertised label for that one question is accepted. Multiple/custom/unknown answers, raw option IDs
  and modified labels cancel the request and emit question rejection. Explicit question dismissal also cancels.
- Every reply follows registry -> interaction service -> connection-scoped repository -> ACP client, with generated
  response serialization. The registry owns pending lifecycle only. It reuses `PendingPermissionRegistry`, not the
  stock ACP registry's raw-policy/direct-responder path.
- Pending replies are one-shot. Misrouting a question ID to permission reply leaves the question pending. Wire dispatch
  precedes a terminal reply event; session cancellation settles only that session, and disposal settles remaining
  entries once and detaches the request stream. Separate connection registries never reply through another client.
- Malformed-request recovery remains observable through a safe typed exception and local log with the original stack.
  Checked decoding records the generated DTO class, field, and inner error type; policy failures retain their useful
  authored message, and logs identify the request. Original decoder causes/stacks remain attached, but malformed
  values and payload-bearing decoder messages are not rendered.

## Failure signals and coverage

- Any silent approval, always-allow dispatch, warning-bearing option exposure, fabricated option ID, or response sent
  through another connection is a security regression. So is accepting ambiguous labels or malformed answers.
- Invisible pending requests, duplicate wire responses, premature reply events, or requests handled after disposal
  indicate pending-lifecycle regressions.
- `antigravity_interaction_service_test.dart` uses real ACP response encoding with a fake process and twelve focused tests:
  ordinary once/reject/always behavior; interaction questions with reject-kind and filtered choices; wrong-kind and
  duplicate replies; malformed answers; duplicate labels/IDs and unsafe choices; bounded/invalid DTO fields;
  unknown methods; cancellation/disposal and stream detachment; independent connection dispatch; tool-kind fallback;
  and useful decoder field/type/cause evidence without malformed-value disclosure.
- Owning package analysis and focused tests cover these foundations; this slice does not activate or verify shared
  ACP registry wiring or live Google tools.
- Step 8 must introduce the narrow neutral registry integration seam, preserve existing ACP consumers, and exercise
  Antigravity composition there. Live harness, client-to-bridge execution and the final L5 Full matrix remain unverified.
