/// The Sesori bridge plugin for the Claude Code harness.
///
/// Drives the `claude` CLI's headless stream-json protocol over stdio — the
/// same ndjson protocol the official Agent SDK speaks internally — so the
/// bridge needs no Node runtime.
///
/// The wire protocol this package implements is documented in
/// `.plan/completed/claude-code-plugin/PROTOCOL.md`, verified against Claude CLI
/// 2.1.221 and `@anthropic-ai/claude-agent-sdk@0.3.221`.
library;

export "src/api/claude_launch_spec.dart";
export "src/api/claude_process_factory.dart";
export "src/api/claude_stream_client.dart";
export "src/api/claude_transcript_api.dart";
export "src/api/models/claude_backend_catalog_dto.dart";
export "src/api/models/claude_content_block_dto.dart";
export "src/api/models/claude_stream_message.dart";
export "src/api/models/claude_transcript_record_dto.dart";
export "src/claude_approval_registry.dart";
export "src/claude_event_dispatcher.dart";
export "src/claude_history_mapper.dart";
export "src/claude_plugin_impl.dart";
export "src/models/claude_agent_selection.dart";
export "src/models/claude_effort_level.dart";
export "src/models/claude_permission_mode.dart";
export "src/repositories/claude_backend_catalog_repository.dart";
export "src/repositories/claude_session_process_repository.dart";
export "src/repositories/claude_transcript_catalog_repository.dart";
export "src/repositories/mappers/claude_content_mapper.dart";
export "src/repositories/models/claude_session_record.dart";
export "src/repositories/models/claude_transcript_record.dart";
export "src/repositories/trackers/claude_tool_tracker.dart";
export "src/runtime/claude_bridge_plugin.dart";
export "src/runtime/claude_plugin_descriptor.dart";
export "src/services/claude_catalog_service.dart";
export "src/services/claude_session_service.dart";
