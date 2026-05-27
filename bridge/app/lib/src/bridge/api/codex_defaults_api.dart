import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

class CodexDefaultsApi {
  final Map<String, String> _environment;

  CodexDefaultsApi({Map<String, String>? environment}) : _environment = environment ?? Platform.environment;

  CodexSelectionDefaults readProjectDefaults({required String projectId}) {
    final config = _readLocalConfig();
    return CodexSelectionDefaults(
      agent: "codex",
      modelId: config.model,
      modelProvider: config.modelProvider ?? _latestProjectModelProvider(projectId: projectId) ?? "openai",
    );
  }

  CodexSelectionDefaults readSessionDefaults({required String sessionId}) {
    final config = _readLocalConfig();
    return CodexSelectionDefaults(
      agent: "codex",
      modelId: config.model,
      modelProvider: config.modelProvider ?? _sessionModelProvider(sessionId: sessionId) ?? "openai",
    );
  }

  _CodexLocalConfig _readLocalConfig() {
    final codexHome = _codexHome;
    if (codexHome == null) {
      return const _CodexLocalConfig(model: null, modelProvider: null);
    }

    final file = File(p.join(codexHome, "config.toml"));
    if (!file.existsSync()) {
      return const _CodexLocalConfig(model: null, modelProvider: null);
    }

    String? model;
    String? modelProvider;
    var insideSection = false;

    for (final rawLine in file.readAsLinesSync()) {
      final line = rawLine.split("#").first.trim();
      if (line.isEmpty) {
        continue;
      }
      if (line.startsWith("[")) {
        insideSection = true;
        continue;
      }
      if (insideSection) {
        continue;
      }

      model ??= _parseTomlStringAssignment(line: line, key: "model");
      modelProvider ??= _parseTomlStringAssignment(line: line, key: "model_provider");

      if (model != null && modelProvider != null) {
        break;
      }
    }

    return _CodexLocalConfig(model: model, modelProvider: modelProvider);
  }

  String? get _codexHome {
    final explicit = _environment["CODEX_HOME"];
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final home = _environment["HOME"] ?? _environment["USERPROFILE"];
    if (home == null || home.isEmpty) {
      return null;
    }

    return p.join(home, ".codex");
  }

  String? get _sessionsDirectory {
    final codexHome = _codexHome;
    if (codexHome == null) {
      return null;
    }
    return p.join(codexHome, "sessions");
  }

  String? _latestProjectModelProvider({required String projectId}) {
    final sessionsDirectory = _sessionsDirectory;
    if (sessionsDirectory == null) {
      return null;
    }

    DateTime? newestTimestamp;
    String? provider;
    for (final meta in _sessionMetas(sessionsDirectory: sessionsDirectory)) {
      if (meta.cwd != projectId || meta.modelProvider == null) {
        continue;
      }

      if (newestTimestamp == null || meta.timestamp.isAfter(newestTimestamp)) {
        newestTimestamp = meta.timestamp;
        provider = meta.modelProvider;
      }
    }
    return provider;
  }

  String? _sessionModelProvider({required String sessionId}) {
    final sessionsDirectory = _sessionsDirectory;
    if (sessionsDirectory == null) {
      return null;
    }

    for (final meta in _sessionMetas(sessionsDirectory: sessionsDirectory)) {
      if (meta.sessionId == sessionId) {
        return meta.modelProvider;
      }
    }
    return null;
  }

  Iterable<_CodexSessionMeta> _sessionMetas({required String sessionsDirectory}) sync* {
    final directory = Directory(sessionsDirectory);
    if (!directory.existsSync()) {
      return;
    }

    for (final entity in directory.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith(".jsonl")) {
        continue;
      }

      final meta = _readSessionMeta(entity);
      if (meta != null) {
        yield meta;
      }
    }
  }

  _CodexSessionMeta? _readSessionMeta(File file) {
    final lines = file.readAsLinesSync();
    final scanLimit = lines.length < 32 ? lines.length : 32;

    for (var index = 0; index < scanLimit; index++) {
      final line = lines[index].trim();
      if (line.isEmpty) {
        continue;
      }

      try {
        final decoded = jsonDecodeMap(line);
        if (decoded["type"] != "session_meta") {
          continue;
        }

        final payload = decoded["payload"];
        if (payload is! Map<String, dynamic>) {
          continue;
        }

        final sessionId = payload["id"];
        final cwd = payload["cwd"];
        final timestamp = payload["timestamp"];
        if (sessionId is! String || sessionId.isEmpty || cwd is! String || cwd.isEmpty || timestamp is! String) {
          continue;
        }

        final parsedTimestamp = DateTime.tryParse(timestamp);
        if (parsedTimestamp == null) {
          continue;
        }

        return _CodexSessionMeta(
          sessionId: sessionId,
          cwd: cwd,
          modelProvider: _normalizeConfigValue(payload["model_provider"] as String?),
          timestamp: parsedTimestamp,
        );
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  String? _parseTomlStringAssignment({required String line, required String key}) {
    if (!line.startsWith("$key =")) {
      return null;
    }

    final value = line.substring(line.indexOf("=") + 1).trim();
    return _normalizeConfigValue(value);
  }

  String? _normalizeConfigValue(String? rawValue) {
    if (rawValue == null) {
      return null;
    }

    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.length >= 2) {
      final first = trimmed[0];
      final last = trimmed[trimmed.length - 1];
      if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
        final unquoted = trimmed.substring(1, trimmed.length - 1).trim();
        return unquoted.isEmpty ? null : unquoted;
      }
    }

    return trimmed;
  }
}

class CodexSelectionDefaults {
  const CodexSelectionDefaults({
    required this.agent,
    required this.modelId,
    required this.modelProvider,
  });

  final String agent;
  final String? modelId;
  final String? modelProvider;
}

class _CodexLocalConfig {
  const _CodexLocalConfig({
    required this.model,
    required this.modelProvider,
  });

  final String? model;
  final String? modelProvider;
}

class _CodexSessionMeta {
  const _CodexSessionMeta({
    required this.sessionId,
    required this.cwd,
    required this.modelProvider,
    required this.timestamp,
  });

  final String sessionId;
  final String cwd;
  final String? modelProvider;
  final DateTime timestamp;
}
