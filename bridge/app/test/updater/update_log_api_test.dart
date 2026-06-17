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

  test('redacts github tokens, full authorization credentials, and key=value secrets', () async {
    final api = UpdateLogApi(installRoot: tempDir.path, clock: clock);

    await api.append(message: 'using ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123 to fetch');
    await api.append(message: 'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload.signature failed');
    await api.append(message: 'url https://x/cb?access_token=secretvalue123456&x=1');
    await api.append(message: '{"token": "jsonsecretvalue999", "ok": true}');
    await api.append(message: 'Authorization: Digest username="bob", response=digestsecretabcdef, nonce=zzz');

    final contents = readLog(tempDir.path);
    // No secret value of any kind survives.
    expect(contents, isNot(contains('ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123')));
    expect(contents, isNot(contains('eyJhbGciOiJIUzI1NiJ9.payload.signature')));
    expect(contents, isNot(contains('secretvalue123456')));
    expect(contents, isNot(contains('jsonsecretvalue999')));
    // Every parameter of a multi-param Authorization header is redacted.
    expect(contents, isNot(contains('digestsecretabcdef')));
    // The whole bearer credential is redacted, not just the scheme.
    expect(contents, contains('[REDACTED_TOKEN]'));
    expect(contents, contains('Authorization: [REDACTED]'));
    expect(contents, contains('access_token=[REDACTED]'));
    // Colon/JSON-delimited token fields are redacted too.
    expect(contents, contains('token=[REDACTED]'));
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
