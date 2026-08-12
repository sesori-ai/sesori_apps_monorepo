import "package:meta/meta.dart";

enum AnalyticsLoginProvider({required final String wireValue}) {
  github(wireValue: "github"),
  google(wireValue: "google"),
  apple(wireValue: "apple"),
  email(wireValue: "email");
}

enum AnalyticsLoginFailureKind({required final String wireValue}) {
  authentication(wireValue: "authentication"),
  launch(wireValue: "launch"),
  cancelled(wireValue: "cancelled"),
  timeout(wireValue: "timeout"),
  unknown(wireValue: "unknown");
}

@immutable
sealed class const InstallationAnalyticsEvent() {
  const factory loginAttemptStarted({required AnalyticsLoginProvider provider}) = LoginAttemptStartedEvent;
  const factory loginAttemptCompleted({required AnalyticsLoginProvider provider}) = LoginAttemptCompletedEvent;
  const factory loginAttemptFailed({
    required AnalyticsLoginProvider provider,
    required AnalyticsLoginFailureKind failureKind,
  }) = LoginAttemptFailedEvent;

  String get wireName;
  Map<String, String> get parameters;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstallationAnalyticsEvent &&
          wireName == other.wireName &&
          parameters.length == other.parameters.length &&
          parameters.entries.every((entry) => other.parameters[entry.key] == entry.value);

  @override
  int get hashCode => Object.hash(
    wireName,
    Object.hashAllUnordered(parameters.entries.map((entry) => Object.hash(entry.key, entry.value))),
  );
}

final class const LoginAttemptStartedEvent({required final AnalyticsLoginProvider provider})
    extends InstallationAnalyticsEvent {
  @override
  String get wireName => "login_attempt_started";

  @override
  Map<String, String> get parameters => {"provider": provider.wireValue};
}

final class const LoginAttemptCompletedEvent({required final AnalyticsLoginProvider provider})
    extends InstallationAnalyticsEvent {
  @override
  String get wireName => "login_attempt_completed";

  @override
  Map<String, String> get parameters => {"provider": provider.wireValue};
}

final class const LoginAttemptFailedEvent({
  required final AnalyticsLoginProvider provider,
  required final AnalyticsLoginFailureKind failureKind,
}) extends InstallationAnalyticsEvent {
  @override
  String get wireName => "login_attempt_failed";

  @override
  Map<String, String> get parameters => {
    "provider": provider.wireValue,
    "failure_kind": failureKind.wireValue,
  };
}
