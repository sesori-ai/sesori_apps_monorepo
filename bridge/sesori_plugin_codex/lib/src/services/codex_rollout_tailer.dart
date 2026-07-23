import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../api/codex_rollout_api.dart";
import "../api/models/codex_rollout_dto.dart";
import "../repositories/codex_catalog_repository.dart";

class CodexRolloutAppend {
  const CodexRolloutAppend({
    required this.sessionId,
    required this.line,
  });

  final String sessionId;
  final CodexRolloutLineDto line;
}

/// Streams complete records appended to rollouts for turns active in this
/// bridge process.
///
/// COMPATIBILITY 2026-07-23 (Codex app-server 0.144.x): stable item events do
/// not expose every response-item call (notably code-mode `exec` and `wait`),
/// and experimental raw events are disabled when a thread is resumed. Remove
/// this tailer when a stable app-server stream covers raw calls and outputs for
/// both newly started and resumed threads.
class CodexRolloutTailer {
  CodexRolloutTailer({
    required CodexRolloutApi rolloutApi,
    required CodexCatalogRepository catalogRepository,
    required Duration pollInterval,
  }) : _rolloutApi = rolloutApi,
       _catalogRepository = catalogRepository,
       _pollInterval = pollInterval;

  final CodexRolloutApi _rolloutApi;
  final CodexCatalogRepository _catalogRepository;
  final Duration _pollInterval;

  // Synchronous delivery is intentional: a final drain on turn/completed must
  // enqueue tool updates before the plugin emits session.idle. Remove `sync`
  // only if the plugin starts awaiting an ordered async rollout pipeline.
  final StreamController<CodexRolloutAppend> _appends = StreamController<CodexRolloutAppend>.broadcast(sync: true);
  final Map<String, _CodexRolloutCursor> _cursors = {};
  Timer? _timer;

  Stream<CodexRolloutAppend> get appends => _appends.stream;

  void start({required String sessionId}) {
    if (_cursors.containsKey(sessionId)) return;
    final path = _catalogRepository.findRolloutPath(sessionId: sessionId);
    _cursors[sessionId] = _CodexRolloutCursor(
      path: path,
      offset: path == null ? 0 : _rolloutApi.rolloutLength(rolloutPath: path),
      trailingBytes: const [],
    );
    _timer ??= Timer.periodic(_pollInterval, (_) => drainAll());
  }

  void drainAll() {
    for (final sessionId in _cursors.keys.toList(growable: false)) {
      drain(sessionId: sessionId);
    }
  }

  void drain({required String sessionId}) {
    final cursor = _cursors[sessionId];
    if (cursor == null) return;
    var path = cursor.path;
    if (path == null) {
      path = _catalogRepository.findRolloutPath(sessionId: sessionId);
      if (path == null) return;
      cursor.path = path;
    }
    try {
      final chunk = _rolloutApi.readTranscriptChunk(
        rolloutPath: path,
        offset: cursor.offset,
        trailingBytes: cursor.trailingBytes,
      );
      cursor
        ..offset = chunk.nextOffset
        ..trailingBytes = chunk.trailingBytes;
      for (final line in chunk.lines) {
        _appends.add(CodexRolloutAppend(sessionId: sessionId, line: line));
      }
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex] stopped live rollout tail for $sessionId after a read failure",
        error,
        stackTrace,
      );
      stop(sessionId: sessionId);
    }
  }

  void stop({required String sessionId}) {
    _cursors.remove(sessionId);
    if (_cursors.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void stopAll() {
    _cursors.clear();
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    stopAll();
    await _appends.close();
  }
}

class _CodexRolloutCursor {
  _CodexRolloutCursor({
    required this.path,
    required this.offset,
    required this.trailingBytes,
  });

  String? path;
  int offset;
  List<int> trailingBytes;
}
