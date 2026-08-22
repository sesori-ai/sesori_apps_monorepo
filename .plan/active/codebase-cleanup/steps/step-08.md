# Step 8/45 — Plugin-interface testing library for console fakes

## Re-verification against `main`

36 `Stdout` fake declarations exist across 32 files in 7 packages
(`bridge/app` 16, `sesori_plugin_acp` 4, `sesori_plugin_codex` 4,
`sesori_plugin_interface` 4, `sesori_plugin_claude` 2, `sesori_plugin_cursor` 1,
`sesori_plugin_runtime` 1). Hashing the bodies shows they are not all the same
fake:

| Body hash | Copies | Shape |
|---|---|---|
| `bf4cebdc` | 10 | buffering, `writeln` only |
| `52337a09` | 4 | buffering, `write` + `writeln` |
| `bbb212bc` | 4 | capturing into a `List<String>` |
| 13 others | 1–2 each | bespoke: terminal flags, ANSI support, throwing |

Only the three identical groups (18 declarations) are migrated. The remaining
declarations carry per-test constructor parameters — `supportsAnsiEscapes`,
`hasTerminal`, specific throw behaviour — and are left where they are rather
than growing the shared fakes a knob at a time.

The plan also listed `HostProcessService`, `SpawnedProcess`, `BridgeHostInfo`
and `CapturingIOSink` for this step. They are **not** here: those fakes carry
scripted behaviour rather than being identical, so consolidating them is a
design exercise rather than a de-duplication, and folding it into the same PR
would bury the mechanical part. They move to a follow-up.

## Verification

`dart analyze --fatal-infos` clean in all seven affected packages. `dart test`:
`sesori_plugin_interface` 153, `sesori_plugin_runtime` 132, `sesori_plugin_acp`
260, `sesori_plugin_claude` 253, `sesori_plugin_codex` 392,
`sesori_plugin_cursor` 136, `bridge/app` 2,684 — 4,010 tests passing.

Architecture implementation review not run: the new library is test-only and
exports no production type; no production file is touched.
