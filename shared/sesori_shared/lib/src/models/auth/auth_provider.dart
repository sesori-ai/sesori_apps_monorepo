import 'package:freezed_annotation/freezed_annotation.dart';

sealed class const AuthProvider._() {
  static const github = GitHubAuthProvider._();
  static const google = GoogleAuthProvider._();
  static const apple = AppleAuthProvider._();
  static const email = EmailAuthProvider._();

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

sealed class const OAuthProvider._() extends AuthProvider {
  this : super._();
  String get apiCallbackPath => "$apiAuthPath/callback";
}

@immutable
final class const GitHubAuthProvider._() extends OAuthProvider {
  this : super._();

  @override
  bool operator ==(Object other) {
    return other is GitHubAuthProvider;
  }

  @override
  int get hashCode => key.hashCode;
}

@immutable
final class const GoogleAuthProvider._() extends OAuthProvider {
  this : super._();

  @override
  bool operator ==(Object other) {
    return other is GoogleAuthProvider;
  }

  @override
  int get hashCode => key.hashCode;
}

@immutable
final class const AppleAuthProvider._() extends OAuthProvider {
  this : super._();

  @override
  bool operator ==(Object other) {
    return other is AppleAuthProvider;
  }

  @override
  int get hashCode => key.hashCode;
}

@immutable
final class const EmailAuthProvider._() extends AuthProvider {
  this : super._();

  @override
  bool operator ==(Object other) {
    return other is EmailAuthProvider;
  }

  @override
  int get hashCode => key.hashCode;
}
