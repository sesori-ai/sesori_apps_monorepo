import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/session/session_service.dart";
import "new_session_state.dart";

class NewSessionCubit extends Cubit<NewSessionState> {
  final SessionService _sessionService;
  final String _projectId;

  NewSessionCubit({
    required SessionService sessionService,
    required String projectId,
  }) : _sessionService = sessionService,
       _projectId = projectId,
       super(const NewSessionState.idle());

  Future<void> createSessionWithMessage({
    required String text,
    required String? agent,
    required PromptModel? model,
  }) async {
    if (state is NewSessionSending) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    emit(const NewSessionState.sending());

    final response = await _sessionService.createSessionWithMessage(
      projectId: _projectId,
      text: trimmed,
      agent: agent,
      model: model,
    );

    if (isClosed) return;

    switch (response) {
      case SuccessResponse(:final data):
        emit(NewSessionState.created(session: data));
      case ErrorResponse(:final error):
        emit(NewSessionState.error(message: _describeError(error: error)));
    }
  }

  String _describeError({required ApiError error}) {
    return switch (error) {
      NotAuthenticatedError() => "Authentication required.",
      NonSuccessCodeError(:final rawErrorString) => rawErrorString ?? "Failed to create session.",
      DartHttpClientError() => "Unable to reach server.",
      JsonParsingError() => "Unexpected server response.",
      GenericError() => "Failed to create session.",
    };
  }
}
