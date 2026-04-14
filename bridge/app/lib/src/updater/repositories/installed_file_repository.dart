import '../api/file_replacement_api.dart';
import '../models/file_replacement_result.dart';
import '../models/pending_windows_update.dart';

class InstalledFileRepository {
  final FileReplacementApi _fileReplacementApi;

  InstalledFileRepository({required FileReplacementApi fileReplacementApi}) : _fileReplacementApi = fileReplacementApi;

  Future<FileReplacementResult> replaceInstalledFiles({
    required String installRoot,
    required String stagingPath,
  }) {
    return _fileReplacementApi.replaceInstalledFiles(
      installRoot: installRoot,
      stagingPath: stagingPath,
    );
  }

  Future<String> createWindowsSwapScript({
    required PendingWindowsUpdate pendingWindowsUpdate,
    required List<String> args,
  }) {
    return _fileReplacementApi.createWindowsSwapScript(
      pending: pendingWindowsUpdate,
      args: args,
    );
  }
}
