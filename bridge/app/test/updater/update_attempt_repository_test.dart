import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/updater/api/update_attempt_api.dart';
import 'package:sesori_bridge/src/updater/models/update_attempt.dart';
import 'package:sesori_bridge/src/updater/repositories/update_attempt_repository.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late UpdateAttemptRepository repository;

  UpdateAttempt attempt({
    UpdateStage stage = UpdateStage.swapping,
    UpdateAttemptStatus status = UpdateAttemptStatus.inFlight,
    String? reason,
  }) {
    return UpdateAttempt(
      fromVersion: '1.0.0',
      toVersion: '2.0.0',
      startedAt: DateTime.utc(2026, 6, 17, 12),
      stage: stage,
      status: status,
      reason: reason,
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('update-attempt');
    repository = UpdateAttemptRepository(api: UpdateAttemptApi(installRoot: tempDir.path));
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('read returns null when no record exists', () async {
    expect(await repository.readAttempt(), isNull);
  });

  test('save then read roundtrips the record', () async {
    await repository.saveAttempt(attempt: attempt());

    final loaded = await repository.readAttempt();
    expect(loaded, isNotNull);
    expect(loaded!.fromVersion, '1.0.0');
    expect(loaded.toVersion, '2.0.0');
    expect(loaded.stage, UpdateStage.swapping);
    expect(loaded.status, UpdateAttemptStatus.inFlight);
  });

  test('save overwrites with a status transition', () async {
    await repository.saveAttempt(attempt: attempt());
    await repository.saveAttempt(
      attempt: attempt(stage: UpdateStage.activated, status: UpdateAttemptStatus.appliedPendingActivation),
    );

    final loaded = await repository.readAttempt();
    expect(loaded!.status, UpdateAttemptStatus.appliedPendingActivation);
    expect(loaded.stage, UpdateStage.activated);
  });

  test('clear removes the record', () async {
    await repository.saveAttempt(attempt: attempt());
    await repository.clearAttempt();

    expect(await repository.readAttempt(), isNull);
  });

  test('read throws on a corrupt record so the failure stays observable', () async {
    File(p.join(tempDir.path, '.sesori-bridge-update-attempt.json')).writeAsStringSync('{ not json');

    await expectLater(repository.readAttempt(), throwsA(isA<FormatException>()));
  });
}
