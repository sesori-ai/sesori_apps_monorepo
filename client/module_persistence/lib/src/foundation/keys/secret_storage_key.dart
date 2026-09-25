import "package:meta/meta.dart";

/// Identity of a protected value, not accepted by plaintext primitive access.
///
/// Keep [storageKey] stable across releases rather than deriving it from an enum
/// name or ordinal. The platform selects the secure backend, not the caller.
@immutable
abstract interface class const SecretStorageKey() {
  String get storageKey;
}
