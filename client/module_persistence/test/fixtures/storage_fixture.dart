import "dart:async";

import "package:sesori_persistence/sesori_persistence.dart";

class const FixtureSecretKey({@override required final String storageKey}) implements SecretStorageKey;

/// In-memory native-item stand-in. Gates expose actual I/O admission rather than
/// waiting for timers; no OS credentials or application directories are touched.
class FixtureMasterKeyStore({required String? value}) implements MasterKeyStore {
  String? storedValue = value;
  int reads = 0;
  int writes = 0;
  Object? readFailure;
  Object? writeFailure;
  Future<String?>? readResult;
  Future<void>? writeCompletion;
  final readStarted = Completer<void>();
  final writeStarted = Completer<void>();

  @override
  Future<String?> read() async {
    reads++;
    if (!readStarted.isCompleted) readStarted.complete();
    if (readFailure case final Object error) throw error;
    if (readResult case final result?) return await result;
    return storedValue;
  }

  @override
  Future<void> write({required String value}) async {
    writes++;
    if (!writeStarted.isCompleted) writeStarted.complete();
    if (writeFailure case final Object error) throw error;
    if (writeCompletion case final completion?) await completion;
    storedValue = value;
  }
}
