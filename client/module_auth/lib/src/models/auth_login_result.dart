import "package:sesori_shared/sesori_shared.dart";

/// Successful interactive authentication without exposing token ownership.
final class const AuthLoginResult({
  required final AuthUser user,
  required final AccountStatus accountStatus,
});
