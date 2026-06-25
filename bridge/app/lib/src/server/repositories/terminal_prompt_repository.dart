import '../api/terminal_prompt_api.dart';
import '../foundation/terminal_prompt_decision.dart';

class TerminalPromptRepository {
  TerminalPromptRepository({required TerminalPromptApi api}) : _api = api;

  final TerminalPromptApi _api;

  Future<TerminalPromptDecision> askReplaceExistingBridge({required int bridgeCount}) async {
    return _askYesNo(
      message: 'Another Sesori bridge is already running. Kill it and start fresh? [y/N]',
    );
  }

  Future<TerminalPromptDecision> askReplaceStartingBridge({required int holderPid}) async {
    return _askYesNo(
      message: 'Another Sesori bridge is still starting up (pid $holderPid). Kill it and start fresh? [y/N]',
    );
  }

  Future<TerminalPromptDecision> askStopBridgesBeforeLogout({required int bridgeCount}) async {
    return _askYesNo(
      message: '$bridgeCount bridge instance(s) are currently running. Stop them before logging out? [y/N]',
    );
  }

  Future<TerminalPromptDecision> _askYesNo({required String message}) async {
    if (!_api.isInteractive) {
      return TerminalPromptDecision.nonInteractive;
    }

    final rawAnswer = _api.readLine(message: message);
    final answer = rawAnswer?.trim().toLowerCase();
    if (answer == 'y' || answer == 'yes') {
      return TerminalPromptDecision.replace;
    }
    return TerminalPromptDecision.decline;
  }

  ({String email, String password}) promptForEmailCredentials() {
    if (!_api.isInteractive) {
      // No usable terminal (e.g. a legacy post-update relaunch): fail with clear
      // guidance instead of blocking on stdin for credentials no one can enter.
      throw Exception(
        'Email login required, but no interactive terminal is available. '
        'Run sesori-bridge again from a terminal to log in.',
      );
    }

    final email = _api.readLine(message: "Email: ");
    if (email == null) {
      throw Exception('EOF reached while reading email');
    }

    final password = _api.readLine(
      message: "Password: ",
      disableEcho: true, // to not print the pwd to console as user is writing
    );
    if (password == null) {
      throw Exception('EOF reached while reading password');
    }

    return (email: email, password: password);
  }
}
