import "dart:async";

import "package:injectable/injectable.dart";

import "../../core/platform/temporary_directory_client.dart";
import "audio_format_config.dart";

@lazySingleton
class RecordingFileProvider {
  final AudioFormatConfig _audioFormat;
  final TemporaryDirectoryClient _temporaryDirectoryClient;

  RecordingFileProvider({
    required AudioFormatConfig audioFormat,
    required TemporaryDirectoryClient temporaryDirectoryClient,
  }) : _audioFormat = audioFormat,
       _temporaryDirectoryClient = temporaryDirectoryClient {
    unawaited(_temporaryDirectoryClient.warmUp());
  }

  Future<String> createRecordingPath() async {
    final tempDir = await _temporaryDirectoryClient.directory;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return "${tempDir.path}/sesori_voice_$timestamp.${_audioFormat.fileExtension}";
  }
}
