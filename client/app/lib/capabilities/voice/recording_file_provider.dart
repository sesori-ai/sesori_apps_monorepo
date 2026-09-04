import "dart:async";

import "package:injectable/injectable.dart";

import "../../core/platform/temporary_directory_client.dart";
import "audio_format_config.dart";

@lazySingleton
class RecordingFileProvider({
  required final AudioFormatConfig _audioFormat,
  required final TemporaryDirectoryClient _temporaryDirectoryClient,
}) {
  final Future<void> _warmUp = _temporaryDirectoryClient.warmUp();
  final int _providerInstanceId = DateTime.now().microsecondsSinceEpoch;
  int _nextRecordingId = 0;

  this {
    unawaited(_warmUp);
  }

  Future<String> createRecordingPath() async {
    await _warmUp;
    final tempDir = await _temporaryDirectoryClient.directory;
    final recordingId = _nextRecordingId++;
    return "${tempDir.path}/sesori_voice_${_providerInstanceId}_$recordingId.${_audioFormat.fileExtension}";
  }
}
