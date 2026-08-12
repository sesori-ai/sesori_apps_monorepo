/// Test doubles for the Claude Code plugin, shared with packages that compose
/// it. Not exported from `claude_plugin.dart` — production code must never
/// depend on a fake process.
library;

export "src/testing/fake_claude_process.dart";
