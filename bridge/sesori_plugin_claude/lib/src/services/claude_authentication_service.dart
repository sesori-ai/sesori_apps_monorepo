import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/claude_pasted_code.dart";
import "../repositories/claude_authentication_repository.dart";

/// Runs one Claude Code login as a pasted-code operation.
///
/// The CLI never exits on its own, so two budgets bound it: the sign-in URL
/// must appear within [_urlBudget], and the CLI must exit within
/// [_overallBudget] of spawning.
final class ClaudeAuthenticationService({
  required final ClaudeAuthenticationRepository _repository,
  required final StartAbortSignal _aborted,
  final Duration _urlBudget = const Duration(seconds: 90),
  final Duration _overallBudget = const Duration(minutes: 10),
}) {
  final Completer<void> _rejectedCode = Completer<void>();

  PluginAuthenticationOperation authenticate() =>
      PluginAuthenticationOperation.pastedCode(events: _events(), submitCode: _submitCode);

  Stream<PluginAuthenticationPastedCodeEvent> _events() async* {
    try {
      final abort = _aborted.whenAborted.then<Never>((_) => throw const PluginStartAbortedException());
      final elapsed = Stopwatch()..start();
      // `timeout` cancels its timer once a wait settles, so no budget outlives the login.
      final authorizationUri = await _within(
        work: Future.any([_repository.start(), abort]),
        budget: _urlBudget,
        stage: "print a sign-in URL",
      );
      yield PluginAuthenticationPastedCodeChallenge(authorizationUri: authorizationUri);
      final rejected = _rejectedCode.future.then<Never>(
        (_) => throw ClaudeAuthenticationException(message: "The pasted code is not a code#state pair"),
      );
      final exitCode = await _within(
        work: Future.any([_repository.waitForExit(), abort, rejected]),
        budget: _overallBudget - elapsed.elapsed,
        stage: "exit",
      );
      if (exitCode != 0) {
        throw ClaudeAuthenticationException(message: "Claude Code login exited with code $exitCode");
      }
      yield const PluginAuthenticationCompleted();
    } on PluginStartAbortedException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Log.w("[claude] login failed; stderr tail:\n${_repository.stderrTail}", error, stackTrace);
      yield const PluginAuthenticationFailed(message: "Claude Code login could not be completed.");
    } finally {
      await _repository.dispose();
    }
  }

  Future<void> _submitCode({required String code}) async {
    final pastedCode = ClaudePastedCode.tryParse(raw: code);
    if (pastedCode == null) {
      // The running exit wait fails the operation, which then stops the CLI.
      _rejectedCode.complete();
      return;
    }
    await _repository.submitCode(code: pastedCode);
  }

  Future<T> _within<T>({required Future<T> work, required Duration budget, required String stage}) =>
      work.timeout(budget, onTimeout: () => throw TimeoutException("Claude Code login did not $stage in time"));
}
