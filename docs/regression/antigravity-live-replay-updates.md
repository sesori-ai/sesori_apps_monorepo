# Antigravity Live and Replay Updates

## Status and scope

Internal, unregistered Step 7.c foundations. Shared ACP now offers an identity-by-default normalization hook;
Antigravity's protocol mapper is tested through that hook, but concrete plugin composition remains Step 8 and
activation Step 9. No client/wire tool-state expansion, database changes, OAuth, credential access or history mutation.

## Required behavior

- `AcpEventMapper.normalizeSessionUpdate` is a pure envelope transformation. Live mapping and `AcpReplayCollector`
  invoke the same hook before retaining tool state. ACP plugin replay and DeepSeek's separate history repository pass
  their live mapper's hook; other direct collectors explicitly select identity when no transformation is required.
- Existing harnesses retain identity behavior. Antigravity transforms only tool-call/tool-call-update envelopes, never
  assistant text or other updates. Caller envelopes and standard image content are not mutated.
- Generated DTOs decode native command/CWD aliases, combined output and exit codes before normalization. Supported
  aliases and raw sanitation follow `pingdotgg/t3code@fff33f9e851912363c5b1f3ac65598be35eb5f0d`,
  `apps/server/src/provider/acp/AntigravityProtocol.ts`; this is corroborating pinned evidence, not an alternate runtime.
- Command/CWD labels are trimmed and bounded to 8,000 characters. Command becomes the display title; execute kind is
  inferred only when no kind is advertised. Combined-output/stdout aliases and the `formatted_output` fallback become
  standard stdout, retaining the numeric exit code.
- Nonzero process exit appends a clearly labelled `[Process exit code: N]` note, including when command output exists.
  Reserve note space inside the existing 500-character shared tool-display limit, retaining the output tail with a
  truncation marker. Do not classify a nonzero exit as an ACP tool/protocol failure. Genuine failed tool status stays
  failed; successful/completed status stays completed. Live and replay must produce identical tool state.
- Deduplicate standard text only on exact equality with native output, including text split across blocks. Retain
  differing standard/native text together, reserving bounded space for both tails and the exit note. Accept direct
  map/string content as well as lists, matching existing shared ACP handling. Preserve original non-text content entries,
  including valid standard inline images; the existing ACP attachment mapper owns their MIME/size/count limits and
  metadata degradation. Image paths in native payloads remain bounded metadata, never a filesystem read or fetch.
- Raw input/output/metadata each use a 512-node, 64,000-character text, depth-12 sanitation budget; individual raw
  strings are bounded to 8,000 characters. Canonical derived fields have their own bounds. Remove documented raw
  image data/blob/data-image URI copies and formatted output identical to combined output; retain useful metadata.
  Sanitized-away fields cannot reappear from merging the original envelope. Standard content attachments remain
  governed by ACP's existing separate limits rather than the raw-payload budget.
- Malformed native aliases degrade to bounded raw data with an original error/stack log, not invented command policy.
  Generated envelope decoding failures log and retain existing ACP handling. Malformed known content blocks log and
  preserve their original entries for the shared mapper's bounded degradation, rather than aborting live/replay.
  Known shapes still use generated DTOs; raw JSON type suppressions are limited to the mapper/DTO arbitrary payload
  boundary. No provider status or approval policy moves into shared ACP.

## Failure signals and coverage

- A nonzero exit note disappearing after display truncation, nonzero exit changing completed status into tool failure,
  a genuine tool failure becoming success, differing live/replay output, or duplicate displayed native text is a regression.
- Lost supported standard images, retained redundant raw image bytes, original fields reappearing after sanitation,
  caller-envelope mutation, or unbounded raw metadata indicates normalization regression.
- `antigravity_protocol_mapper_updates_test.dart`: 21 tests cover exact aliases, identity, live/replay equality,
  nonzero/empty/success/failure output with and without standard content, update-only replay, tail/note bounds, valid
  inline images and retained metadata, raw-copy removal, aggregate budgets and observable malformed-native fallback;
  formatted-only output, distinct/duplicate standard text, malformed blocks/envelopes and direct-map images.
- `acp_session_loader_test.dart`, `acp_tool_content_integration_test.dart`, and `acp_history_replay_test.dart` exercise
  standard identity behavior and production replay; DeepSeek history/time tests cover its direct collector path.
- Owning ACP/Antigravity and changed DeepSeek analyses are the static boundary. Actual Antigravity plugin hooks,
  authenticated sessions, real Google-generated images and final L5 Full remain later integration gates.
