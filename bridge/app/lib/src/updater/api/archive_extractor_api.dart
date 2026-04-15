import 'dart:io';

import '../../bridge/foundation/process_runner.dart';

class ArchiveExtractorApi {
  final ProcessRunner _processRunner;

  ArchiveExtractorApi({required ProcessRunner processRunner}) : _processRunner = processRunner;

  Future<bool> extract({
    required String archivePath,
    required String stagingPath,
  }) async {
    final Directory stagingDir = Directory(stagingPath);
    if (stagingDir.existsSync()) {
      stagingDir.deleteSync(recursive: true);
    }
    stagingDir.createSync(recursive: true);

    if (Platform.isWindows) {
      final String psArchive = archivePath.replaceAll("'", "''");
      final String psStaging = stagingPath.replaceAll("'", "''");
      final ProcessResult result = await _processRunner.run(
        'powershell',
        [
          '-Command',
          "Expand-Archive -LiteralPath '$psArchive' -DestinationPath '$psStaging' -Force",
        ],
      );
      return result.exitCode == 0;
    }

    final ProcessResult result = await _processRunner.run(
      'tar',
      ['-xzf', archivePath, '-C', stagingPath],
    );
    return result.exitCode == 0;
  }
}
