import "package:meta/meta.dart";

/// Identity of a non-secret bool value, separate from string and secret keys.
///
/// Keep [storageKey] stable across releases rather than deriving it from an enum
/// name or ordinal. The backend owns its physical boolean encoding.
@immutable
abstract interface class const BoolPersistenceKey() {
  String get storageKey;
}
