import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/bridge/foundation/post_update_restart_flag.dart';
import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:sesori_bridge/src/updater/api/file_replacement_api.dart';
import 'package:sesori_bridge/src/updater/models/pending_windows_update.dart';
import 'package:test/test.dart';

void main() {
  group('FileReplacementApi', () {
    test('Windows swap script sets post-update env flag before Start-Process', () async {
      final tempDir = await Directory.systemTemp.createTemp('file-replacement-api-test-');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final api = FileReplacementApi(processRunner: _FakeProcessRunner());
      final scriptPath = await api.createWindowsSwapScript(
        pending: PendingWindowsUpdate(
          installRoot: tempDir.path,
          stagingPath: p.join(tempDir.path, 'staging'),
          archivePath: p.join(tempDir.path, 'archive.zip'),
          lockPath: p.join(tempDir.path, 'update.lock'),
        ),
        args: const <String>['run'],
      );

      final script = await File(scriptPath).readAsString();
      const envLine = "${r'$env:'}$sesoriPostUpdateRestartEnvVar = '1'";
      final envIndex = script.indexOf(envLine);
      final startIndex = script.indexOf(r'Start-Process -FilePath $binaryPath -ArgumentList $args');

      expect(envIndex, isNonNegative);
      expect(startIndex, isNonNegative);
      expect(envIndex, lessThan(startIndex));
    });
  });
}

class _FakeProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 15),
  }) {
    throw UnimplementedError();
  }
}
