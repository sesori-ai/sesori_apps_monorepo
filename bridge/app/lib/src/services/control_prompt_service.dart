import "dart:async";
import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show ControlMessage, ControlPromptKind;

import "../foundation/control_channel_client.dart";
import "../server/foundation/bridge_replace_prompt.dart";
import "../server/foundation/terminal_prompt_decision.dart";

/// Supervised-mode user prompts over the loopback control channel: the desktop
/// GUI, not an interactive terminal, answers the bridge's questions. This is
/// the supervised counterpart of `TerminalPromptRepository` for the
/// replace-bridge questions — both implement [BridgeReplacePrompt] and the
/// composition root picks one by mode.
///
/// It owns the prompt-class correlation state and ALL prompt-class outbound
/// sends: an ask sends an id-correlated [ControlMessage.promptRequest] and
/// awaits the matching [ControlMessage.promptResponse], which the
/// `BridgeControlMessageDispatcher` (the single inbound subscriber) delivers via
/// [handlePromptResponse]. An unanswerable ask — channel down, GUI not replying
/// within the timeout, or teardown mid-flight — degrades to
/// [TerminalPromptDecision.nonInteractive], mirroring the terminal path's
/// "couldn't ask" semantics, and is logged since the transport failure is
/// otherwise swallowed into a decision.
class ControlPromptService implements BridgeReplacePrompt {
  /// A human answers these through a GUI dialog, so the wait is generous —
  /// unlike the token pull's machine-speed timeout.
  static const Duration _defaultResponseTimeout = Duration(minutes: 2);

  final ControlChannelClient _client;
  final Duration _responseTimeout;
  final Map<String, Completer<bool>> _pending = <String, Completer<bool>>{};
  int _nextId = 0;
  bool _disposed = false;

  ControlPromptService({
    required ControlChannelClient client,
    Duration responseTimeout = _defaultResponseTimeout,
  })  : _client = client,
        _responseTimeout = responseTimeout;

  @override
  Future<TerminalPromptDecision> askReplaceExistingBridge({required int bridgeCount}) {
    return _ask(
      kind: ControlPromptKind.replaceBridge,
      message: "Another Sesori bridge is already running. Kill it and start fresh?",
    );
  }

  @override
  Future<TerminalPromptDecision> askReplaceStartingBridge({required int holderPid}) {
    return _ask(
      kind: ControlPromptKind.replaceBridge,
      message: "Another Sesori bridge is still starting up (pid $holderPid). Kill it and start fresh?",
    );
  }

  /// Best-effort heads-up that the bridge needs the user to log in (the GUI
  /// could not supply a token at bootstrap). Fire-and-forget: no response is
  /// awaited — the authoritative signal is the auth-required exit sentinel; this
  /// prompt is advisory, so a send failure is logged and swallowed.
  void announceLoginNeeded() {
    final id = "prompt-${_nextId++}";
    try {
      _client.send(
        jsonEncode(
          ControlMessage.promptRequest(
            id: id,
            kind: ControlPromptKind.loginNeeded,
            message: "Sign in to the Sesori desktop app to start the bridge.",
          ).toJson(),
        ),
      );
    } on ControlChannelNotConnectedException catch (error) {
      Log.w("[control][prompt] could not announce login-needed — control channel down", error);
    }
  }

  /// Delivers the GUI's answer to a pending ask. Called by the control-message
  /// dispatcher (the single inbound subscriber); answers for unknown or
  /// already-resolved ids are ignored (e.g. a reply arriving after the timeout).
  void handlePromptResponse({required String id, required bool accepted}) {
    final completer = _pending.remove(id);
    if (completer != null && !completer.isCompleted) {
      completer.complete(accepted);
    }
  }

  /// Resolves any in-flight asks as [TerminalPromptDecision.nonInteractive] so
  /// shutdown never hangs on the response timeout.
  Future<void> dispose() async {
    _disposed = true;
    final pending = List<Completer<bool>>.of(_pending.values);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        // Resolved via the completer's normal path; _ask maps the sentinel to
        // nonInteractive. Using the decision (not an error) keeps teardown quiet.
        completer.complete(false);
      }
    }
  }

  Future<TerminalPromptDecision> _ask({
    required ControlPromptKind kind,
    required String message,
  }) async {
    if (_disposed) {
      return TerminalPromptDecision.nonInteractive;
    }
    final id = "prompt-${_nextId++}";
    final completer = Completer<bool>();
    _pending[id] = completer;
    try {
      try {
        _client.send(
          jsonEncode(ControlMessage.promptRequest(id: id, kind: kind, message: message).toJson()),
        );
      } on ControlChannelNotConnectedException catch (error) {
        // The GUI is unreachable (outage / mid-reconnect): the question cannot
        // be asked. Degrade like a non-interactive terminal; logged because the
        // transport failure is otherwise swallowed into a decision.
        Log.w("[control][prompt] could not send prompt — control channel down", error);
        return TerminalPromptDecision.nonInteractive;
      }
      final accepted = await completer.future.timeout(_responseTimeout);
      // A dispose-resolved completer answers false; distinguish it from a real
      // decline so teardown reads as "couldn't ask", not "user said no".
      if (_disposed) {
        return TerminalPromptDecision.nonInteractive;
      }
      return accepted ? TerminalPromptDecision.replace : TerminalPromptDecision.decline;
    } on TimeoutException {
      Log.w("[control][prompt] no answer from the desktop app within ${_responseTimeout.inSeconds}s");
      return TerminalPromptDecision.nonInteractive;
    } finally {
      _pending.remove(id);
    }
  }
}
