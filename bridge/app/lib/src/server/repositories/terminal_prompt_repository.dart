import '../api/terminal_prompt_api.dart';
import '../foundation/terminal_prompt_decision.dart';

class TerminalPromptRepository {
  TerminalPromptRepository({required TerminalPromptApi api}) : _api = api;

  final TerminalPromptApi _api;

  Future<TerminalPromptDecision> askReplaceExistingBridge({required int bridgeCount}) async {
    if (!_api.isInteractive) {
      return TerminalPromptDecision.nonInteractive;
    }

    final rawAnswer = _api.readLine(
      message: 'Another Sesori bridge is already running. Kill it and start fresh? [y/N]',
    );
    final answer = rawAnswer?.trim().toLowerCase();
    if (answer == 'y' || answer == 'yes') {
      return TerminalPromptDecision.replace;
    }
    return TerminalPromptDecision.decline;
  }

  ({String email, String password}) promptForEmailCredentials() {
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
