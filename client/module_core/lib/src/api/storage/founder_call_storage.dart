import "dart:convert";

import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../../foundation/models/founder_call/founder_call_progress.dart";
import "../../foundation/persistence/persistence_keys.dart";
import "../../logging/logging.dart";

const _storageVersion = 1;

/// Device-scoped CEO call invitation progress, one versioned JSON value that
/// survives sign-out and account switches.
@lazySingleton
class FounderCallStorage({required final PersisterRepository _persister}) {
  /// The stored progress, or null when none is stored or it is unreadable.
  Future<FounderCallStoredProgress?> read() async {
    final value = await _persister.readString(key: StringPreferenceKey.founderCall);
    if (value == null) return null;
    try {
      return switch (jsonDecodeMap(value)) {
        {"version": _storageVersion, "kind": "armed"} => const FounderCallArmed(),
        {"version": _storageVersion, "kind": "retired"} => const FounderCallRetired(),
        _ => throw FormatException("Invalid stored founder call progress", value),
      };
    } on Object catch (error, stackTrace) {
      // The device then reads as never armed, so the invitation stays quiet.
      logw("Discarding unreadable founder call progress", error, stackTrace);
      return null;
    }
  }

  Future<void> write({required FounderCallStoredProgress progress}) => _persister.writeString(
    key: StringPreferenceKey.founderCall,
    value: jsonEncode(switch (progress) {
      FounderCallArmed() => {"version": _storageVersion, "kind": "armed"},
      FounderCallRetired() => {"version": _storageVersion, "kind": "retired"},
    }),
  );
}
