import "dart:async";

import "package:injectable/injectable.dart";

import "../../core/platform/temporary_directory_client.dart";
import "audio_format_config.dart";

@lazySingleton
class RecordingFileProvider {
  final AudioFormatConfig _audioFormat;
  final TemporaryDirectoryClient _temporaryDirectoryClient;
  final Future<void> _warmUp;

  RecordingFileProvider({
    required AudioFormatConfig audioFormat,
    required TemporaryDirectoryClient temporaryDirectoryClient,
  }) : _audioFormat = audioFormat,
       _temporaryDirectoryClient = temporaryDirectoryClient,
       _warmUp = temporaryDirectoryClient.warmUp() {
    unawaited(_warmUp);
  }

  Future<String> createRecordingPath() async {
    await _warmUp;
    final tempDir = await _temporaryDirectoryClient.directory;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return "${tempDir.path}/sesori_voice_$timestamp.${_audioFormat.fileExtension}";
  }
}
