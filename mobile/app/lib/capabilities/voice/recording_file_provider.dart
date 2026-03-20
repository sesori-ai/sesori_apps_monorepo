import "package:injectable/injectable.dart";
import "package:path_provider/path_provider.dart";

import "audio_format_config.dart";

@lazySingleton
class RecordingFileProvider {
  final AudioFormatConfig _audioFormat;

  RecordingFileProvider(AudioFormatConfig audioFormat) : _audioFormat = audioFormat;

  Future<String> createRecordingPath() async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return "${tempDir.path}/sesori_voice_$timestamp.${_audioFormat.fileExtension}";
  }
}
