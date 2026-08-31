import "dart:async";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/capabilities/voice/audio_format_config.dart";
import "package:sesori_mobile/capabilities/voice/recording_file_provider.dart";
import "package:sesori_mobile/core/platform/temporary_directory_client.dart";

void main() {
  test("reuses the app-wide cached temporary directory", () async {
    var directoryLoads = 0;
    final temporaryDirectoryClient = TemporaryDirectoryClient.forTesting(
      load: () async {
        directoryLoads++;
        return Directory("/tmp/sesori-recording-file-provider-test");
      },
    );
    final provider = RecordingFileProvider(
      audioFormat: AudioFormatConfig.forPlatform(isWeb: false),
      temporaryDirectoryClient: temporaryDirectoryClient,
    );

    final [firstPath, secondPath] = await Future.wait([
      provider.createRecordingPath(),
      provider.createRecordingPath(),
    ]);

    expect(firstPath, startsWith("/tmp/sesori-recording-file-provider-test/sesori_voice_"));
    expect(firstPath, endsWith(".m4a"));
    expect(secondPath, startsWith("/tmp/sesori-recording-file-provider-test/sesori_voice_"));
    expect(secondPath, isNot(firstPath));
    expect(directoryLoads, 1);
  });

  test("retries when recording starts as eager warm-up fails", () async {
    final firstLoad = Completer<Directory>();
    final recoveredDirectory = Directory("/tmp/sesori-recording-file-provider-recovered");
    var directoryLoads = 0;
    final temporaryDirectoryClient = TemporaryDirectoryClient.forTesting(
      load: () {
        directoryLoads++;
        return directoryLoads == 1 ? firstLoad.future : Future.value(recoveredDirectory);
      },
    );
    final provider = RecordingFileProvider(
      audioFormat: AudioFormatConfig.forPlatform(isWeb: false),
      temporaryDirectoryClient: temporaryDirectoryClient,
    );

    final path = provider.createRecordingPath();
    firstLoad.completeError(StateError("temporary directory unavailable"));

    expect(await path, startsWith("${recoveredDirectory.path}/sesori_voice_"));
    expect(directoryLoads, 2);
  });
}
