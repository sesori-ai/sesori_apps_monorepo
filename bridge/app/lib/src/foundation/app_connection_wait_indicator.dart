import "dart:async";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, TerminalColorValidator, TerminalGlyphValidator;

/// Renders the post-onboarding wait for the first usable phone connection.
///
/// Interactive capable terminals receive an in-place spinner. Redirected or
/// limited terminals receive one static status line instead, so the bridge's
/// state remains understandable without ANSI cursor control.
class AppConnectionWaitIndicator {
  AppConnectionWaitIndicator({
    required Stdout out,
    required Map<String, String> environment,
    required Duration frameInterval,
  }) : _out = out,
       _frameInterval = frameInterval,
       _unicode = TerminalGlyphValidator.isSupported(environment: environment),
       _animated = _canAnimate(out: out, environment: environment);

  static const String waitingMessage = "Waiting for Sesori on your phone to connect";
  static const String staticWaitingMessage =
      "Waiting for Sesori on your phone to connect. The bridge is already running.";
  static const String connectedMessage = "Sesori connected on your phone.";
  static const List<String> _unicodeFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
  static const List<String> _asciiFrames = ["|", "/", "-", r"\"];
  static const int _animatedLineWidth = waitingMessage.length + 2;

  final Stdout _out;
  final Duration _frameInterval;
  final bool _unicode;
  final bool _animated;

  Timer? _timer;
  int _frameIndex = 0;
  bool _started = false;
  bool _stopped = false;
  bool _drewAnimatedLine = false;
  bool _writeFailed = false;

  void start() {
    if (_started) {
      throw StateError("App connection wait indicator has already started");
    }
    _started = true;

    if (!_animated) {
      _write(text: "$staticWaitingMessage\n");
      return;
    }

    _drawFrame();
    if (_writeFailed || _stopped) return;
    _timer = Timer.periodic(_frameInterval, (_) => _drawFrame());
  }

  /// Stops animation and optionally replaces the waiting state with success.
  void stop({required bool connected}) {
    if (!_started || _stopped) return;
    _stopped = true;
    _timer?.cancel();

    if (_drewAnimatedLine) {
      _write(text: "\r\x1b[2K");
    }
    if (connected) {
      final prefix = _unicode ? "✓ " : "";
      _write(text: "$prefix$connectedMessage\n");
    }
  }

  void _drawFrame() {
    if (_stopped || _writeFailed) return;
    final frames = _unicode ? _unicodeFrames : _asciiFrames;
    final frame = frames[_frameIndex % frames.length];
    _frameIndex += 1;
    if (_write(text: "\r$frame $waitingMessage")) {
      _drewAnimatedLine = true;
    }
  }

  bool _write({required String text}) {
    if (_writeFailed) return false;
    try {
      _out.write(text);
      return true;
    } on Object catch (error, stackTrace) {
      _writeFailed = true;
      _timer?.cancel();
      Log.w("Disabling the phone connection indicator after stdout failed", error, stackTrace);
      return false;
    }
  }

  static bool _canAnimate({required Stdout out, required Map<String, String> environment}) {
    if (!TerminalColorValidator.isSupported(out: out, environment: environment)) {
      return false;
    }
    try {
      return out.hasTerminal && out.terminalColumns >= _animatedLineWidth;
    } on Object {
      return false;
    }
  }
}
