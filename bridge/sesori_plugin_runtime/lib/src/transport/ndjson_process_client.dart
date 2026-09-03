import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

// Decoded JSON values are heterogeneous at transport boundary.
typedef JsonObject = Map<String, Object?>; // ignore: no_slop_linter/prefer_specific_type
// Correlation IDs are opaque JSON scalar values owned by plugin protocol.
typedef NdjsonCorrelationId = Object? Function(JsonObject frame); // ignore: no_slop_linter/prefer_specific_type
// Exit failures stay plugin-typed across transport boundary.
typedef NdjsonExitError = Object Function(int exitCode); // ignore: no_slop_linter/prefer_specific_type
// Long-running requests may define which uncorrelated inbound frames prove
// progress and therefore restart their inactivity deadline.
typedef NdjsonActivityMatcher = bool Function(JsonObject frame);

enum MalformedFramePolicy() {
  discard,
  failPending,
}

enum NonObjectFramePolicy() {
  discard,
  failPending,
}

enum MalformedFrameLogPolicy() {
  metadataOnly,
  sanitizedContent,
}

enum StderrPolicy() {
  discard,
  forwardSanitized,
}

abstract interface class NdjsonProcessHandle() {
  IOSink get stdin;
  Stream<String> get stdoutLines;
  Stream<String> get stderrLines;
  Future<int> get done;
  Future<void> kill({required bool force});
}

final class AttachToken._(final int generation);

final class NdjsonDispatch({required final Future<JsonObject> response});

final class _PendingResponse({
  required final Completer<JsonObject> completer,
  required final Duration timeout,
  required final NdjsonActivityMatcher? activityMatcher,
}) {
  Timer? timer;
}

final class NdjsonProcessClient({
  required final NdjsonCorrelationId _responseCorrelationId,
  required final NdjsonExitError _exitError,
  required final MalformedFramePolicy _malformedFramePolicy,
  required final NonObjectFramePolicy _nonObjectFramePolicy,
  required final MalformedFrameLogPolicy _malformedFrameLogPolicy,
  required final StderrPolicy _stderrPolicy,
  required final String Function(String) _sanitizeForLog,
  required final String _logTag,
  required final Duration _reapTimeout,
}) {
  // JSON correlation IDs are intentionally opaque protocol boundary values.
  final Map<Object, _PendingResponse> _pending = {}; // ignore: no_slop_linter/prefer_specific_type
  final StreamController<JsonObject> _notifications = StreamController.broadcast();

  NdjsonProcessHandle? _process;
  // Client owns and cancels both subscriptions during every teardown path.
  // ignore: cancel_subscriptions
  StreamSubscription<String>? _stdoutSubscription;
  // Client owns and cancels both subscriptions during every teardown path.
  // ignore: cancel_subscriptions
  StreamSubscription<String>? _stderrSubscription;
  Completer<int> _exit = Completer<int>();
  Future<void>? _teardownFuture;
  int _generation = 0;
  bool _disposed = false;

  Stream<JsonObject> get notifications => _notifications.stream;
  Future<int> get exit => _exit.future;
  bool get isAttached => _process != null && !_exit.isCompleted && !_disposed;

  AttachToken beginAttach() {
    if (_disposed) throw StateError("NdjsonProcessClient is disposed");
    if (_process != null || _teardownFuture != null) {
      throw StateError("NdjsonProcessClient is already attached or tearing down");
    }
    return AttachToken._(++_generation);
  }

  Future<void> attach({required AttachToken token, required NdjsonProcessHandle process}) async {
    if (_disposed || token.generation != _generation || _process != null || _teardownFuture != null) {
      await _reap(process: process);
      throw StateError(
        _disposed ? "NdjsonProcessClient disposed during attach" : "NdjsonProcessClient attach superseded",
      );
    }
    _process = process;
    _exit = Completer<int>();
    final exit = _exit;
    unawaited(process.stdin.done.catchError((Object _) {}));
    final generation = token.generation;
    _stdoutSubscription = process.stdoutLines.listen(
      (line) {
        if (generation == _generation) _handleLine(line: line);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (generation != _generation) return;
        Log.w("[$_logTag] stdout stream error", error, stackTrace);
        _failPending(error: error, stackTrace: stackTrace);
      },
      cancelOnError: false,
    );
    _stderrSubscription = process.stderrLines.listen(
      (line) {
        if (generation != _generation) return;
        if (_stderrPolicy == StderrPolicy.forwardSanitized) {
          Log.d("[$_logTag][stderr] ${_sanitizeForLog(line)}");
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (generation == _generation) Log.w("[$_logTag] stderr stream error", error, stackTrace);
      },
      cancelOnError: false,
    );
    unawaited(
      process.done.then(
        (code) {
          if (!exit.isCompleted) exit.complete(code);
          if (generation != _generation) return;
          _failPending(error: _exitError(code), stackTrace: StackTrace.current);
          if (!_disposed) Log.w("[$_logTag] process exited with code $code");
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!exit.isCompleted) exit.completeError(error, stackTrace);
          if (generation != _generation) return;
          _failPending(error: error, stackTrace: stackTrace);
        },
      ),
    );
  }

  Future<JsonObject> request({
    // JSON correlation IDs are intentionally opaque protocol boundary values.
    required Object id, // ignore: no_slop_linter/prefer_specific_type
    required JsonObject frame,
    required Duration timeout,
  }) async {
    final dispatched = await dispatch(id: id, frame: frame, timeout: timeout);
    return await dispatched.response;
  }

  Future<NdjsonDispatch> dispatch({
    // JSON correlation IDs are intentionally opaque protocol boundary values.
    required Object id, // ignore: no_slop_linter/prefer_specific_type
    required JsonObject frame,
    required Duration timeout,
  }) => _dispatch(
    id: id,
    frame: frame,
    timeout: timeout,
    activityMatcher: null,
  );

  /// Dispatches a request whose [timeout] measures inbound inactivity rather
  /// than total wall time. Only frames accepted by [activityMatcher] restart
  /// the deadline, so unrelated concurrent work cannot keep it alive.
  Future<NdjsonDispatch> dispatchWithInactivityTimeout({
    // JSON correlation IDs are intentionally opaque protocol boundary values.
    required Object id, // ignore: no_slop_linter/prefer_specific_type
    required JsonObject frame,
    required Duration timeout,
    required NdjsonActivityMatcher activityMatcher,
  }) => _dispatch(
    id: id,
    frame: frame,
    timeout: timeout,
    activityMatcher: activityMatcher,
  );

  Future<NdjsonDispatch> _dispatch({
    // JSON correlation IDs are intentionally opaque protocol boundary values.
    required Object id, // ignore: no_slop_linter/prefer_specific_type
    required JsonObject frame,
    required Duration timeout,
    required NdjsonActivityMatcher? activityMatcher,
  }) async {
    final process = _requireProcess();
    final pending = _PendingResponse(
      completer: Completer<JsonObject>(),
      timeout: timeout,
      activityMatcher: activityMatcher,
    );
    _pending[id] = pending;
    _armTimeout(id: id, pending: pending);
    try {
      sendFrame(frame: frame);
    } on Object catch (error, stackTrace) {
      final failed = _removePending(id);
      if (failed != null && !failed.completer.isCompleted) {
        failed.completer.completeError(error, stackTrace);
      }
      rethrow;
    }
    final response = pending.completer.future;
    response.ignore();
    try {
      await process.stdin.flush();
    } on Object catch (error, stackTrace) {
      final failed = _removePending(id);
      if (failed != null && !failed.completer.isCompleted) {
        failed.completer.completeError(error, stackTrace);
      }
      rethrow;
    }
    return NdjsonDispatch(response: response);
  }

  void sendFrame({required JsonObject frame}) {
    final process = _requireProcess();
    process.stdin.add(utf8.encode("${jsonEncode(frame)}\n"));
  }

  NdjsonProcessHandle _requireProcess() {
    final process = _process;
    if (process == null || _exit.isCompleted) throw StateError("NdjsonProcessClient is not attached");
    return process;
  }

  void _armTimeout({
    // JSON correlation IDs are intentionally opaque protocol boundary values.
    required Object id, // ignore: no_slop_linter/prefer_specific_type
    required _PendingResponse pending,
  }) {
    pending.timer?.cancel();
    pending.timer = Timer(pending.timeout, () {
      if (!identical(_pending[id], pending)) return;
      _pending.remove(id);
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(
          TimeoutException("No matching process activity", pending.timeout),
          StackTrace.current,
        );
      }
    });
  }

  // JSON correlation IDs are intentionally opaque protocol boundary values.
  // ignore: no_slop_linter/prefer_specific_type
  _PendingResponse? _removePending(Object id) {
    final pending = _pending.remove(id);
    pending?.timer?.cancel();
    return pending;
  }

  void _handleLine({required String line}) {
    if (line.trim().isEmpty) return;
    final Object? decoded; // ignore: no_slop_linter/prefer_specific_type
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      final suffix = switch (_malformedFrameLogPolicy) {
        MalformedFrameLogPolicy.metadataOnly => "",
        MalformedFrameLogPolicy.sanitizedContent => ": ${_sanitizeForLog(line)}",
      };
      Log.w("[$_logTag] ignored malformed stdout frame$suffix");
      if (_malformedFramePolicy == MalformedFramePolicy.failPending) {
        _failPending(error: StateError("$_logTag returned malformed JSON"), stackTrace: StackTrace.current);
      }
      return;
    }
    if (decoded is! Map) {
      Log.d("[$_logTag] ignored non-object stdout frame");
      if (_nonObjectFramePolicy == NonObjectFramePolicy.failPending) {
        _failPending(error: StateError("$_logTag returned non-object JSON"), stackTrace: StackTrace.current);
      }
      return;
    }
    final frame = <String, Object?>{}; // ignore: no_slop_linter/prefer_specific_type
    for (final entry in decoded.entries) {
      switch (entry) {
        case MapEntry(:final key, :final value) when key is String:
          frame[key] = value;
        default:
          Log.d("[$_logTag] ignored object with non-string key");
          return;
      }
    }
    final id = _responseCorrelationId(frame);
    if (id != null) {
      final pending = _removePending(id);
      if (pending != null) {
        pending.completer.complete(frame);
        return;
      }
    }
    for (final entry in _pending.entries) {
      final activityMatcher = entry.value.activityMatcher;
      if (activityMatcher != null && activityMatcher(frame)) {
        _armTimeout(id: entry.key, pending: entry.value);
      }
    }
    if (!_notifications.isClosed) _notifications.add(frame);
  }

  void _failPending({
    // Errors remain opaque so plugin-specific typed failures retain identity.
    required Object error, // ignore: no_slop_linter/prefer_specific_type
    required StackTrace stackTrace,
  }) {
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final response in pending) {
      response.timer?.cancel();
      if (!response.completer.isCompleted) response.completer.completeError(error, stackTrace);
    }
  }

  Future<void> reset({
    // Teardown reasons remain opaque so callers can preserve typed failures.
    required Object reason, // ignore: no_slop_linter/prefer_specific_type
    required Duration gracefulTimeout,
  }) {
    if (_disposed) return Future.value();
    return _startTeardown(reason: reason, gracefulTimeout: gracefulTimeout, closeNotifications: false);
  }

  Future<void> dispose({
    // Teardown reasons remain opaque so callers can preserve typed failures.
    required Object reason, // ignore: no_slop_linter/prefer_specific_type
    required Duration gracefulTimeout,
  }) {
    _disposed = true;
    return _startTeardown(reason: reason, gracefulTimeout: gracefulTimeout, closeNotifications: true);
  }

  Future<void> _startTeardown({
    // Teardown reasons remain opaque so callers can preserve typed failures.
    required Object reason, // ignore: no_slop_linter/prefer_specific_type
    required Duration gracefulTimeout,
    required bool closeNotifications,
  }) {
    final active = _teardownFuture;
    if (active != null) {
      return closeNotifications ? active.whenComplete(_closeNotifications) : active;
    }
    final teardown = _teardown(reason: reason, gracefulTimeout: gracefulTimeout);
    _teardownFuture = teardown;
    return teardown.whenComplete(() async {
      _teardownFuture = null;
      if (closeNotifications) await _closeNotifications();
    });
  }

  Future<void> _closeNotifications() async {
    if (!_notifications.isClosed) await _notifications.close();
  }

  Future<void> _teardown({
    // Teardown reasons remain opaque so callers can preserve typed failures.
    required Object reason, // ignore: no_slop_linter/prefer_specific_type
    required Duration gracefulTimeout,
  }) async {
    _generation++;
    final process = _process;
    _process = null;
    final stdoutSubscription = _stdoutSubscription;
    _stdoutSubscription = null;
    final stderrSubscription = _stderrSubscription;
    _stderrSubscription = null;
    _failPending(error: reason, stackTrace: StackTrace.current);
    if (process != null) {
      try {
        await process.stdin.close().timeout(gracefulTimeout);
      } on Object catch (error, stackTrace) {
        Log.w("[$_logTag] failed to close process stdin", error, stackTrace);
      }
      await _kill(process: process, force: false);
      if (!await _waitForExit(process: process, timeout: gracefulTimeout)) {
        await _kill(process: process, force: true);
        await _waitForExit(process: process, timeout: gracefulTimeout);
      }
    }
    await _cancel(subscription: stdoutSubscription, streamName: "stdout");
    await _cancel(subscription: stderrSubscription, streamName: "stderr");
  }

  Future<bool> _waitForExit({required NdjsonProcessHandle process, required Duration timeout}) async {
    try {
      await process.done.timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    } on Object catch (error, stackTrace) {
      Log.w("[$_logTag] failed while awaiting process exit", error, stackTrace);
      return true;
    }
  }

  Future<void> _kill({required NdjsonProcessHandle process, required bool force}) async {
    try {
      await process.kill(force: force);
    } on Object catch (error, stackTrace) {
      Log.w("[$_logTag] failed to stop process", error, stackTrace);
    }
  }

  Future<void> _reap({required NdjsonProcessHandle process}) async {
    await _kill(process: process, force: true);
    await _waitForExit(process: process, timeout: _reapTimeout);
  }

  Future<void> _cancel({required StreamSubscription<String>? subscription, required String streamName}) async {
    try {
      await subscription?.cancel();
    } on Object catch (error, stackTrace) {
      Log.w("[$_logTag] failed to cancel $streamName subscription", error, stackTrace);
    }
  }
}
