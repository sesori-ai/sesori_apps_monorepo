import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/codex_thread_sample_dto.dart";
import "../../codex_app_server_client.dart";

/// Maps Codex's `thread/sample` result into the plugin contract.
class const CodexSideAnswerMapper() {
  PluginSideAnswer map({required CodexThreadSampleDto sample}) {
    final text = sample.text?.trim();
    if (text == null || text.isEmpty) return const PluginSideRefused(reason: PluginSideRefusal.noAnswer);
    return PluginSideAnswered(text: text, notice: null);
  }

  /// The refusal for an [error] that means this Codex can't answer side
  /// questions, or null for any other error.
  PluginSideAnswer? mapUnsupported({required CodexRpcException error}) {
    final message = error.message;
    final unsupported =
        // Releases before 0.164.0 reject the method as "Invalid request:
        // unknown variant `thread/sample`, expected one of …".
        message.contains("unknown variant `thread/sample`") ||
        // 0.164.0 to 0.168.x have thread/sample but ignore
        // allowInProgressTurn, so they refuse while a turn runs.
        message.contains("sample source must be idle");
    return unsupported ? const PluginSideRefused(reason: PluginSideRefusal.harnessUpdateRequired) : null;
  }
}
