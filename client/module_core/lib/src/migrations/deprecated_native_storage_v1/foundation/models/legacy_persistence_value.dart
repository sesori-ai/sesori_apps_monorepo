import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_persistence/sesori_persistence.dart";

part "legacy_persistence_value.freezed.dart";

/// Retain the exact source spelling for cleanup, independently of the typed
/// destination key. Never include imported payloads in diagnostic presentation.
@Freezed(copyWith: false, toStringOverride: false)
sealed class LegacyPersistenceValue with _$LegacyPersistenceValue {
  const factory string({
    required String sourceKey,
    required StringPersistenceKey key,
    required String value,
  }) = LegacyStringValue;

  const factory boolean({
    required String sourceKey,
    required BoolPersistenceKey key,
    required bool value,
  }) = LegacyBoolValue;

  const factory secret({
    required String sourceKey,
    required SecretStorageKey key,
    required String value,
  }) = LegacySecretValue;
}
