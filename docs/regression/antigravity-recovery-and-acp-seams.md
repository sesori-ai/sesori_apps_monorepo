# Antigravity Recovery Foundations and ACP Seams

## Status and scope

Step 8.a foundations only. Antigravity remains unregistered; Step 8.b composes its concrete plugin/descriptor and
calls recovery at import/cold activation. No ordinary-read scan, database migration, history deletion, OAuth, token
inspection, ambient credential access, managed installation or user-visible capability is introduced here.

## Supported behavior

- Metadata storage only lists the prepared profile's `antigravity-acp/conversations` directory, without recursion or
  following listed links. Only regular `.meta` files are read; SQLite, brain files, and token files are not opened.
- A service scan processes at most 10,000 directory entries (one lookahead detects truncation); each metadata read
  is bounded to 64 KiB before decoding.
  The generated DTO consumes only string `cwd`. The repository canonicalizes UUID filename case and path syntax
  without turning a relative cwd into the bridge's working directory.
- The service accepts UUID filenames and absolute, NUL-free cwds of at most 4,096 characters, deduplicates IDs, and
  returns one immutable typed directory batch. Duplicates retain the first normalized entry. Bounds, duplicates,
  per-file failures and listing failures remain observable locally. Decode errors retain original cause/stack but
  never render ignored JSON values; diagnostics identify the path and JSON location or cwd/type.
- Missing history creates no directories. Recovery never writes metadata or replaces existing bridge attribution.
  The shared bulk hook reuses `primeSessionDirectory`: DB/live attribution wins over recovered hints; later live
  attribution can replace a recovered hint. No second directory cache or lifecycle owner is added.
- `AcpPendingRegistry` supplies only neutral pending lifecycle and attribution routing. Stock/Cursor/DeepSeek keep
  their existing policy; Antigravity continues through its service/repository. Ambiguous requests cannot use an
  active-turn guess, create pending UI or approve a tool. Existing reply, session-cancel and disposal behavior remains.
- Residency defaults to load-first. A resume-first override chooses resume only when advertised; load is its fallback
  when resume is unavailable. Neither preference retries arbitrary errors using the other RPC. Existing transient
  retry-on-next-turn and permanent-unsupported memoization remain unchanged. History replay always uses load.
- Each live/replay process receives a fresh output-interceptor pair from the policy hook. Null stream policies retain
  default behavior. `AcpStdioClient` remains responsible for interception before decoding/logging and for failure
  cleanup; callback state is not shared by composition between live and replay processes.

## Failure signals and coverage

- Metadata reaching SQLite/brain/token content, modifying files, manufacturing an absolute cwd, replacing live/DB
  attribution, exposing malformed JSON contents in logs, or scanning on ordinary reads is a regression.
- A non-stock registry bypassing attribution/cancellation, a resume preference changing replay, error-triggered
  alternate-RPC retry, or any process skipping its pre-log output policy is a regression.
- `antigravity_session_metadata_service_test.dart`: isolated temporary profiles, missing history, UUID/cwd mapping,
  malformed/oversized records, relative cwd, byte/entry bounds, link exclusion, duplicate handling, immutable batch
  and privacy-safe decoder presentation. Windows link creation is skipped when host privilege would be required.
- `antigravity_interaction_service_test.dart`: neutral ambiguous-attribution rejection through actual ACP response
  encoding, plus existing permission/question/cancellation coverage.
- `acp_recovery_seams_test.dart`: all preference/capability combinations, no alternate retry after an error, directory
  authority without spawning, non-stock routing/pending lifecycle, and fresh live/replay stdout/stderr policies.
- Existing ACP approval/project/resume/reconnect/replay/output tests and Cursor/DeepSeek registry tests retain their
  owning behavior. Concrete Antigravity lifecycle integration and final L5 Full are later gates, not claimed here.
