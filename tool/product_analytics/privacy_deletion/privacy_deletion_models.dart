final RegExp _lowercaseSha256Pattern = RegExp(r'^[0-9a-f]{64}$');
final RegExp _requestIdPattern = RegExp(r'^[A-Za-z0-9_-]{8,128}$');
final RegExp _projectIdPattern = RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$');
final RegExp _bigQueryIdentifierPattern = RegExp(
  r'^[A-Za-z_][A-Za-z0-9_]{0,1023}$',
);
final RegExp _locationPattern = RegExp(r'^[A-Za-z][A-Za-z0-9-]{1,31}$');
final RegExp _analyticsPropertyIdPattern = RegExp(r'^[0-9]{1,32}$');

final class GcpProjectId {
  GcpProjectId._({required this.value});

  factory GcpProjectId.parse({required String value}) {
    if (!_projectIdPattern.hasMatch(value)) {
      throw PrivacyDeletionValidationException(
        field: 'project',
        requirement: 'a valid lowercase Google Cloud project ID',
      );
    }
    return GcpProjectId._(value: value);
  }

  final String value;
}

final class BigQueryDatasetId {
  BigQueryDatasetId._({required this.value});

  factory BigQueryDatasetId.parse({
    required String field,
    required String value,
  }) {
    if (!_bigQueryIdentifierPattern.hasMatch(value)) {
      throw PrivacyDeletionValidationException(
        field: field,
        requirement: 'a valid BigQuery dataset identifier',
      );
    }
    return BigQueryDatasetId._(value: value);
  }

  final String value;
}

final class BigQueryTableId {
  BigQueryTableId._({required this.value});

  factory BigQueryTableId.parse({
    required String field,
    required String value,
  }) {
    if (!_bigQueryIdentifierPattern.hasMatch(value)) {
      throw PrivacyDeletionValidationException(
        field: field,
        requirement: 'a valid BigQuery table identifier',
      );
    }
    return BigQueryTableId._(value: value);
  }

  final String value;
}

final class BigQueryLocation {
  BigQueryLocation._({required this.value});

  factory BigQueryLocation.parse({required String value}) {
    if (!_locationPattern.hasMatch(value)) {
      throw PrivacyDeletionValidationException(
        field: 'location',
        requirement: 'a valid BigQuery location',
      );
    }
    return BigQueryLocation._(value: value);
  }

  final String value;
}

final class AnalyticsPropertyId {
  AnalyticsPropertyId._({required this.value});

  factory AnalyticsPropertyId.parse({required String value}) {
    if (!_analyticsPropertyIdPattern.hasMatch(value)) {
      throw PrivacyDeletionValidationException(
        field: 'analytics_property_id',
        requirement: 'a numeric Google Analytics property ID',
      );
    }
    return AnalyticsPropertyId._(value: value);
  }

  final String value;
}

final class BigQueryDatasetReference {
  const BigQueryDatasetReference({
    required this.projectId,
    required this.datasetId,
  });

  final GcpProjectId projectId;
  final BigQueryDatasetId datasetId;

  String get allowlistKey => '${projectId.value}.${datasetId.value}';
  String get sqlIdentifier => '`${projectId.value}.${datasetId.value}`';
}

final class BigQueryTableReference {
  const BigQueryTableReference({required this.dataset, required this.tableId});

  final BigQueryDatasetReference dataset;
  final BigQueryTableId tableId;

  String get sqlIdentifier =>
      '`${dataset.projectId.value}.${dataset.datasetId.value}.${tableId.value}`';
}

final class PrivacyRequestId {
  PrivacyRequestId._({required this.value});

  factory PrivacyRequestId.parse({required String value}) {
    if (!_requestIdPattern.hasMatch(value)) {
      throw PrivacyDeletionValidationException(
        field: 'request_id',
        requirement: '8-128 ASCII letters, digits, underscores, or hyphens',
      );
    }
    return PrivacyRequestId._(value: value);
  }

  final String value;
}

final class PseudonymousUserKey {
  PseudonymousUserKey._({required this.value});

  factory PseudonymousUserKey.parse({required String value}) {
    if (!_lowercaseSha256Pattern.hasMatch(value)) {
      throw PrivacyDeletionValidationException(
        field: 'user_key',
        requirement: 'exactly 64 lowercase hexadecimal characters',
      );
    }
    return PseudonymousUserKey._(value: value);
  }

  final String value;
}

final class LegacyFirebaseUserId {
  LegacyFirebaseUserId._({required this.value});

  factory LegacyFirebaseUserId.parse({required String value}) {
    if (!_lowercaseSha256Pattern.hasMatch(value)) {
      throw PrivacyDeletionValidationException(
        field: 'legacy_firebase_user_id',
        requirement: 'exactly 64 lowercase hexadecimal characters',
      );
    }
    return LegacyFirebaseUserId._(value: value);
  }

  final String value;
}

final class AppInstanceId {
  AppInstanceId._({required this.value});

  factory AppInstanceId.parse({required String value}) {
    final hasControlCharacter = value.codeUnits.any(
      (final codeUnit) => codeUnit < 0x20 || codeUnit == 0x7f,
    );
    if (value.isEmpty || value.length > 256 || hasControlCharacter) {
      throw PrivacyDeletionValidationException(
        field: 'app_instance_id',
        requirement: '1-256 characters without control characters',
      );
    }
    return AppInstanceId._(value: value);
  }

  final String value;
}

enum PrivacyDeletionTargetStatus {
  pending,
  processing,
  retryable,
  completed;

  static PrivacyDeletionTargetStatus parse({required String value}) {
    return switch (value) {
      'pending' => pending,
      'processing' => processing,
      'retryable' => retryable,
      'completed' => completed,
      _ => throw PrivacyDeletionValidationException(
        field: 'target_status',
        requirement: 'pending, processing, retryable, or completed',
      ),
    };
  }

  String get wireValue => switch (this) {
    pending => 'pending',
    processing => 'processing',
    retryable => 'retryable',
    completed => 'completed',
  };
}

final class PrivacyDeletionTarget {
  const PrivacyDeletionTarget({
    required this.requestId,
    required this.userKey,
    required this.legacyFirebaseUserId,
    required this.suppressedAt,
    required this.status,
  });

  final PrivacyRequestId requestId;
  final PseudonymousUserKey userKey;
  final LegacyFirebaseUserId legacyFirebaseUserId;
  final DateTime suppressedAt;
  final PrivacyDeletionTargetStatus status;
}

final class PermanentDeletionTombstone {
  const PermanentDeletionTombstone({
    required this.userKey,
    required this.legacyFirebaseUserId,
    required this.suppressedAt,
  });

  final PseudonymousUserKey userKey;
  final LegacyFirebaseUserId legacyFirebaseUserId;
  final DateTime suppressedAt;
}

final class UtcDateRange {
  UtcDateRange._({required this.start, required this.end});

  factory UtcDateRange.fromDates({
    required DateTime start,
    required DateTime end,
  }) {
    final normalizedStart = utcDate(dateTime: start);
    final normalizedEnd = utcDate(dateTime: end);
    if (normalizedStart.isAfter(normalizedEnd)) {
      throw PrivacyDeletionValidationException(
        field: 'date_range',
        requirement: 'start date must not be after end date',
      );
    }
    return UtcDateRange._(start: normalizedStart, end: normalizedEnd);
  }

  static DateTime utcDate({required DateTime dateTime}) {
    final utc = dateTime.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  final DateTime start;
  final DateTime end;

  String get startSuffix => formatCompactUtcDate(date: start);
  String get endSuffix => formatCompactUtcDate(date: end);
}

String formatUtcDate({required DateTime date}) {
  final utc = date.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')}';
}

String formatCompactUtcDate({required DateTime date}) {
  final utc = date.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}'
      '${utc.month.toString().padLeft(2, '0')}'
      '${utc.day.toString().padLeft(2, '0')}';
}

final class AuthExportSnapshot {
  const AuthExportSnapshot({
    required this.runCutoff,
    required this.publishedAt,
  });

  final DateTime runCutoff;
  final DateTime publishedAt;
}

enum AuthExportReadiness {
  ready,
  notReady;

  String get wireValue => switch (this) {
    ready => 'ready',
    notReady => 'not_ready',
  };
}

enum PrivacyDeletionCleanupPhase {
  preliminary(includeAuthTables: false),
  finalPass(includeAuthTables: true);

  const PrivacyDeletionCleanupPhase({required this.includeAuthTables});

  final bool includeAuthTables;
}

final class AggregateRebuildResult {
  const AggregateRebuildResult({
    required this.plannedOperations,
    required this.executedOperations,
  });

  final int plannedOperations;
  final int executedOperations;
}

final class WarehouseMutationResult {
  const WarehouseMutationResult({
    required this.plannedJobs,
    required this.executedJobs,
    required this.affectedRows,
  });

  const WarehouseMutationResult.none()
    : plannedJobs = 0,
      executedJobs = 0,
      affectedRows = 0;

  final int plannedJobs;
  final int executedJobs;
  final int affectedRows;

  WarehouseMutationResult add({required WarehouseMutationResult other}) {
    return WarehouseMutationResult(
      plannedJobs: plannedJobs + other.plannedJobs,
      executedJobs: executedJobs + other.executedJobs,
      affectedRows: affectedRows + other.affectedRows,
    );
  }
}

final class WarehouseVerificationResult {
  const WarehouseVerificationResult({
    required this.checksRun,
    required this.violationChecks,
  });

  final int checksRun;
  final int violationChecks;
}

final class CleanupResult {
  const CleanupResult({
    required this.installationsDiscovered,
    required this.upstreamSubmissionsPlanned,
    required this.upstreamSubmissionsExecuted,
    required this.rawMutations,
    required this.keyedMutations,
    required this.aggregateRebuild,
    required this.verification,
  });

  const CleanupResult.none()
    : installationsDiscovered = 0,
      upstreamSubmissionsPlanned = 0,
      upstreamSubmissionsExecuted = 0,
      rawMutations = const WarehouseMutationResult.none(),
      keyedMutations = const WarehouseMutationResult.none(),
      aggregateRebuild = const AggregateRebuildResult(
        plannedOperations: 0,
        executedOperations: 0,
      ),
      verification = const WarehouseVerificationResult(
        checksRun: 0,
        violationChecks: 0,
      );

  final int installationsDiscovered;
  final int upstreamSubmissionsPlanned;
  final int upstreamSubmissionsExecuted;
  final WarehouseMutationResult rawMutations;
  final WarehouseMutationResult keyedMutations;
  final AggregateRebuildResult aggregateRebuild;
  final WarehouseVerificationResult verification;

  CleanupResult add({required CleanupResult other}) {
    return CleanupResult(
      installationsDiscovered:
          installationsDiscovered + other.installationsDiscovered,
      upstreamSubmissionsPlanned:
          upstreamSubmissionsPlanned + other.upstreamSubmissionsPlanned,
      upstreamSubmissionsExecuted:
          upstreamSubmissionsExecuted + other.upstreamSubmissionsExecuted,
      rawMutations: rawMutations.add(other: other.rawMutations),
      keyedMutations: keyedMutations.add(other: other.keyedMutations),
      aggregateRebuild: AggregateRebuildResult(
        plannedOperations:
            aggregateRebuild.plannedOperations +
            other.aggregateRebuild.plannedOperations,
        executedOperations:
            aggregateRebuild.executedOperations +
            other.aggregateRebuild.executedOperations,
      ),
      verification: WarehouseVerificationResult(
        checksRun: verification.checksRun + other.verification.checksRun,
        violationChecks:
            verification.violationChecks + other.verification.violationChecks,
      ),
    );
  }
}

enum PrivacyDeletionOperationKind {
  request,
  sweep;

  String get wireValue => switch (this) {
    request => 'privacy_deletion_request',
    sweep => 'privacy_deletion_sweep',
  };
}

enum PrivacyDeletionOutcome {
  planned,
  completed,
  alreadyCompleted,
  retryable;

  String get wireValue => switch (this) {
    planned => 'planned',
    completed => 'completed',
    alreadyCompleted => 'already_completed',
    retryable => 'retryable',
  };
}

enum PrivacyDeletionFailureKind {
  invalidInput,
  targetNotFound,
  malformedTarget,
  credentials,
  warehouseRead,
  warehouseWrite,
  upstreamSubmission,
  aggregateRebuild,
  authExportNotReady,
  verification,
  statusUpdate,
  unexpected;

  String get wireValue => switch (this) {
    invalidInput => 'invalid_input',
    targetNotFound => 'target_not_found',
    malformedTarget => 'malformed_target',
    credentials => 'credentials',
    warehouseRead => 'warehouse_read',
    warehouseWrite => 'warehouse_write',
    upstreamSubmission => 'upstream_submission',
    aggregateRebuild => 'aggregate_rebuild',
    authExportNotReady => 'auth_export_not_ready',
    verification => 'verification',
    statusUpdate => 'status_update',
    unexpected => 'unexpected',
  };
}

enum PrivacyDeletionOperation {
  loadTarget,
  upsertExclusion,
  readExclusion,
  readAuthExport,
  readTombstones,
  discoverInstallations,
  submitUpstream,
  deleteRaw,
  deleteKeyed,
  rebuildAggregates,
  verifyDeletion,
  updateTargetStatus,
  validateWarehouseSchema,
  readSweepCheckpoint,
  updateSweepCheckpoint,
  readRawTables;

  String get wireValue => switch (this) {
    loadTarget => 'load_target',
    upsertExclusion => 'upsert_exclusion',
    readExclusion => 'read_exclusion',
    readAuthExport => 'read_auth_export',
    readTombstones => 'read_tombstones',
    discoverInstallations => 'discover_installations',
    submitUpstream => 'submit_upstream',
    deleteRaw => 'delete_raw',
    deleteKeyed => 'delete_keyed',
    rebuildAggregates => 'rebuild_aggregates',
    verifyDeletion => 'verify_deletion',
    updateTargetStatus => 'update_target_status',
    validateWarehouseSchema => 'validate_warehouse_schema',
    readSweepCheckpoint => 'read_sweep_checkpoint',
    updateSweepCheckpoint => 'update_sweep_checkpoint',
    readRawTables => 'read_raw_tables',
  };
}

final class PrivacyDeletionSummary {
  const PrivacyDeletionSummary({
    required this.operation,
    required this.outcome,
    required this.dryRun,
    required this.targetsConsidered,
    required this.authExportReadiness,
    required this.cleanup,
    required this.failureKind,
  });

  final PrivacyDeletionOperationKind operation;
  final PrivacyDeletionOutcome outcome;
  final bool dryRun;
  final int targetsConsidered;
  final AuthExportReadiness? authExportReadiness;
  final CleanupResult cleanup;
  final PrivacyDeletionFailureKind? failureKind;

  bool get succeeded =>
      outcome == PrivacyDeletionOutcome.completed ||
      outcome == PrivacyDeletionOutcome.alreadyCompleted ||
      outcome == PrivacyDeletionOutcome.planned;

  Map<String, Object?> toAggregateJson({
    required String credentialSource,
    required bool credentialFallback,
  }) {
    return <String, Object?>{
      'operation': operation.wireValue,
      'mode': dryRun ? 'dry_run' : 'apply',
      'outcome': outcome.wireValue,
      'targets_considered': targetsConsidered,
      'auth_export': authExportReadiness?.wireValue,
      'installation_discoveries': cleanup.installationsDiscovered,
      'upstream_submissions_planned': cleanup.upstreamSubmissionsPlanned,
      'upstream_submissions_executed': cleanup.upstreamSubmissionsExecuted,
      'raw_mutation_jobs_planned': cleanup.rawMutations.plannedJobs,
      'raw_mutation_jobs_executed': cleanup.rawMutations.executedJobs,
      'keyed_mutation_jobs_planned': cleanup.keyedMutations.plannedJobs,
      'keyed_mutation_jobs_executed': cleanup.keyedMutations.executedJobs,
      'aggregate_rebuilds_planned': cleanup.aggregateRebuild.plannedOperations,
      'aggregate_rebuilds_executed':
          cleanup.aggregateRebuild.executedOperations,
      'verification_checks': cleanup.verification.checksRun,
      'current_violation_checks': cleanup.verification.violationChecks,
      'failure_kind': failureKind?.wireValue,
      'credential_source': credentialSource,
      'credential_fallback': credentialFallback,
    };
  }
}

final class PrivacyDeletionValidationException implements Exception {
  const PrivacyDeletionValidationException({
    required this.field,
    required this.requirement,
  });

  final String field;
  final String requirement;

  @override
  String toString() => 'Invalid $field: expected $requirement.';
}

final class PrivacyDeletionOperationException implements Exception {
  const PrivacyDeletionOperationException({
    required this.failureKind,
    required this.operation,
    required this.innerError,
    required this.innerStackTrace,
  });

  final PrivacyDeletionFailureKind failureKind;
  final PrivacyDeletionOperation operation;
  final Object innerError;
  final StackTrace innerStackTrace;

  @override
  String toString() =>
      'Privacy deletion operation failed: ${operation.wireValue} '
      '(${failureKind.wireValue}).';
}

final class PrivacyDeletionRecoveryException implements Exception {
  const PrivacyDeletionRecoveryException({
    required this.primaryError,
    required this.innerError,
    required this.innerStackTrace,
  });

  final PrivacyDeletionOperationException primaryError;
  final Object innerError;
  final StackTrace innerStackTrace;

  @override
  String toString() =>
      'Privacy deletion failed and retryable status could not be recorded.';
}
