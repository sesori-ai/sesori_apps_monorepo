import 'dart:io';

import '../api/file_replacement_api.dart';
import '../models/file_replacement_result.dart';
import '../models/pending_windows_update.dart';

class InstalledFileRepository {
  final FileReplacementApi _fileReplacementApi;
  PendingWindowsUpdate? _pendingWindowsUpdate;

  InstalledFileRepository({required FileReplacementApi fileReplacementApi}) : _fileReplacementApi = fileReplacementApi;

  PendingWindowsUpdate? get pendingWindowsUpdate => _pendingWindowsUpdate;

  Future<bool> replaceInstalledFiles({
    required String installRoot,
    required String stagingPath,
  }) async {
    final FileReplacementResult result = await _fileReplacementApi.replaceInstalledFiles(
      installRoot: installRoot,
      stagingPath: stagingPath,
    );

    if (Platform.isWindows) {
      _pendingWindowsUpdate = result.pendingWindowsUpdate;
      return result.success;
    }

    _pendingWindowsUpdate = null;
    return result.success;
  }

  Future<String> createWindowsSwapScript({required List<String> args}) {
    return _fileReplacementApi.createWindowsSwapScript(
      pending: _pendingWindowsUpdate!,
      args: args,
    );
  }
}
