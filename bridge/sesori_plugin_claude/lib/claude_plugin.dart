/// The Sesori bridge plugin for the Claude Code harness.
///
/// Drives the `claude` CLI's headless stream-json protocol over stdio — the
/// same ndjson protocol the official Agent SDK speaks internally — so the
/// bridge needs no Node runtime.
///
/// The wire protocol this package implements is documented in
/// `.plan/active/claude-code-plugin/PROTOCOL.md`, verified against Claude CLI
/// 2.1.221 and `@anthropic-ai/claude-agent-sdk@0.3.221`.
library;

export "src/api/claude_launch_spec.dart";
export "src/models/claude_effort_level.dart";
export "src/models/claude_permission_mode.dart";
