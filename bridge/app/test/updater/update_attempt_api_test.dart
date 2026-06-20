import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/updater/api/update_attempt_api.dart';
import 'package:sesori_bridge/src/updater/models/update_attempt.dart';
import 'package:test/test.dart';

void main() {
  late Directory installRoot;
  late UpdateAttemptApi api;

  const fileName = '.sesori-bridge-update-attempt.json';
  String recordPath() => p.join(installRoot.path, fileName);
  String tmpPath() => '${recordPath()}.tmp';

  UpdateAttempt attempt({UpdateAttemptStatus status = UpdateAttemptStatus.inFlight}) => UpdateAttempt(
    fromVersion: '1.0.0',
    toVersion: '2.0.0',
    startedAt: DateTime.utc(2026, 6, 17),
    stage: UpdateStage.swapping,
    status: status,
    reason: null,
  );

  setUp(() async {
    installRoot = await Directory.systemTemp.createTemp('update-attempt-api');
    api = UpdateAttemptApi(installRoot: installRoot.path);
  });

  tearDown(() async {
    if (installRoot.existsSync()) {
      await installRoot.delete(recursive: true);
    }
  });

  test('write then read round-trips the attempt', () async {
    await api.write(attempt: attempt());

    final read = await api.read();

    expect(read, isNotNull);
    expect(read!.toVersion, '2.0.0');
    expect(read.status, UpdateAttemptStatus.inFlight);
    // The temp file is renamed into place, never left behind.
    expect(File(tmpPath()).existsSync(), isFalse);
  });

  test('recovers the record from the temp when a crash left the target missing', () async {
    // Simulate a crash in write()'s delete→rename gap: only the flushed temp
    // survives, the target record is gone.
    File(tmpPath()).writeAsStringSync(jsonEncode(attempt(status: UpdateAttemptStatus.appliedPendingActivation).toJson()));
    expect(File(recordPath()).existsSync(), isFalse);

    final read = await api.read();

    expect(read, isNotNull);
    expect(read!.status, UpdateAttemptStatus.appliedPendingActivation);
    // The temp is healed into the record path so subsequent operations are clean.
    expect(File(recordPath()).existsSync(), isTrue);
    expect(File(tmpPath()).existsSync(), isFalse);
  });

  test('returns null when neither the record nor the temp exist', () async {
    expect(await api.read(), isNull);
  });

  test('clear removes both the record and any leftover temp', () async {
    await api.write(attempt: attempt());
    File(tmpPath()).writeAsStringSync('{}'); // a stray temp from an interrupted write

    await api.clear();

    expect(File(recordPath()).existsSync(), isFalse);
    expect(File(tmpPath()).existsSync(), isFalse);
    expect(await api.read(), isNull);
  });
}
