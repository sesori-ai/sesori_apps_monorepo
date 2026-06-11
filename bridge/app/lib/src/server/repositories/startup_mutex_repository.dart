import 'dart:convert';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:sesori_shared/sesori_shared.dart';

import '../api/runtime_file_api.dart';
import '../foundation/process_match.dart';
import '../models/bridge_startup_lock.dart';
import 'process_repository.dart';

class StartupLockRejection {
  const StartupLockRejection({
    required this.lock,
    required this.holderMatch,
    required this.lockFilePath,
  });

  final BridgeStartupLock? lock;
  final ProcessMatch? holderMatch;
  final String lockFilePath;
}

class _LiveStartupLockHolder {
  const _LiveStartupLockHolder({
    required this.lock,
    required this.match,
  });

  final BridgeStartupLock lock;
  final ProcessMatch match;
}

class StartupMutexRepository {
  StartupMutexRepository({
    required RuntimeFileApi runtimeFileApi,
    required ProcessRepository processRepository,
  }) : _runtimeFileApi = runtimeFileApi,
       _processRepository = processRepository;

  final RuntimeFileApi _runtimeFileApi;
  final ProcessRepository _processRepository;

  Future<T> withLock<T>({
    required int bridgePid,
    required String? bridgeStartMarker,
    required Future<T> Function() onLockAcquired,
    required Future<T> Function(StartupLockRejection rejection) onLockRejected,
  }) async {
    final lock = BridgeStartupLock(
      bridgePid: bridgePid,
      bridgeStartMarker: bridgeStartMarker,
    );

    final acquired = await _runtimeFileApi.acquireStartupLock(
      contents: jsonEncode(lock.toJson()),
    );
    if (acquired) {
      try {
        return await onLockAcquired();
      } finally {
        await _runtimeFileApi.releaseStartupLock();
      }
    }

    final holder = await _inspectLiveHolder();
    if (holder == null) {
      final retryAcquired = await _runtimeFileApi.acquireStartupLock(
        contents: jsonEncode(lock.toJson()),
      );
      if (retryAcquired) {
        try {
          return await onLockAcquired();
        } finally {
          await _runtimeFileApi.releaseStartupLock();
        }
      }

      final retryHolder = await _inspectLiveHolder();
      return onLockRejected(
        StartupLockRejection(
          lock: retryHolder?.lock,
          holderMatch: retryHolder?.match,
          lockFilePath: _runtimeFileApi.startupLockFilePath,
        ),
      );
    }

    return onLockRejected(
      StartupLockRejection(
        lock: holder.lock,
        holderMatch: holder.match,
        lockFilePath: _runtimeFileApi.startupLockFilePath,
      ),
    );
  }

  Future<_LiveStartupLockHolder?> _inspectLiveHolder() async {
    final lockContents = await _runtimeFileApi.readStartupLock();
    if (lockContents == null) {
      return null;
    }

    if (lockContents.isEmpty) {
      await _runtimeFileApi.releaseStartupLock();
      return null;
    }

    final BridgeStartupLock lock;
    try {
      lock = BridgeStartupLock.fromJson(
        jsonDecodeMap(lockContents),
      );
    } catch (err, st) {
      Log.w("Failed to parse lockfile to `BridgeStartupLock`", err, st);
      await _runtimeFileApi.releaseStartupLock();
      return null;
    }

    final match = await _processRepository.inspectProcessMatch(pid: lock.bridgePid);
    if (match == null ||
        match.kind != ProcessMatchKind.sesoriBridge ||
        !match.isCurrentUserProcess ||
        !_lockMatchesProcess(lock: lock, match: match)) {
      await _runtimeFileApi.releaseStartupLock();
      return null;
    }

    return _LiveStartupLockHolder(lock: lock, match: match);
  }

  bool _lockMatchesProcess({
    required BridgeStartupLock lock,
    required ProcessMatch match,
  }) {
    final identity = match.identity;
    if (identity.startMarker != null || lock.bridgeStartMarker != null) {
      return identity.startMarker == lock.bridgeStartMarker;
    }
    // Both markers are null (e.g. Windows). We cannot distinguish a recycled
    // PID from the original owner without additional heuristics, so we
    // conservatively treat the lock as active.
    return true;
  }
}
