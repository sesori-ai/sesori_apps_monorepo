import 'privacy_deletion_models.dart';
import 'privacy_deletion_repository.dart';

final class PrivacyDeletionService {
  const PrivacyDeletionService({required PrivacyDeletionRepository repository})
    : _repository = repository;

  final PrivacyDeletionRepository _repository;

  Future<PrivacyDeletionSummary> runRequest({
    required PrivacyRequestId requestId,
    required bool dryRun,
  }) async {
    PrivacyDeletionTarget? target;
    var cleanup = const CleanupResult.none();
    AuthExportReadiness? readiness;
    try {
      target = await _repository.loadTarget(requestId: requestId);
      if (target.status == PrivacyDeletionTargetStatus.completed) {
        return PrivacyDeletionSummary(
          operation: PrivacyDeletionOperationKind.request,
          outcome: PrivacyDeletionOutcome.alreadyCompleted,
          dryRun: dryRun,
          targetsConsidered: 1,
          authExportReadiness: AuthExportReadiness.ready,
          cleanup: cleanup,
          failureKind: null,
        );
      }

      await _repository.prepareTarget(target: target, dryRun: dryRun);
      cleanup = cleanup.add(
        other: await _cleanupTarget(
          target: target,
          phase: PrivacyDeletionCleanupPhase.preliminary,
          dryRun: dryRun,
        ),
      );
      readiness = await _repository.checkTombstoneAwareAuthExport(
        suppressedAt: target.suppressedAt,
      );

      if (dryRun) {
        if (readiness == AuthExportReadiness.ready) {
          await _repository.validateWarehouseInventory(
            allowAuthStagingTables: false,
          );
          cleanup = cleanup.add(
            other: await _cleanupTarget(
              target: target,
              phase: PrivacyDeletionCleanupPhase.finalPass,
              dryRun: true,
            ),
          );
          await _repository.validateWarehouseInventory(
            allowAuthStagingTables: false,
          );
        }
        return PrivacyDeletionSummary(
          operation: PrivacyDeletionOperationKind.request,
          outcome: PrivacyDeletionOutcome.planned,
          dryRun: true,
          targetsConsidered: 1,
          authExportReadiness: readiness,
          cleanup: cleanup,
          failureKind: null,
        );
      }

      if (readiness == AuthExportReadiness.notReady) {
        final failure = PrivacyDeletionOperationException(
          failureKind: PrivacyDeletionFailureKind.authExportNotReady,
          operation: PrivacyDeletionOperation.readAuthExport,
          innerError: const AuthExportCutoffNotReadyException(),
          innerStackTrace: StackTrace.current,
        );
        return _recoverRequestFailure(
          target: target,
          failure: failure,
          cleanup: cleanup,
          readiness: readiness,
        );
      }

      await _repository.validateWarehouseInventory(
        allowAuthStagingTables: false,
      );
      cleanup = cleanup.add(
        other: await _cleanupTarget(
          target: target,
          phase: PrivacyDeletionCleanupPhase.finalPass,
          dryRun: false,
        ),
      );
      await _repository.validateWarehouseInventory(
        allowAuthStagingTables: false,
      );
      await _repository.markCompleted(requestId: target.requestId);
      return PrivacyDeletionSummary(
        operation: PrivacyDeletionOperationKind.request,
        outcome: PrivacyDeletionOutcome.completed,
        dryRun: false,
        targetsConsidered: 1,
        authExportReadiness: readiness,
        cleanup: cleanup,
        failureKind: null,
      );
    } on PrivacyDeletionOperationException catch (error) {
      if (target == null || dryRun) {
        return PrivacyDeletionSummary(
          operation: PrivacyDeletionOperationKind.request,
          outcome: PrivacyDeletionOutcome.retryable,
          dryRun: dryRun,
          targetsConsidered: target == null ? 0 : 1,
          authExportReadiness: readiness,
          cleanup: cleanup,
          failureKind: error.failureKind,
        );
      }
      return _recoverRequestFailure(
        target: target,
        failure: error,
        cleanup: cleanup,
        readiness: readiness,
      );
    } catch (error, stackTrace) {
      final failure = PrivacyDeletionOperationException(
        failureKind: PrivacyDeletionFailureKind.unexpected,
        operation: PrivacyDeletionOperation.verifyDeletion,
        innerError: error,
        innerStackTrace: stackTrace,
      );
      if (target == null || dryRun) {
        return PrivacyDeletionSummary(
          operation: PrivacyDeletionOperationKind.request,
          outcome: PrivacyDeletionOutcome.retryable,
          dryRun: dryRun,
          targetsConsidered: target == null ? 0 : 1,
          authExportReadiness: readiness,
          cleanup: cleanup,
          failureKind: failure.failureKind,
        );
      }
      return _recoverRequestFailure(
        target: target,
        failure: failure,
        cleanup: cleanup,
        readiness: readiness,
      );
    }
  }

  Future<CleanupResult> _cleanupTarget({
    required PrivacyDeletionTarget target,
    required PrivacyDeletionCleanupPhase phase,
    required bool dryRun,
  }) async {
    final rawRange = _repository.retainedRawRange();
    final installations = await _repository.discoverTargetInstallations(
      userKey: target.userKey,
      range: rawRange,
    );
    return _cleanup(
      userKeys: <PseudonymousUserKey>[target.userKey],
      legacyUserIds: <LegacyFirebaseUserId>[target.legacyFirebaseUserId],
      appInstanceIds: installations,
      rawRange: rawRange,
      includeAuthTables: phase.includeAuthTables,
      dryRun: dryRun,
    );
  }

  Future<CleanupResult> _cleanupSweep({
    required List<PermanentDeletionTombstone> tombstones,
    required UtcDateRange discoveryRange,
    required bool dryRun,
  }) async {
    if (tombstones.isEmpty) {
      return const CleanupResult.none();
    }
    final installations = await _repository.discoverSweepInstallations(
      range: discoveryRange,
    );
    return _cleanup(
      userKeys: tombstones.map((final value) => value.userKey).toList(),
      legacyUserIds: tombstones
          .map((final value) => value.legacyFirebaseUserId)
          .toList(),
      appInstanceIds: installations,
      rawRange: _repository.retainedRawRange(),
      includeAuthTables: true,
      dryRun: dryRun,
    );
  }

  Future<CleanupResult> _cleanup({
    required List<PseudonymousUserKey> userKeys,
    required List<LegacyFirebaseUserId> legacyUserIds,
    required List<AppInstanceId> appInstanceIds,
    required UtcDateRange rawRange,
    required bool includeAuthTables,
    required bool dryRun,
  }) async {
    final upstream = await _repository.submitUpstreamDeletions(
      appInstanceIds: appInstanceIds,
      legacyUserIds: legacyUserIds,
      dryRun: dryRun,
    );
    final rawMutations = await _repository.deleteRawContributions(
      range: rawRange,
      userKeys: userKeys,
      legacyUserIds: legacyUserIds,
      appInstanceIds: appInstanceIds,
      dryRun: dryRun,
    );
    final keyedMutations = await _repository.deleteKeyedContributions(
      userKeys: userKeys,
      includeAuthTables: includeAuthTables,
      dryRun: dryRun,
    );
    final aggregateRebuild = await _repository.rebuildAggregates(
      dryRun: dryRun,
    );
    final verification = await _repository.verifyNoRepopulation(
      rawRange: rawRange,
      userKeys: userKeys,
      legacyUserIds: legacyUserIds,
      appInstanceIds: appInstanceIds,
      includeAuthTables: includeAuthTables,
      dryRun: dryRun,
    );
    return CleanupResult(
      installationsDiscovered: appInstanceIds.length,
      upstreamSubmissionsPlanned: upstream.plannedSubmissions,
      upstreamSubmissionsExecuted: upstream.executedSubmissions,
      rawMutations: rawMutations,
      keyedMutations: keyedMutations,
      aggregateRebuild: aggregateRebuild,
      verification: verification,
    );
  }

  Future<PrivacyDeletionSummary> _recoverRequestFailure({
    required PrivacyDeletionTarget target,
    required PrivacyDeletionOperationException failure,
    required CleanupResult cleanup,
    required AuthExportReadiness? readiness,
  }) async {
    try {
      await _repository.markRetryable(
        requestId: target.requestId,
        failureKind: failure.failureKind,
      );
    } catch (error, stackTrace) {
      throw PrivacyDeletionRecoveryException(
        primaryError: failure,
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
    return PrivacyDeletionSummary(
      operation: PrivacyDeletionOperationKind.request,
      outcome: PrivacyDeletionOutcome.retryable,
      dryRun: false,
      targetsConsidered: 1,
      authExportReadiness: readiness,
      cleanup: cleanup,
      failureKind: failure.failureKind,
    );
  }

  Future<PrivacyDeletionSummary> runSweep({required bool dryRun}) async {
    var cleanup = const CleanupResult.none();
    var targetCount = 0;
    try {
      await _repository.validateWarehouseInventory(
        allowAuthStagingTables: false,
      );
      final range = await _repository.nextSweepRange();
      final tombstones = await _repository.loadAllPermanentTombstones();
      targetCount = tombstones.length;
      cleanup = await _cleanupSweep(
        tombstones: tombstones,
        discoveryRange: range,
        dryRun: dryRun,
      );
      if (!dryRun) {
        await _repository.validateWarehouseInventory(
          allowAuthStagingTables: false,
        );
        await _repository.markSweepCompleted(throughDate: range.end);
      }
      return PrivacyDeletionSummary(
        operation: PrivacyDeletionOperationKind.sweep,
        outcome: dryRun
            ? PrivacyDeletionOutcome.planned
            : PrivacyDeletionOutcome.completed,
        dryRun: dryRun,
        targetsConsidered: targetCount,
        authExportReadiness: null,
        cleanup: cleanup,
        failureKind: null,
      );
    } on PrivacyDeletionOperationException catch (error) {
      return PrivacyDeletionSummary(
        operation: PrivacyDeletionOperationKind.sweep,
        outcome: PrivacyDeletionOutcome.retryable,
        dryRun: dryRun,
        targetsConsidered: targetCount,
        authExportReadiness: null,
        cleanup: cleanup,
        failureKind: error.failureKind,
      );
    } catch (error, stackTrace) {
      final failure = PrivacyDeletionOperationException(
        failureKind: PrivacyDeletionFailureKind.unexpected,
        operation: PrivacyDeletionOperation.readTombstones,
        innerError: error,
        innerStackTrace: stackTrace,
      );
      return PrivacyDeletionSummary(
        operation: PrivacyDeletionOperationKind.sweep,
        outcome: PrivacyDeletionOutcome.retryable,
        dryRun: dryRun,
        targetsConsidered: targetCount,
        authExportReadiness: null,
        cleanup: cleanup,
        failureKind: failure.failureKind,
      );
    }
  }
}

final class AuthExportCutoffNotReadyException implements Exception {
  const AuthExportCutoffNotReadyException();
}
