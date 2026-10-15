import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../foundation/models/form_draft_value.dart";
import "../../services/pending_form_service.dart";
import "pending_form_state.dart";

/// One modal's editable drafts; the existing pending list owns native settlement.
class PendingFormCubit({
  required final PendingFormService _service,
  required final ConnectionService _connectionService,
  required final String requestId,
  required final String sessionId,
}) extends Cubit<PendingFormState> {
  this : super(const FormLoading()) {
    _origin = _connectionService.currentStatus;
    _subscription = _connectionService.status.listen((status) {
      if (!_sameConnection(status: status)) _retire();
    });
    unawaited(refresh());
  }
  late final ConnectionStatus _origin;
  late final StreamSubscription<ConnectionStatus> _subscription;

  bool _sameConnection({required ConnectionStatus status}) => switch ((_origin, status)) {
    (ConnectionConnected(config: final original), ConnectionConnected(config: final current)) => original == current,
    _ => false,
  };

  bool get _active {
    final current = state;
    return !isClosed &&
        current is! FormDisconnected &&
        (current is! FormReady || current.connection == FormConnectionOwnership.active) &&
        _sameConnection(status: _connectionService.currentStatus);
  }

  bool get canSubmit {
    final current = state;
    return _active &&
        current is FormReady &&
        current.submission is! FormSubmitting &&
        _service.supportsSubmission(form: current.form);
  }

  void _retire() {
    if (isClosed) return;
    final current = state;
    if (current is FormReady) {
      emit(current.retire());
    } else if (current is! FormSettled) {
      emit(const FormDisconnected());
    }
  }

  Future<void> refresh() async {
    if (!_active) {
      _retire();
      return;
    }
    if (state is FormReady || state is FormSettled) return;
    emit(const FormLoading());
    try {
      final form = await _service.read(requestId: requestId, sessionId: sessionId);
      if (!_active || state is! FormLoading) return;
      emit(
        form == null
            ? const FormNoLongerPending()
            : FormReady(
                form: form,
                drafts: _service.initialDrafts(form: form),
                submission: const FormSubmissionIdle(),
                connection: FormConnectionOwnership.active,
              ),
      );
      // ApiError is an expected transport failure despite extending Error.
      // ignore: avoid_catching_errors
    } on ApiError catch (error) {
      if (_active && state is FormLoading) emit(FormReadFailed(cause: error));
    }
  }

  void edit({required String fieldId, required FormDraftValue? draft}) {
    final current = state;
    if (!_active || current is! FormReady || current.submission is FormSubmitting) return;
    final drafts = {...current.drafts};
    if (draft == null) {
      drafts.remove(fieldId);
    } else {
      drafts[fieldId] = draft;
    }
    FormSubmission submission = const FormSubmissionIdle();
    if (current.submission case FormSubmissionInvalid(:final fieldErrors)) {
      final remaining = {...fieldErrors}..remove(fieldId);
      if (remaining.isNotEmpty) submission = FormSubmissionInvalid(fieldErrors: remaining);
    }
    emit(current.withDrafts(drafts: drafts, submission: submission));
  }

  Future<void> submit() => _reply(intent: FormSubmissionIntent.submit);

  Future<void> decline({required FormDismissalChoice choice}) {
    if (choice == FormDismissalChoice.unknown) {
      final current = state;
      if (_active && current is FormReady && current.submission is! FormSubmitting) {
        emit(
          current.withSubmission(submission: const FormSubmissionRefused(reason: FormRefusalReason.unsupportedChoice)),
        );
      }
      return Future<void>.value();
    }
    return switch (choice) {
      FormDismissalChoice.decline => _reply(intent: FormSubmissionIntent.decline),
      FormDismissalChoice.cancel => _reply(intent: FormSubmissionIntent.cancel),
      FormDismissalChoice.unknown => Future<void>.value(),
    };
  }

  Future<void> _reply({required FormSubmissionIntent intent}) async {
    final current = state;
    if (!_active || current is! FormReady || current.submission is FormSubmitting) return;
    emit(current.withSubmission(submission: FormSubmitting(intent: intent)));
    try {
      final result = await switch (intent) {
        FormSubmissionIntent.submit => _service.submit(form: current.form, drafts: current.drafts),
        FormSubmissionIntent.decline => _service.decline(form: current.form, choice: FormDismissalChoice.decline),
        FormSubmissionIntent.cancel => _service.decline(form: current.form, choice: FormDismissalChoice.cancel),
      };
      final latest = state;
      if (!_active || latest is! FormReady) return;
      switch (result) {
        case FormReplyAccepted():
          emit(FormReplySent(intent: intent));
        case FormAlreadySettled():
          emit(const FormNoLongerPending());
        case FormValidationFailed(:final fieldErrors):
          emit(latest.withSubmission(submission: FormSubmissionInvalid(fieldErrors: fieldErrors)));
        case FormReplyUnknown():
          emit(
            latest.withSubmission(submission: const FormSubmissionRefused(reason: FormRefusalReason.unknownResponse)),
          );
        case FormUnsupportedChoice():
          emit(
            latest.withSubmission(submission: const FormSubmissionRefused(reason: FormRefusalReason.unsupportedChoice)),
          );
      }
      // ApiError is an expected transport failure despite extending Error.
      // ignore: avoid_catching_errors
    } on ApiError catch (error) {
      if (state case final FormReady ready when _active) {
        emit(ready.withSubmission(submission: FormSubmissionFailed(cause: error)));
      }
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
