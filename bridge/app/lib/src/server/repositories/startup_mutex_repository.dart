import 'dart:convert';

import '../api/runtime_file_api.dart';

enum StartupMutexAcquireResult {
  alreadyLocked,
}

class StartupMutexRepository {
  final RuntimeFileApi _runtimeFileApi;

  StartupMutexRepository({required RuntimeFileApi runtimeFileApi})
    : _runtimeFileApi = runtimeFileApi;

  Future<T> withLock<T>({
    required int bridgePid,
    required String? bridgeStartMarker,
    required Future<T> Function() onLockAcquired,
    required Future<T> Function(StartupMutexAcquireResult result) onLockRejected,
  }) async {
    final acquired = await _runtimeFileApi.acquireStartupLock(
      contents: jsonEncode(
        <String, dynamic>{
          'bridgePid': bridgePid,
          'bridgeStartMarker': bridgeStartMarker,
        },
      ),
    );
    if (!acquired) {
      return onLockRejected(StartupMutexAcquireResult.alreadyLocked);
    }

    try {
      return await onLockAcquired();
    } finally {
      await _runtimeFileApi.releaseStartupLock();
    }
  }
}
