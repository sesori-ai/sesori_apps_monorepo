import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "new_session_state.freezed.dart";

@Freezed()
sealed class NewSessionState with _$NewSessionState {
  const factory NewSessionState.idle() = NewSessionIdle;

  const factory NewSessionState.sending() = NewSessionSending;

  const factory NewSessionState.error({required String message}) = NewSessionError;

  const factory NewSessionState.created({required Session session}) = NewSessionCreated;
}
