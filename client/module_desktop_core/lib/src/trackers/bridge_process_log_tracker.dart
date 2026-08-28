import "dart:async";
import "dart:collection";
import "dart:convert";

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../api/bridge_process_log_storage.dart";

/// Which child pipe produced a helper log line.
// WORKAROUND: dart_style 3.1.12 crashes on empty enhanced enum constructors in this file.
// ignore: use_primary_constructors
enum BridgeProcessLogSource { stdout, stderr }

/// One line captured from the supervised bridge process.
class const BridgeProcessLogEntry({
  required final DateTime timestamp,
  required final BridgeProcessLogSource source,
  required final String message,
});

/// Reports a local pipe or persistence warning without coupling tests to the
/// global logger implementation.
@visibleForTesting
typedef BridgeProcessLogWarningReporter = void Function({
  required String message,
  required Object error,
  required StackTrace stackTrace,
});

/// Layer-2 owner of the supervised helper's stdout/stderr drain and recent-log
/// state.
///
/// Both pipes are continuously decoded with malformed-byte tolerance, so a
/// chatty or imperfect helper can never block on a full OS pipe. Every line is
/// retained in a last-N in-memory ring and independently offered to rotating
/// Layer-1 storage; storage failures are rate-limited in local logs and never
/// cancel either drain subscription.
@lazySingleton
class BridgeProcessLogTracker.forTesting({
  required final BridgeProcessLogStorage _storage,
  required final int _maxEntries,
  required final Duration _storageWarningInterval,
  required final DateTime Function() _now,
  required final BridgeProcessLogWarningReporter _reportWarning,
}) {
  new({required BridgeProcessLogStorage storage})
    : this.forTesting(
        storage: storage,
        maxEntries: defaultMaxEntries,
        storageWarningInterval: defaultStorageWarningInterval,
        now: DateTime.now,
        reportWarning: _logWarning,
      );

  @visibleForTesting
  this : assert(_maxEntries > 0, "maxEntries must be positive");

  static const int defaultMaxEntries = 200;
  static const Duration defaultStorageWarningInterval = Duration(minutes: 1);

  final ListQueue<BridgeProcessLogEntry> _entries = ListQueue<BridgeProcessLogEntry>();
  final BehaviorSubject<List<BridgeProcessLogEntry>> _entrySnapshots =
      BehaviorSubject<List<BridgeProcessLogEntry>>.seeded(const <BridgeProcessLogEntry>[]);
  final Set<Future<void>> _pendingPersistence = <Future<void>>{};
  CompositeSubscription _subscriptions = CompositeSubscription();
  DateTime? _nextStorageWarningAt;

  List<BridgeProcessLogEntry> get snapshot => List<BridgeProcessLogEntry>.unmodifiable(_entries);

  ValueStream<List<BridgeProcessLogEntry>> get snapshots => _entrySnapshots.stream;

  /// Replaces the current pipe subscriptions with a new child process's raw
  /// byte streams. Cancelling the old subscriptions is awaited before the new
  /// drain starts, so lines from two process generations cannot interleave.
  Future<void> attach({
    required Stream<List<int>> stdout,
    required Stream<List<int>> stderr,
  }) async {
    await _subscriptions.cancel();
    _subscriptions = CompositeSubscription();
    _subscribe(stream: stdout, source: BridgeProcessLogSource.stdout).addTo(_subscriptions);
    _subscribe(stream: stderr, source: BridgeProcessLogSource.stderr).addTo(_subscriptions);
  }

  StreamSubscription<String> _subscribe({
    required Stream<List<int>> stream,
    required BridgeProcessLogSource source,
  }) => const Utf8Decoder(allowMalformed: true)
      .bind(stream)
      .transform(const LineSplitter())
      .listen(
        (line) => _record(source: source, message: line),
        onError: (Object error, StackTrace stackTrace) => _reportWarning(
          message: "Supervised bridge ${source.name} stream failed",
          error: error,
          stackTrace: stackTrace,
        ),
        cancelOnError: false,
      );

  void _record({required BridgeProcessLogSource source, required String message}) {
    final BridgeProcessLogEntry entry = BridgeProcessLogEntry(
      timestamp: _now().toUtc(),
      source: source,
      message: message,
    );
    _entries.addLast(entry);
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
    _entrySnapshots.add(snapshot);

    final Future<void> persistence = _persist(entry: entry);
    _pendingPersistence.add(persistence);
    unawaited(
      persistence.whenComplete(() {
        _pendingPersistence.remove(persistence);
      }),
    );
  }

  Future<void> _persist({required BridgeProcessLogEntry entry}) async {
    try {
      await _storage.appendLine(line: _format(entry: entry));
      _nextStorageWarningAt = null;
    } on Object catch (error, stackTrace) {
      final DateTime now = _now();
      final DateTime? nextWarningAt = _nextStorageWarningAt;
      if (nextWarningAt == null || !now.isBefore(nextWarningAt)) {
        _nextStorageWarningAt = now.add(_storageWarningInterval);
        _reportWarning(
          message: "Failed to persist supervised bridge output; continuing to drain child pipes",
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  static String _format({required BridgeProcessLogEntry entry}) =>
      "${entry.timestamp.toUtc().toIso8601String()} [${entry.source.name}] ${entry.message}";

  static void _logWarning({
    required String message,
    required Object error,
    required StackTrace stackTrace,
  }) => logw(message, error, stackTrace);

  @disposeMethod
  Future<void> dispose() async {
    await _subscriptions.cancel();
    await Future.wait<void>(_pendingPersistence);
    await _entrySnapshots.close();
  }
}
