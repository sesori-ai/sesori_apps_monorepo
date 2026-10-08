import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// The running compaction part of each session. OpenCode's compaction delta
/// names only its session, so its words reach the part through this record.
class OpenCodeV2CompactionTracker() {
  final Map<String, PluginMessagePartCompaction> _running = {};

  PluginMessagePartCompaction? running({required String sessionId}) => _running[sessionId];

  /// Records [message]'s compaction while it runs and forgets it once it settles.
  void observe({required PluginMessageWithParts message}) {
    final sessionId = message.info.sessionID;
    switch (message.parts.whereType<PluginMessagePartCompaction>().firstOrNull) {
      case final part? when part.compactionState is PluginCompactionStateRunning:
        _running[sessionId] = part;
      case _:
        _running.remove(sessionId);
    }
  }

  void reset() => _running.clear();
}
