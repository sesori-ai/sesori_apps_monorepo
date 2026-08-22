# Step 2/45 — Delete the dead concurrency copy

**PR:** [#1019](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1019)

## Re-verification against `main`

Plan evidence held exactly. `dto_parser.dart` still had zero references in
`client/`; the concurrency tree's only importer was `dto_parser.dart`;
`MessageQueue`/`ConcurrentCache` had no production consumer. Two references the
plan had not listed were found and handled: `client/module_core/README.md:30`
and the `concurrency/` line in `client/module_core/AGENTS.md`.

## Verification

`client/module_core`: analyze clean, 1,172 tests. `client/app`: analyze clean,
`test/core` 217 tests. Size `+0 / -1,356` (15 files deleted).

Architecture implementation review not run — deletion-only.
