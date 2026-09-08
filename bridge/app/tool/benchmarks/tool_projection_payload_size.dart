import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/repositories/mappers/plugin_to_shared_mapping.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Synthetic UTF-8 JSON sizes, not relay/compression/latency or harness measurements.
/// Run from bridge/app: dart run tool/benchmarks/tool_projection_payload_size.dart
void main() {
  stdout.writeln("Synthetic state-only UTF-8 JSON bytes; no envelopes, encryption, compression or images.");
  stdout.writeln("Unfiltered = source fields in released wire shape. Before = PR #1221 pre-correction projection.");
  stdout.writeln("After = current common projection. 100 repetitions per scenario; limit=$maxToolOutputLength runes.");
  stdout.writeln("scenario,unfiltered,before,after");
  for (final fixture in [
    (name: "ordinary-read", command: null, priorCommand: null, subtask: false),
    (name: "shell-result", command: "git status", priorCommand: "git status", subtask: false),
    (name: "codex-code-only", command: null, priorCommand: 'console.log("non-shell data")', subtask: false),
    (name: "subtask-outcome", command: null, priorCommand: null, subtask: true),
  ]) {
    final state = PluginToolState(
      status: PluginToolStatus.error,
      title: "Synthetic title",
      shellCommand: fixture.command,
      output: "😀" * 12000,
      error: "é" * 12000,
      attachments: const [],
    );
    final raw = ToolState(
      status: ToolStatus.error,
      title: state.title,
      shellCommand: fixture.priorCommand,
      output: state.output,
      error: state.error,
      attachments: const [],
    );
    // Reproduces the starting-HEAD state projection, including subtask stripping
    // and the demonstrated normalized Codex exec title misclassification.
    final before = ToolState(
      status: ToolStatus.error,
      title: fixture.priorCommand,
      shellCommand: fixture.priorCommand,
      output: fixture.priorCommand == null ? null : state.output,
      error: fixture.priorCommand == null ? null : state.error,
      attachments: const [],
    );
    final part = fixture.subtask
        ? PluginMessagePart.subtask(
            id: "t",
            sessionID: "s",
            messageID: "m",
            prompt: "task",
            description: "task",
            agent: "agent",
            taskState: state,
            childSessionID: "child",
          )
        : PluginMessagePart.tool(id: "t", sessionID: "s", messageID: "m", tool: "tool", state: state);
    final projected = part.toShared(sessionId: "s");
    final after = switch (projected) {
      MessagePartTool(:final state) => state,
      MessagePartSubtask(:final taskState) => taskState!,
      _ => throw StateError("Unexpected synthetic part"),
    };
    int bytes({required ToolState state}) => utf8.encode(jsonEncode(List.filled(100, state.toJson()))).length;
    stdout.writeln("${fixture.name},${bytes(state: raw)},${bytes(state: before)},${bytes(state: after)}");
  }
}
