import 'privacy_deletion_api.dart';
import 'privacy_deletion_models.dart';

final class PrivacyDeletionRepository {
  PrivacyDeletionRepository({
    required PrivacyDeletionApi api,
    required int rawRetentionDays,
    required DateTime Function() now,
  }) : _api = api,
       _rawRetentionDays = rawRetentionDays,
       _now = now {
    if (rawRetentionDays < 1 || rawRetentionDays > 90) {
      throw const PrivacyDeletionValidationException(
        field: 'raw_retention_days',
        requirement: '1 through 90',
      );
    }
  }

  final PrivacyDeletionApi _api;
  final int _rawRetentionDays;
  final DateTime Function() _now;

  Future<PrivacyDeletionTarget> loadTarget({
    required PrivacyRequestId requestId,
  }) async {
    final target = await _api.loadTarget(requestId: requestId);
    if (target == null) {
      throw PrivacyDeletionOperationException(
        failureKind: PrivacyDeletionFailureKind.targetNotFound,
        operation: PrivacyDeletionOperation.loadTarget,
        innerError: const PrivacyDeletionTargetNotFoundException(),
        innerStackTrace: StackTrace.current,
      );
    }
    return target;
  }

  Future<void> prepareTarget({
    required PrivacyDeletionTarget target,
    required bool dryRun,
  }) async {
    await _api.upsertPermanentExclusion(target: target, dryRun: dryRun);
    await validateWarehouseInventory(allowAuthStagingTables: true);
    if (dryRun) {
      return;
    }
    final exclusionExists = await _api.permanentExclusionExists(
      userKey: target.userKey,
    );
    if (!exclusionExists) {
      throw PrivacyDeletionOperationException(
        failureKind: PrivacyDeletionFailureKind.verification,
        operation: PrivacyDeletionOperation.readExclusion,
        innerError: const PermanentExclusionMissingException(),
        innerStackTrace: StackTrace.current,
      );
    }
    await _api.updateTargetStatus(
      requestId: target.requestId,
      status: PrivacyDeletionTargetStatus.processing,
      failureKind: null,
    );
  }

  Future<AuthExportSnapshot?> loadLatestSuccessfulAuthExport() {
    return _api.latestSuccessfulAuthExport();
  }

  Future<List<AppInstanceId>> discoverTargetInstallations({
    required PseudonymousUserKey userKey,
    required UtcDateRange range,
  }) {
    return _api.discoverInstallationsForTarget(userKey: userKey, range: range);
  }

  Future<List<AppInstanceId>> discoverSweepInstallations({
    required UtcDateRange range,
  }) {
    return _api.discoverInstallationsForAllTombstones(range: range);
  }

  Future<UpstreamDeletionResult> submitUpstreamDeletions({
    required List<AppInstanceId> appInstanceIds,
    required List<LegacyFirebaseUserId> legacyUserIds,
    required bool dryRun,
  }) {
    return _api.submitUpstreamDeletions(
      appInstanceIds: appInstanceIds,
      legacyUserIds: legacyUserIds,
      dryRun: dryRun,
    );
  }

  Future<WarehouseMutationResult> deleteRawContributions({
    required UtcDateRange range,
    required List<PseudonymousUserKey> userKeys,
    required List<LegacyFirebaseUserId> legacyUserIds,
    required List<AppInstanceId> appInstanceIds,
    required bool dryRun,
  }) {
    return _api.deleteRawContributions(
      range: range,
      userKeys: userKeys,
      legacyUserIds: legacyUserIds,
      appInstanceIds: appInstanceIds,
      dryRun: dryRun,
    );
  }

  Future<WarehouseMutationResult> deleteKeyedContributions({
    required List<PseudonymousUserKey> userKeys,
    required bool includeAuthTables,
    required bool dryRun,
  }) {
    return _api.deleteKeyedContributions(
      userKeys: userKeys,
      includeAuthTables: includeAuthTables,
      dryRun: dryRun,
    );
  }

  Future<AggregateRebuildResult> rebuildAggregates({required bool dryRun}) {
    return _api.rebuildAggregates(dryRun: dryRun);
  }

  Future<WarehouseVerificationResult> verifyNoRepopulation({
    required UtcDateRange rawRange,
    required List<PseudonymousUserKey> userKeys,
    required List<LegacyFirebaseUserId> legacyUserIds,
    required List<AppInstanceId> appInstanceIds,
    required bool includeAuthTables,
    required bool dryRun,
  }) async {
    final verification = await _api.verifyNoRepopulation(
      rawRange: rawRange,
      userKeys: userKeys,
      legacyUserIds: legacyUserIds,
      appInstanceIds: appInstanceIds,
      includeAuthTables: includeAuthTables,
    );
    if (!dryRun && verification.violationChecks != 0) {
      throw PrivacyDeletionOperationException(
        failureKind: PrivacyDeletionFailureKind.verification,
        operation: PrivacyDeletionOperation.verifyDeletion,
        innerError: DeletionVerificationException(
          violationChecks: verification.violationChecks,
        ),
        innerStackTrace: StackTrace.current,
      );
    }
    return verification;
  }

  Future<void> markCompleted({required PrivacyRequestId requestId}) {
    return _api.updateTargetStatus(
      requestId: requestId,
      status: PrivacyDeletionTargetStatus.completed,
      failureKind: null,
    );
  }

  Future<void> markRetryable({
    required PrivacyRequestId requestId,
    required PrivacyDeletionFailureKind failureKind,
  }) {
    return _api.updateTargetStatus(
      requestId: requestId,
      status: PrivacyDeletionTargetStatus.retryable,
      failureKind: failureKind,
    );
  }

  Future<List<PermanentDeletionTombstone>> loadAllPermanentTombstones() {
    return _api.loadAllPermanentTombstones();
  }

  Future<void> validateWarehouseInventory({
    required bool allowAuthStagingTables,
  }) async {
    await _api.validateKeyedTableInventory(
      allowAuthStagingTables: allowAuthStagingTables,
    );
    await _api.latestRawEventTableDate();
  }

  Future<UtcDateRange> nextSweepRange() async {
    final lastSuccessDate = await _api.readLastSweepSuccessDate();
    final latestRawTableDate = await _api.latestRawEventTableDate();
    if (latestRawTableDate == null) {
      throw PrivacyDeletionOperationException(
        failureKind: PrivacyDeletionFailureKind.warehouseRead,
        operation: PrivacyDeletionOperation.readRawTables,
        innerError: const RawEventTableNotFoundException(),
        innerStackTrace: StackTrace.current,
      );
    }
    final latestCompleteRawDate = calculateLatestCompleteRawDate(
      now: _now(),
      latestRawTableDate: latestRawTableDate,
    );
    return calculateSweepRange(
      latestCompleteRawDate: latestCompleteRawDate,
      lastSuccessDate: lastSuccessDate,
      rawRetentionDays: _rawRetentionDays,
    );
  }

  Future<void> markSweepCompleted({required DateTime throughDate}) {
    return _api.updateSweepSuccessDate(throughDate: throughDate);
  }

  UtcDateRange retainedRawRange() {
    final today = UtcDateRange.utcDate(dateTime: _now());
    return UtcDateRange.fromDates(
      start: today.subtract(Duration(days: _rawRetentionDays - 1)),
      end: today,
    );
  }

  static UtcDateRange calculateSweepRange({
    required DateTime latestCompleteRawDate,
    required DateTime? lastSuccessDate,
    required int rawRetentionDays,
  }) {
    if (rawRetentionDays < 1 || rawRetentionDays > 90) {
      throw const PrivacyDeletionValidationException(
        field: 'raw_retention_days',
        requirement: '1 through 90',
      );
    }
    final throughDate = UtcDateRange.utcDate(dateTime: latestCompleteRawDate);
    final oldestRetained = throughDate.subtract(
      Duration(days: rawRetentionDays - 1),
    );
    final latestThreeStart = throughDate.subtract(const Duration(days: 2));
    final normalizedLastSuccess = lastSuccessDate == null
        ? null
        : UtcDateRange.utcDate(dateTime: lastSuccessDate);
    if (normalizedLastSuccess != null &&
        normalizedLastSuccess.isAfter(throughDate)) {
      throw const PrivacyDeletionValidationException(
        field: 'sweep_checkpoint',
        requirement: 'a UTC date no later than the latest complete raw date',
      );
    }
    final continuation = normalizedLastSuccess == null
        ? oldestRetained
        : normalizedLastSuccess.add(const Duration(days: 1));
    var start = continuation.isBefore(latestThreeStart)
        ? continuation
        : latestThreeStart;
    if (start.isBefore(oldestRetained)) {
      start = oldestRetained;
    }
    return UtcDateRange.fromDates(start: start, end: throughDate);
  }

  static DateTime calculateLatestCompleteRawDate({
    required DateTime now,
    required DateTime latestRawTableDate,
  }) {
    final yesterday = UtcDateRange.utcDate(
      dateTime: now,
    ).subtract(const Duration(days: 1));
    final latestCompleteFromTables = UtcDateRange.utcDate(
      dateTime: latestRawTableDate,
    ).subtract(const Duration(days: 1));
    return latestCompleteFromTables.isBefore(yesterday)
        ? latestCompleteFromTables
        : yesterday;
  }
}

final class PrivacyDeletionTargetNotFoundException implements Exception {
  const PrivacyDeletionTargetNotFoundException();
}

final class PermanentExclusionMissingException implements Exception {
  const PermanentExclusionMissingException();
}

final class DeletionVerificationException implements Exception {
  const DeletionVerificationException({required this.violationChecks});

  final int violationChecks;
}

final class RawEventTableNotFoundException implements Exception {
  const RawEventTableNotFoundException();
}
