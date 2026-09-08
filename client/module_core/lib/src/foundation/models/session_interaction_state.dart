import "package:meta/meta.dart";
import "package:sesori_auth/sesori_auth.dart";

enum SessionInteractionBlockedReason() {
  disabled,
  authenticationRequired,
  runtimeMissing,
  unavailable,
  stopping,
  notInspected,
  unknownStatus,
  missingHarness,
  statusCheckFailed,
  contentLoadFailed,
}

@immutable
sealed class const SessionInteractionState() {
  const factory available({required ApiError? refreshError}) = SessionInteractionAvailable;
  const factory checking() = SessionInteractionChecking;
  const factory legacyUnverified() = SessionInteractionLegacyUnverified;
  const factory blocked({
    required SessionInteractionBlockedReason reason,
    required String? displayName,
    required String? actionHint,
    required ApiError? refreshError,
  }) = SessionInteractionBlocked;

  bool get canInteract => this is SessionInteractionAvailable || this is SessionInteractionLegacyUnverified;
}

final class const SessionInteractionAvailable({required final ApiError? refreshError}) extends SessionInteractionState {
  @override
  bool operator ==(Object other) => other is SessionInteractionAvailable && other.refreshError == refreshError;

  @override
  int get hashCode => refreshError.hashCode;
}

final class const SessionInteractionChecking() extends SessionInteractionState {
  @override
  bool operator ==(Object other) => other is SessionInteractionChecking;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class const SessionInteractionLegacyUnverified() extends SessionInteractionState {
  @override
  bool operator ==(Object other) => other is SessionInteractionLegacyUnverified;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class const SessionInteractionBlocked({
  required final SessionInteractionBlockedReason reason,
  required final String? displayName,
  required final String? actionHint,
  required final ApiError? refreshError,
}) extends SessionInteractionState {
  @override
  bool operator ==(Object other) =>
      other is SessionInteractionBlocked &&
      other.reason == reason &&
      other.displayName == displayName &&
      other.actionHint == actionHint &&
      other.refreshError == refreshError;

  @override
  int get hashCode => Object.hash(reason, displayName, actionHint, refreshError);
}
