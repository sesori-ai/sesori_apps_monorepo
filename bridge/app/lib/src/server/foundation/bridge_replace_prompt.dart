import 'terminal_prompt_decision.dart';

/// Asks the user whether an already-running (or still-starting) Sesori bridge
/// should be killed so this one can take its place.
///
/// Two production implementations exist: the standalone bridge asks on the
/// interactive terminal (`TerminalPromptRepository`), while a supervised bridge
/// has no terminal and asks the desktop GUI over the loopback control channel
/// (`ControlPromptService`). [TerminalPromptDecision.nonInteractive] means the
/// question could not be asked at all (no terminal / GUI unreachable), not that
/// the user declined.
abstract class BridgeReplacePrompt {
  /// Shared question copy for both implementations, so the terminal and GUI
  /// paths never drift apart (the terminal appends its own `[y/N]` hint).
  static const String replaceExistingBridgeMessage = 'Another Sesori bridge is already running. Kill it and start fresh?';

  /// See [replaceExistingBridgeMessage].
  static String replaceStartingBridgeMessage({required int holderPid}) =>
      'Another Sesori bridge is still starting up (pid $holderPid). Kill it and start fresh?';

  Future<TerminalPromptDecision> askReplaceExistingBridge({required int bridgeCount});

  Future<TerminalPromptDecision> askReplaceStartingBridge({required int holderPid});
}
