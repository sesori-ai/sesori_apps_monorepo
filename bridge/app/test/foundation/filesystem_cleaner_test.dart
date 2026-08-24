import 'dart:io';

import 'package:sesori_bridge/src/foundation/filesystem_cleaner.dart';
import 'package:sesori_plugin_interface/plugin_interface_testing.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log, LogLevel;
import 'package:test/test.dart';

void main() {
  late Directory tempDirectory;

  setUp(() => tempDirectory = Directory.systemTemp.createTempSync('filesystem-cleaner-test-'));
  tearDown(() {
    if (tempDirectory.existsSync()) tempDirectory.deleteSync(recursive: true);
  });

  test('deletes a file and directory', () async {
    final file = File('${tempDirectory.path}/file')..writeAsStringSync('content');
    final directory = Directory('${tempDirectory.path}/directory')..createSync();

    await const FilesystemCleaner().delete(path: file.path, recursive: false);
    await const FilesystemCleaner().delete(path: directory.path, recursive: false);

    expect(file.existsSync(), isFalse);
    expect(directory.existsSync(), isFalse);
  });

  test('deletes dangling symlink without following it', () async {
    if (Platform.isWindows) return;
    final link = Link('${tempDirectory.path}/dangling')..createSync('${tempDirectory.path}/missing');

    await const FilesystemCleaner().delete(path: link.path, recursive: false);

    expect(link.existsSync(), isFalse);
  });

  test('logs cleanup error, stack trace, and path', () async {
    final directory = Directory('${tempDirectory.path}/non-empty')..createSync();
    File('${directory.path}/child').writeAsStringSync('content');
    final output = BufferingStdout();
    final previousLevel = Log.level;
    try {
      Log.level = LogLevel.debug;
      await IOOverrides.runZoned(
        () => const FilesystemCleaner().delete(path: directory.path, recursive: false),
        stderr: () => output,
      );
    } finally {
      Log.level = previousLevel;
    }

    expect(output.text, contains('updater cleanup failed for ${directory.path}'));
    expect(output.text, contains('FileSystemException'));
    expect(output.text, contains('filesystem_cleaner.dart'));
  });
}
