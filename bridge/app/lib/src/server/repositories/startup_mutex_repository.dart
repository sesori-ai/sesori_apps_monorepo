import 'dart:convert';

import '../api/runtime_file_api.dart';
import '../foundation/process_match.dart';
import 'process_repository.dart';

enum StartupMutexAcquireResult {
  alreadyLocked,
}

class StartupMutexRepository {
  StartupMutexRepository({
    required RuntimeFileApi runtimeFileApi,
    required ProcessRepository processRepository,
  })  : _runtimeFileApi = runtimeFileApi,
        _processRepository = processRepository;

  final RuntimeFileApi _runtimeFileApi;
  final ProcessRepository _processRepository;

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
    if (acquired) {
      try {
        return await onLockAcquired();
      } finally {
        await _runtimeFileApi.releaseStartupLock();
      }
    }

    final staleLockCleared = await _clearStaleLockIfAny();
    if (staleLockCleared) {
      final retryAcquired = await _runtimeFileApi.acquireStartupLock(
        contents: jsonEncode(
          <String, dynamic>{
            'bridgePid': bridgePid,
            'bridgeStartMarker': bridgeStartMarker,
          },
        ),
      );
      if (retryAcquired) {
        try {
          return await onLockAcquired();
        } finally {
          await _runtimeFileApi.releaseStartupLock();
        }
      }
    }

    return onLockRejected(StartupMutexAcquireResult.alreadyLocked);
  }

  Future<bool> _clearStaleLockIfAny() async {
    final lockContents = await _runtimeFileApi.readStartupLock();
    if (lockContents == null) {
      return true;
    }

    if (lockContents.isEmpty) {
      return false;
    }

    final int? lockPid;
    try {
      final json = jsonDecode(lockContents) as Map<String, dynamic>;
      lockPid = json['bridgePid'] as int?;
    } on Object {
      await _runtimeFileApi.releaseStartupLock();
      return true;
    }

    if (lockPid == null) {
      await _runtimeFileApi.releaseStartupLock();
      return true;
    }

    final match = await _processRepository.inspectProcessMatch(pid: lockPid);
    if (match == null ||
        match.kind != ProcessMatchKind.sesoriBridge ||
        !match.isCurrentUserProcess) {
      await _runtimeFileApi.releaseStartupLock();
      return true;
    }

    return false;
  }
}
