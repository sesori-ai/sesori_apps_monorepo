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
  Future<TerminalPromptDecision> askReplaceExistingBridge({required int bridgeCount});

  Future<TerminalPromptDecision> askReplaceStartingBridge({required int holderPid});
}
