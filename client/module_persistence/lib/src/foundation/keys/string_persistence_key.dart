import "package:meta/meta.dart";

/// Identity of a non-secret string value. Declare keys in their domain package.
///
/// Keep [storageKey] stable across releases rather than deriving it from an enum
/// name or ordinal. Account/bridge-scoped values must include their identity.
@immutable
abstract interface class const StringPersistenceKey() {
  String get storageKey;
}
