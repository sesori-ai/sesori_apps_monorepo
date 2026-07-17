import "dart:async";

import "../services/codex_turn_service.dart";

/// Periodically sends traffic while the current app-server connection is live.
class CodexKeepaliveListener {
  CodexKeepaliveListener({
    required CodexTurnService turnService,
    required Duration interval,
  }) : _turnService = turnService,
       _interval = interval;

  final CodexTurnService _turnService;
  final Duration _interval;
  Timer? _timer;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _send());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _send() {
    unawaited(
      _turnService.sendKeepalive(timeout: _interval).catchError((Object _) {}),
    );
  }
}
