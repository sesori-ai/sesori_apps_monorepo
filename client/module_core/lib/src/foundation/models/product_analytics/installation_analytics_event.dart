import "package:meta/meta.dart";

enum AnalyticsLoginProvider {
  github(wireValue: "github"),
  google(wireValue: "google"),
  apple(wireValue: "apple"),
  email(wireValue: "email");

  final String wireValue;
  const AnalyticsLoginProvider({required this.wireValue});
}

enum AnalyticsLoginFailureKind {
  authentication(wireValue: "authentication"),
  launch(wireValue: "launch"),
  cancelled(wireValue: "cancelled"),
  timeout(wireValue: "timeout"),
  unknown(wireValue: "unknown");

  final String wireValue;
  const AnalyticsLoginFailureKind({required this.wireValue});
}

@immutable
sealed class InstallationAnalyticsEvent {
  const InstallationAnalyticsEvent();

  const factory InstallationAnalyticsEvent.loginAttemptStarted({required AnalyticsLoginProvider provider}) =
      LoginAttemptStartedEvent;
  const factory InstallationAnalyticsEvent.loginAttemptCompleted({required AnalyticsLoginProvider provider}) =
      LoginAttemptCompletedEvent;
  const factory InstallationAnalyticsEvent.loginAttemptFailed({
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
    Object.hashAll(parameters.entries.map((entry) => Object.hash(entry.key, entry.value))),
  );
}

final class LoginAttemptStartedEvent extends InstallationAnalyticsEvent {
  final AnalyticsLoginProvider provider;
  const LoginAttemptStartedEvent({required this.provider});

  @override
  String get wireName => "login_attempt_started";

  @override
  Map<String, String> get parameters => {"provider": provider.wireValue};
}

final class LoginAttemptCompletedEvent extends InstallationAnalyticsEvent {
  final AnalyticsLoginProvider provider;
  const LoginAttemptCompletedEvent({required this.provider});

  @override
  String get wireName => "login_attempt_completed";

  @override
  Map<String, String> get parameters => {"provider": provider.wireValue};
}

final class LoginAttemptFailedEvent extends InstallationAnalyticsEvent {
  final AnalyticsLoginProvider provider;
  final AnalyticsLoginFailureKind failureKind;
  const LoginAttemptFailedEvent({required this.provider, required this.failureKind});

  @override
  String get wireName => "login_attempt_failed";

  @override
  Map<String, String> get parameters => {
    "provider": provider.wireValue,
    "failure_kind": failureKind.wireValue,
  };
}
