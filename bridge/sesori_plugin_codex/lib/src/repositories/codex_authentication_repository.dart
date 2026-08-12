import "dart:async";

import "../api/codex_app_server_api.dart";
import "../api/models/codex_account_dto.dart";

final class const CodexAuthenticationChallenge({
  required final Uri verificationUri,
  required final String userCode,
});

final class const CodexAuthenticationException({
  required final String message,
  required final Object? cause,
}) implements Exception {
  @override
  String toString() => "CodexAuthenticationException: $message";
}

/// Owns Codex's private login identifier and completion correlation.
class CodexAuthenticationRepository({
  required final CodexAppServerApi _appServerApi,
  required final Duration _requestTimeout,
}) {
  StreamSubscription<CodexAccountLoginCompletedNotificationDto>? _completionSubscription;
  Completer<void>? _completion;
  String? _loginId;

  Future<CodexAuthenticationChallenge> start() async {
    if (_completion != null) {
      throw StateError("Codex authentication already started");
    }
    final completion = Completer<void>();
    _completion = completion;
    _completionSubscription = _appServerApi.accountLoginCompletions.listen(
      (event) {
        final loginId = _loginId;
        if (loginId == null || event.loginId != loginId || completion.isCompleted) {
          return;
        }
        if (event.success) {
          completion.complete();
        } else {
          completion.completeError(
            CodexAuthenticationException(
              message: "Codex device login did not complete",
              cause: event.error,
            ),
            StackTrace.current,
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completion.isCompleted) {
          completion.completeError(error, stackTrace);
        }
      },
    );

    final response = await _appServerApi.startDeviceLogin(
      timeout: _requestTimeout,
    );
    _loginId = response.loginId;
    final verificationUri = Uri.tryParse(response.verificationUrl);
    if (verificationUri == null || verificationUri.scheme != "https" || verificationUri.host.isEmpty) {
      throw const CodexAuthenticationException(
        message: "Codex returned an invalid device verification URL",
        cause: null,
      );
    }
    return CodexAuthenticationChallenge(
      verificationUri: verificationUri,
      userCode: response.userCode,
    );
  }

  Future<void> waitForCompletion() {
    final completion = _completion;
    if (completion == null) {
      throw StateError("Codex authentication has not started");
    }
    return completion.future;
  }

  Future<void> cancel() async {
    final loginId = _loginId;
    if (loginId == null) return;
    await _appServerApi.cancelLogin(
      loginId: loginId,
      timeout: _requestTimeout,
    );
  }

  Future<void> dispose() async {
    await _completionSubscription?.cancel();
    _completionSubscription = null;
  }
}
