import 'package:freezed_annotation/freezed_annotation.dart';

sealed class AuthProvider {
  static const github = GitHubAuthProvider._();
  static const google = GoogleAuthProvider._();
  static const apple = AppleAuthProvider._();
  static const email = EmailAuthProvider._();

  const AuthProvider._();

  static AuthProvider? fromKey(String? key) => switch (true) {
    _ when github.key == key => github,
    _ when google.key == key => google,
    _ when apple.key == key => apple,
    _ when email.key == key => email,
    _ => null,
  };

  String get key => switch (this) {
    GitHubAuthProvider() => "github",
    GoogleAuthProvider() => "google",
    AppleAuthProvider() => "apple",
    EmailAuthProvider() => "email",
  };

  String get label => switch (this) {
    GitHubAuthProvider() => "GitHub",
    GoogleAuthProvider() => "Google",
    AppleAuthProvider() => "Apple",
    EmailAuthProvider() => "Email",
  };

  String get apiAuthPath => switch (this) {
    GitHubAuthProvider() => "auth/github",
    GoogleAuthProvider() => "auth/google",
    AppleAuthProvider() => "auth/apple",
    EmailAuthProvider() => "auth/email",
  };
}

sealed class OAuthProvider extends AuthProvider {
  const OAuthProvider._() : super._();
  String get apiCallbackPath => "$apiAuthPath/callback";
}

@immutable
final class GitHubAuthProvider extends OAuthProvider {
  const GitHubAuthProvider._() : super._();

  @override
  bool operator ==(Object other) {
    return other is GitHubAuthProvider;
  }

  @override
  int get hashCode => key.hashCode;
}

@immutable
final class GoogleAuthProvider extends OAuthProvider {
  const GoogleAuthProvider._() : super._();

  @override
  bool operator ==(Object other) {
    return other is GoogleAuthProvider;
  }

  @override
  int get hashCode => key.hashCode;
}

@immutable
final class AppleAuthProvider extends OAuthProvider {
  const AppleAuthProvider._() : super._();

  @override
  bool operator ==(Object other) {
    return other is AppleAuthProvider;
  }

  @override
  int get hashCode => key.hashCode;
}

@immutable
final class EmailAuthProvider extends AuthProvider {
  const EmailAuthProvider._() : super._();

  @override
  bool operator ==(Object other) {
    return other is EmailAuthProvider;
  }

  @override
  int get hashCode => key.hashCode;
}
