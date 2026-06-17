import 'dart:io';

import 'package:clock/clock.dart';
import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/updater/api/update_log_api.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  final clock = Clock.fixed(DateTime.utc(2026, 6, 17, 12, 30, 45));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('update-log-api');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  String readLog(String installRoot) {
    return File(p.join(installRoot, '.sesori-bridge-update.log')).readAsStringSync();
  }

  test('append writes a timestamped line', () async {
    final api = UpdateLogApi(installRoot: tempDir.path, clock: clock);

    await api.append(message: 'staging started');

    final contents = readLog(tempDir.path);
    expect(contents, contains('2026-06-17T12:30:45'));
    expect(contents, contains('staging started'));
    expect(contents.endsWith('\n'), isTrue);
  });

  test('appendAttemptHeader records the version transition', () async {
    final api = UpdateLogApi(installRoot: tempDir.path, clock: clock);

    await api.appendAttemptHeader(fromVersion: '1.0.0', toVersion: '2.0.0');

    expect(readLog(tempDir.path), contains('update attempt 1.0.0 -> 2.0.0'));
  });

  test('redacts tokens and authorization values', () async {
    final api = UpdateLogApi(installRoot: tempDir.path, clock: clock);

    await api.append(
      message: 'auth failed Authorization: Bearer ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123 token=secretvalue123456',
    );

    final contents = readLog(tempDir.path);
    expect(contents, isNot(contains('ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123')));
    expect(contents, isNot(contains('secretvalue123456')));
    expect(contents, contains('[REDACTED_TOKEN]'));
    expect(contents, contains('[REDACTED]'));
  });

  test('rotates to .log.1 once the cap is exceeded', () async {
    final api = UpdateLogApi(installRoot: tempDir.path, clock: clock, maxBytes: 60);

    await api.append(message: 'first entry that is reasonably long');
    await api.append(message: 'second entry that triggers a rotation');

    final rotated = File(p.join(tempDir.path, '.sesori-bridge-update.log.1'));
    expect(rotated.existsSync(), isTrue);
    expect(rotated.readAsStringSync(), contains('first entry'));
    expect(readLog(tempDir.path), contains('second entry'));
    expect(readLog(tempDir.path), isNot(contains('first entry')));
  });
}
