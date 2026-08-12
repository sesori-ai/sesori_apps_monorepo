import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../codex_stdio_app_server_client.dart";
import "../repositories/codex_authentication_repository.dart";

class CodexAuthenticationService({
    required CodexStdioAppServerClient client,
    required CodexAuthenticationRepository repository,
    required StartAbortSignal aborted,
    required Duration requestTimeout,
  }) {
  this : _client = client,
       _repository = repository,
       _aborted = aborted,
       _requestTimeout = requestTimeout;

  final CodexStdioAppServerClient _client;
  final CodexAuthenticationRepository _repository;
  final StartAbortSignal _aborted;
  final Duration _requestTimeout;
  late final Future<Never> _abort = _abortOperation();

  Stream<PluginAuthenticationEvent> authenticate() async* {
    try {
      await _abortable(
        _client.connect(
          clientName: "sesori-bridge",
          clientVersion: "0.0.0",
          timeout: _requestTimeout,
        ),
      );
      final challenge = await _abortable(_repository.start());
      yield PluginAuthenticationDeviceCodeChallenge(
        verificationUri: challenge.verificationUri,
        userCode: challenge.userCode,
      );
      await _abortable(
        Future.any<void>([
          _repository.waitForCompletion(),
          _client.processExit.then<void>((exitCode) {
            if (_aborted.isAborted) {
              throw const PluginStartAbortedException();
            }
            throw CodexAuthenticationException(
              message: "Codex App Server exited during device login",
              cause: StateError(
                "Codex App Server exited with code $exitCode",
              ),
            );
          }),
        ]),
      );
      yield const PluginAuthenticationCompleted();
    } on PluginStartAbortedException {
      rethrow;
    } on Object catch (error, stackTrace) {
      final localError = error is CodexAuthenticationException ? error.cause ?? error : error;
      Log.w("[codex] device authentication failed", localError, stackTrace);
      yield const PluginAuthenticationFailed(
        message: "Codex login could not be completed. Retry the login flow.",
      );
    } finally {
      await _repository.dispose();
      await _client.dispose();
    }
  }

  Future<T> _abortable<T>(Future<T> work) {
    if (_aborted.isAborted) {
      return Future<T>.error(const PluginStartAbortedException());
    }
    return Future.any<T>([
      work,
      _abort,
    ]);
  }

  Future<Never> _abortOperation() async {
    await _aborted.whenAborted;
    try {
      await _repository.cancel();
    } on Object catch (error, stackTrace) {
      Log.w("[codex] failed to cancel device authentication", error, stackTrace);
    }
    await _client.dispose();
    throw const PluginStartAbortedException();
  }
}
