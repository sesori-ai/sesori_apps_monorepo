import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../platform/url_launcher.dart";
import "../../services/session_external_action_service.dart";
import "session_external_action_state.dart";

/// One modal observes one request; closing it leaves native work untouched.
class SessionExternalActionCubit({
  required final SessionExternalActionService _service,
  required final ConnectionService _connectionService,
  required final UrlLauncher _urlLauncher,
  required final String requestId,
  required final String sessionId,
}) extends Cubit<SessionExternalActionState> {
  this : super(const ExternalActionLoading()) {
    _origin = _connectionService.currentStatus;
    _subscription = _connectionService.status.listen((status) {
      if (!_sameConnection(status: status) && !isClosed) emit(const ExternalActionDisconnected());
    });
    unawaited(refresh());
  }
  late final ConnectionStatus _origin;
  late final StreamSubscription<ConnectionStatus> _subscription;

  bool _sameConnection({required ConnectionStatus status}) => switch ((_origin, status)) {
    (ConnectionConnected(config: final original), ConnectionConnected(config: final current)) => original == current,
    _ => false,
  };
  bool get _active =>
      !isClosed && state is! ExternalActionDisconnected && _sameConnection(status: _connectionService.currentStatus);

  Future<void> refresh() async {
    if (!_active) {
      if (!isClosed) emit(const ExternalActionDisconnected());
      return;
    }
    if (state is ExternalActionReady || state is ExternalActionSettled) return;
    emit(const ExternalActionLoading());
    try {
      final action = await _service.read(requestId: requestId, sessionId: sessionId);
      if (!_active) return;
      emit(
        action == null
            ? const ExternalActionNoLongerPending()
            : ExternalActionReady(
                action: action,
                destination: _service.browserDestination(action: action),
                submission: const ExternalActionSubmissionIdle(),
                browser: const ExternalActionBrowserIdle(),
              ),
      );
      // ApiError models expected transport failures despite extending Error.
      // ignore: avoid_catching_errors
    } on ApiError catch (error) {
      if (_active) emit(ExternalActionReadFailed(cause: error));
    }
  }

  Future<void> reply({required ExternalActionChoice choice}) async {
    final current = state;
    if (!_active || current is! ExternalActionReady || current.submission is ExternalActionSubmitting) return;
    emit(current.withSubmission(submission: ExternalActionSubmitting(choice: choice)));
    try {
      final result = await _service.reply(action: current.action, choice: choice);
      final latest = state;
      if (!_active || latest is! ExternalActionReady) return;
      switch (result) {
        case ExternalActionReplyAccepted():
          emit(ExternalActionReplySent(choice: choice));
        case ExternalActionAlreadySettled():
          emit(const ExternalActionNoLongerPending());
        case ExternalActionReplyUnknown() || ExternalActionUnsupportedChoice():
          emit(latest.withSubmission(submission: ExternalActionSubmissionRefused(result: result)));
      }
      // ApiError models expected transport failures despite extending Error.
      // ignore: avoid_catching_errors
    } on ApiError catch (error) {
      if (state case final ExternalActionReady ready when _active) {
        emit(ready.withSubmission(submission: ExternalActionSubmissionFailed(cause: error)));
      }
    }
  }

  Future<void> openBrowser() async {
    final current = state;
    if (!_active ||
        current is! ExternalActionReady ||
        current.browser is ExternalActionBrowserOpening ||
        current.submission is ExternalActionSubmitting) {
      return;
    }
    final url = current.destination;
    if (url == null) return;
    emit(current.withBrowser(browser: const ExternalActionBrowserOpening()));
    try {
      final opened = await _urlLauncher.launch(url, mode: UrlLaunchMode.externalApp);
      final latest = state;
      if (!_active || latest is! ExternalActionReady) return;
      emit(
        latest.withBrowser(
          browser: opened
              ? const ExternalActionBrowserOpened()
              : ExternalActionBrowserFailed(
                  cause: ExternalLinkLaunchFailure(url: url, innerError: StateError("Browser did not open")),
                  stackTrace: StackTrace.current,
                ),
        ),
      );
    } on Object catch (error, stackTrace) {
      if (state case final ExternalActionReady ready when _active) {
        emit(
          ready.withBrowser(
            browser: ExternalActionBrowserFailed(
              cause: ExternalLinkLaunchFailure(url: url, innerError: error),
              stackTrace: stackTrace,
            ),
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
