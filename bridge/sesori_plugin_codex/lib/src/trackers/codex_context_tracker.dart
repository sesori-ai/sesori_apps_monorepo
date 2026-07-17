import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;

import "../codex_config_reader.dart";
import "../repositories/models/codex_app_server_repository_models.dart";

/// Mutable per-thread facts used to build immutable event-mapping context.
class CodexContextTracker {
  CodexContextTracker({
    required String pluginId,
    required String launchDirectory,
    required CodexConfigDefaults defaults,
  }) : _pluginId = pluginId,
       _launchDirectory = normalizeProjectDirectory(directory: launchDirectory),
       _defaults = defaults;

  final String _pluginId;
  final String _launchDirectory;
  final CodexConfigDefaults _defaults;
  final Map<String, String> _models = {};
  final Map<String, String> _providers = {};
  final Map<String, String> _directories = {};

  void recordFacts(CodexThreadContextFacts facts) {
    record(
      threadId: facts.threadId,
      model: facts.model,
      provider: facts.provider,
      directory: facts.directory,
    );
  }

  void record({
    required String threadId,
    required String? model,
    required String? provider,
    required String? directory,
  }) {
    if (model != null && model.isNotEmpty) _models[threadId] = model;
    if (provider != null && provider.isNotEmpty) _providers[threadId] = provider;
    if (directory != null && directory.isNotEmpty) {
      _directories[threadId] = normalizeProjectDirectory(directory: directory);
    }
  }

  void setModel({required String threadId, required CodexModelSelection? model}) {
    if (model == null) {
      _models.remove(threadId);
      _providers.remove(threadId);
      return;
    }
    _models[threadId] = model.modelId;
    _providers[threadId] = model.providerId;
  }

  String? knownDirectory({required String threadId}) => _directories[threadId];

  CodexEventContext snapshot({
    required String? threadId,
    required String? notificationDirectory,
  }) {
    final directory = threadId == null ? null : _directories[threadId];
    final model = threadId == null ? null : _models[threadId];
    final provider = threadId == null ? null : _providers[threadId];
    return CodexEventContext(
      pluginId: _pluginId,
      projectId: normalizeProjectDirectory(
        directory: directory ?? notificationDirectory ?? _launchDirectory,
      ),
      modelId: model ?? _defaults.model,
      providerId: provider ?? _defaults.modelProvider ?? "openai",
    );
  }

  void forgetThread({required String threadId}) {
    _models.remove(threadId);
    _providers.remove(threadId);
    _directories.remove(threadId);
  }
}

class CodexEventContext {
  const CodexEventContext({
    required this.pluginId,
    required this.projectId,
    required this.modelId,
    required this.providerId,
  });

  final String pluginId;
  final String projectId;
  final String? modelId;
  final String providerId;
}
