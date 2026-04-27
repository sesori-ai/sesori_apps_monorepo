import 'dart:async';

import 'server_health_event.dart';
import 'server_lifecycle_service.dart';

enum _State { running, unreachable, restarting, failed }

sealed class _Trigger {
  const _Trigger();
}

class _UnreachableTrigger extends _Trigger {
  final String? message;
  const _UnreachableTrigger({this.message});
}

class _ReachableTrigger extends _Trigger {
  const _ReachableTrigger();
}

class _ProcessExitedTrigger extends _Trigger {
  final int exitCode;
  const _ProcessExitedTrigger({required this.exitCode});
}

class _RestartSuccessTrigger extends _Trigger {
  const _RestartSuccessTrigger();
}

class _RestartFailureTrigger extends _Trigger {
  const _RestartFailureTrigger();
}

class ServerHealthService {
  final ServerLifecycleService _lifecycleService;
  final StreamController<ServerHealthEvent> _eventsController = StreamController<ServerHealthEvent>.broadcast();
  _State _state = _State.running;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _disposed = false;

  ServerHealthService({required ServerLifecycleService lifecycleService}) : _lifecycleService = lifecycleService;

  Stream<ServerHealthEvent> get events => _eventsController.stream;

  void onProcessExited(int exitCode) {
    _transition(_ProcessExitedTrigger(exitCode: exitCode));
  }

  void onServerUnreachable(String? message) {
    _transition(_UnreachableTrigger(message: message));
  }

  void onServerReachable() {
    _transition(const _ReachableTrigger());
  }

  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    await _eventsController.close();
  }

  void _transition(_Trigger trigger) {
    if (_disposed) return;
    switch ((_state, trigger)) {
      case (_State.running, _UnreachableTrigger(:final message)):
        _state = _State.unreachable;
        _eventsController.add(ServerHealthEventUnreachable(message: message));
      case (_State.running, _ProcessExitedTrigger()):
        _state = _State.restarting;
        _attempt = 1;
        _eventsController.add(ServerHealthEventRestarting(attempt: _attempt));
        _scheduleRestart();
      case (_State.unreachable, _ReachableTrigger()):
        _state = _State.running;
        _eventsController.add(const ServerHealthEventRunning());
      case (_State.unreachable, _ProcessExitedTrigger()):
        _state = _State.restarting;
        _attempt = 1;
        _eventsController.add(ServerHealthEventRestarting(attempt: _attempt));
        _scheduleRestart();
      case (_State.restarting, _RestartSuccessTrigger()):
        _state = _State.running;
        _attempt = 0;
        _eventsController.add(const ServerHealthEventRunning());
      case (_State.restarting, _RestartFailureTrigger()):
        if (_attempt < 4) {
          _attempt++;
          _eventsController.add(ServerHealthEventRestarting(attempt: _attempt));
          _scheduleRestart();
        } else {
          _state = _State.failed;
          _eventsController.add(const ServerHealthEventFailed(reason: "Server restart failed after 4 attempts"));
        }
      case (_State.failed, _ReachableTrigger()):
        _state = _State.running;
        _attempt = 0;
        _eventsController.add(const ServerHealthEventRunning());
      default:
        // Ignore invalid transitions
        break;
    }
  }

  void _scheduleRestart() {
    _retryTimer?.cancel();
    final delays = [Duration.zero, const Duration(seconds: 60), const Duration(seconds: 120), const Duration(seconds: 240)];
    final delay = delays[_attempt - 1];
    _retryTimer = Timer(delay, () async {
      if (_disposed) return;
      try {
        await _lifecycleService.restart();
        if (_disposed) return;
        _transition(const _RestartSuccessTrigger());
      } catch (_) {
        if (_disposed) return;
        _transition(const _RestartFailureTrigger());
      }
    });
  }
}
