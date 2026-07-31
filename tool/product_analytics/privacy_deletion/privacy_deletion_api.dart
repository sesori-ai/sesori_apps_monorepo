import 'dart:io';

import 'bigquery_privacy_deletion_client.dart';
import 'ga_user_deletion_client.dart';
import 'google_api_foundation.dart';
import 'privacy_deletion_models.dart';

final class PrivacyDeletionWarehouseSchema {
  PrivacyDeletionWarehouseSchema({
    required this.rawDataset,
    required this.authDataset,
    required this.privacyDataset,
    required this.controlsDataset,
    required this.curatedDataset,
    required this.reportingDataset,
    required this.targetsTable,
    required this.exclusionsTable,
    required this.publicationGuardTable,
    required this.authExportRunsTable,
    required this.sweepStateTable,
    required List<BigQueryTableReference> authKeyedTables,
    required List<BigQueryTableReference> curatedKeyedTables,
    required List<BigQueryTableReference> reportingKeyedTables,
  }) : authKeyedTables = List<BigQueryTableReference>.unmodifiable(
         authKeyedTables,
       ),
       curatedKeyedTables = List<BigQueryTableReference>.unmodifiable(
         curatedKeyedTables,
       ),
       reportingKeyedTables = List<BigQueryTableReference>.unmodifiable(
         reportingKeyedTables,
       ) {
    _validateTableDataset(table: targetsTable, dataset: privacyDataset);
    _validateTableDataset(table: exclusionsTable, dataset: controlsDataset);
    _validateTableDataset(
      table: publicationGuardTable,
      dataset: controlsDataset,
    );
    _validateTableDataset(table: authExportRunsTable, dataset: authDataset);
    _validateTableDataset(table: sweepStateTable, dataset: controlsDataset);
    for (final table in this.authKeyedTables) {
      _validateTableDataset(table: table, dataset: authDataset);
    }
    for (final table in this.curatedKeyedTables) {
      _validateTableDataset(table: table, dataset: curatedDataset);
    }
    for (final table in this.reportingKeyedTables) {
      _validateTableDataset(table: table, dataset: reportingDataset);
    }
  }

  final BigQueryDatasetReference rawDataset;
  final BigQueryDatasetReference authDataset;
  final BigQueryDatasetReference privacyDataset;
  final BigQueryDatasetReference controlsDataset;
  final BigQueryDatasetReference curatedDataset;
  final BigQueryDatasetReference reportingDataset;
  final BigQueryTableReference targetsTable;
  final BigQueryTableReference exclusionsTable;
  final BigQueryTableReference publicationGuardTable;
  final BigQueryTableReference authExportRunsTable;
  final BigQueryTableReference sweepStateTable;
  final List<BigQueryTableReference> authKeyedTables;
  final List<BigQueryTableReference> curatedKeyedTables;
  final List<BigQueryTableReference> reportingKeyedTables;

  List<BigQueryTableReference> get allKeyedTables =>
      List<BigQueryTableReference>.unmodifiable(<BigQueryTableReference>[
        ...authKeyedTables,
        ...curatedKeyedTables,
        ...reportingKeyedTables,
      ]);

  static void _validateTableDataset({
    required BigQueryTableReference table,
    required BigQueryDatasetReference dataset,
  }) {
    if (table.dataset.allowlistKey != dataset.allowlistKey) {
      throw const PrivacyDeletionValidationException(
        field: 'warehouse_schema',
        requirement: 'every table in its declared allowlisted dataset',
      );
    }
  }
}

abstract interface class AggregateRebuilder {
  Future<AggregateRebuildResult> rebuild({required bool dryRun});
}

enum AggregateTransform {
  userActivityDaily(
    fileName: '20_user_activity_daily.sql',
    modelName: 'user_activity_daily',
  ),
  userMilestones(
    fileName: '30_user_milestones.sql',
    modelName: 'user_milestones',
  ),
  activationRetention(
    fileName: '40_activation_retention.sql',
    modelName: 'activation_retention',
  );

  const AggregateTransform({required this.fileName, required this.modelName});

  final String fileName;
  final String modelName;
}

abstract interface class AggregateTransformLoader {
  Future<String> load({required AggregateTransform transform});
}

final class RepositoryAggregateTransformLoader
    implements AggregateTransformLoader {
  const RepositoryAggregateTransformLoader();

  @override
  Future<String> load({required AggregateTransform transform}) {
    final asset = Platform.script.resolve('../sql/${transform.fileName}');
    return File.fromUri(asset).readAsString();
  }
}

final class FixedAggregateRebuilder implements AggregateRebuilder {
  FixedAggregateRebuilder({
    required BigQueryPrivacyDeletionClient client,
    required PrivacyDeletionWarehouseSchema schema,
    required AggregateTransformLoader loader,
  }) : _client = client,
       _schema = schema,
       _loader = loader;

  final BigQueryPrivacyDeletionClient _client;
  final PrivacyDeletionWarehouseSchema _schema;
  final AggregateTransformLoader _loader;

  @override
  Future<AggregateRebuildResult> rebuild({required bool dryRun}) async {
    try {
      final scripts = <String>[];
      for (final transform in AggregateTransform.values) {
        scripts.add(
          renderAggregateTransform(
            template: await _loader.load(transform: transform),
            schema: _schema,
          ),
        );
      }

      final rebuildStartedAt = dryRun ? null : await _serverTimestamp();
      for (final script in scripts) {
        await _client.execute(
          statement: BigQueryStatement(
            sql: script,
            parameters: const <BigQueryParameter>[],
            referencedDatasets: <BigQueryDatasetReference>[
              _schema.authDataset,
              _schema.controlsDataset,
              _schema.curatedDataset,
            ],
            isMutation: true,
            dryRun: dryRun,
          ),
        );
      }
      if (rebuildStartedAt != null) {
        await _verifyCompletedTransforms(rebuildStartedAt: rebuildStartedAt);
      }
      return AggregateRebuildResult(
        plannedOperations: AggregateTransform.values.length,
        executedOperations: dryRun ? 0 : AggregateTransform.values.length,
      );
    } catch (error, stackTrace) {
      throw AggregateRebuildException(
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
  }

  Future<DateTime> _serverTimestamp() async {
    final result = await _client.execute(
      statement: BigQueryStatement(
        sql: 'SELECT CURRENT_TIMESTAMP() AS rebuild_started_at',
        parameters: const <BigQueryParameter>[],
        referencedDatasets: const <BigQueryDatasetReference>[],
        isMutation: false,
        dryRun: false,
      ),
    );
    if (result.rows.length != 1) {
      throw const BigQueryResponseShapeException();
    }
    return _requiredTimestamp(
      row: result.rows.single,
      field: 'rebuild_started_at',
    );
  }

  Future<void> _verifyCompletedTransforms({
    required DateTime rebuildStartedAt,
  }) async {
    final requiredModelNames = AggregateTransform.values
        .map((transform) => "    '${transform.modelName}'")
        .join(',\n');
    final result = await _client.execute(
      statement: BigQueryStatement(
        sql:
            '''
WITH latest_auth_snapshot AS (
  SELECT published_at
  FROM ${_schema.authExportRunsTable.sqlIdentifier}
  ORDER BY published_at DESC, run_cutoff DESC
  LIMIT 1
),
required_models AS (
  SELECT model_name
  FROM UNNEST([
$requiredModelNames
  ]) AS model_name
)
SELECT COUNT(*) AS matching_count
FROM required_models
WHERE EXISTS (
  SELECT 1
  FROM `${_schema.curatedDataset.projectId.value}.${_schema.curatedDataset.datasetId.value}.transform_state` AS state
  CROSS JOIN latest_auth_snapshot AS auth
  WHERE state.model_name = required_models.model_name
    AND state.completed_at >= @rebuild_started_at
    AND state.auth_snapshot_published_at = auth.published_at
)
''',
        parameters: <BigQueryParameter>[
          BigQueryTimestampParameter(
            name: 'rebuild_started_at',
            value: rebuildStartedAt,
          ),
        ],
        referencedDatasets: <BigQueryDatasetReference>[
          _schema.authDataset,
          _schema.curatedDataset,
        ],
        isMutation: false,
        dryRun: false,
      ),
    );
    final matchingModels = _singleResultCount(result: result);
    if (matchingModels != AggregateTransform.values.length) {
      throw AggregateTransformVerificationException(
        expectedModels: AggregateTransform.values.length,
        matchingModels: matchingModels,
      );
    }
  }
}

final class AggregateRebuildException implements Exception {
  const AggregateRebuildException({
    required this.innerError,
    required this.innerStackTrace,
  });

  final Object innerError;
  final StackTrace innerStackTrace;
}

final class AggregateTransformVerificationException implements Exception {
  const AggregateTransformVerificationException({
    required this.expectedModels,
    required this.matchingModels,
  });

  final int expectedModels;
  final int matchingModels;
}

String renderAggregateTransform({
  required String template,
  required PrivacyDeletionWarehouseSchema schema,
}) {
  final replacements = <String, String>{
    '{{PROJECT_ID}}': schema.rawDataset.projectId.value,
    '{{RAW_DATASET_ID}}': schema.rawDataset.datasetId.value,
    '{{AUTH_DATASET_ID}}': schema.authDataset.datasetId.value,
    '{{PRIVACY_DATASET_ID}}': schema.privacyDataset.datasetId.value,
    '{{CONTROLS_DATASET_ID}}': schema.controlsDataset.datasetId.value,
    '{{CURATED_DATASET_ID}}': schema.curatedDataset.datasetId.value,
    '{{REPORTING_DATASET_ID}}': schema.reportingDataset.datasetId.value,
  };
  var rendered = template;
  for (final entry in replacements.entries) {
    rendered = rendered.replaceAll(entry.key, entry.value);
  }
  if (RegExp(r'\{\{[^}]+\}\}').hasMatch(rendered)) {
    throw const PrivacyDeletionValidationException(
      field: 'aggregate_transform',
      requirement: 'only supported uppercase project and dataset placeholders',
    );
  }
  return rendered;
}

final class UpstreamDeletionResult {
  const UpstreamDeletionResult({
    required this.plannedSubmissions,
    required this.executedSubmissions,
  });

  final int plannedSubmissions;
  final int executedSubmissions;
}

final class PrivacyDeletionApi {
  PrivacyDeletionApi({
    required BigQueryPrivacyDeletionClient bigQueryClient,
    required GaUserDeletionClient gaUserDeletionClient,
    required PrivacyDeletionWarehouseSchema schema,
    required AggregateRebuilder aggregateRebuilder,
    required int parameterBatchSize,
  }) : _bigQueryClient = bigQueryClient,
       _gaUserDeletionClient = gaUserDeletionClient,
       _schema = schema,
       _aggregateRebuilder = aggregateRebuilder,
       _parameterBatchSize = parameterBatchSize {
    if (parameterBatchSize < 1) {
      throw const PrivacyDeletionValidationException(
        field: 'parameter_batch_size',
        requirement: 'a positive integer',
      );
    }
  }

  static const String _sweepName = 'product_analytics_privacy_deletion';

  final BigQueryPrivacyDeletionClient _bigQueryClient;
  final GaUserDeletionClient _gaUserDeletionClient;
  final PrivacyDeletionWarehouseSchema _schema;
  final AggregateRebuilder _aggregateRebuilder;
  final int _parameterBatchSize;

  Future<PrivacyDeletionTarget?> loadTarget({
    required PrivacyRequestId requestId,
  }) async {
    final result = await _executeBigQuery(
      operation: PrivacyDeletionOperation.loadTarget,
      statement: BigQueryStatement(
        sql:
            '''
SELECT request_id, user_key, legacy_firebase_user_id, suppressed_at, status
FROM ${_schema.targetsTable.sqlIdentifier}
WHERE request_id = @request_id
LIMIT 2
''',
        parameters: <BigQueryParameter>[
          BigQueryStringParameter(name: 'request_id', value: requestId.value),
        ],
        referencedDatasets: <BigQueryDatasetReference>[_schema.privacyDataset],
        isMutation: false,
        dryRun: false,
      ),
    );
    if (result.rows.isEmpty) {
      return null;
    }
    if (result.rows.length != 1) {
      throw _malformedTarget(
        innerError: const TargetCardinalityException(),
        innerStackTrace: StackTrace.current,
      );
    }
    try {
      final row = result.rows.single;
      final loadedRequestId = PrivacyRequestId.parse(
        value: _requiredString(row: row, field: 'request_id'),
      );
      if (loadedRequestId.value != requestId.value) {
        throw const TargetRequestMismatchException();
      }
      return PrivacyDeletionTarget(
        requestId: loadedRequestId,
        userKey: PseudonymousUserKey.parse(
          value: _requiredString(row: row, field: 'user_key'),
        ),
        legacyFirebaseUserId: LegacyFirebaseUserId.parse(
          value: _requiredString(row: row, field: 'legacy_firebase_user_id'),
        ),
        suppressedAt: _requiredTimestamp(row: row, field: 'suppressed_at'),
        status: PrivacyDeletionTargetStatus.parse(
          value: _requiredString(row: row, field: 'status'),
        ),
      );
    } catch (error, stackTrace) {
      throw _malformedTarget(innerError: error, innerStackTrace: stackTrace);
    }
  }

  Future<void> upsertPermanentExclusion({
    required PrivacyDeletionTarget target,
    required bool dryRun,
  }) async {
    await _executeBigQuery(
      operation: PrivacyDeletionOperation.upsertExclusion,
      statement: BigQueryStatement(
        sql:
            '''
BEGIN TRANSACTION;

UPDATE ${_schema.publicationGuardTable.sqlIdentifier}
SET publication_epoch = publication_epoch + 1,
    updated_at = CURRENT_TIMESTAMP()
WHERE guard_key = 'singleton';

ASSERT @@row_count = 1 AS 'The keyed publication guard singleton is required';

MERGE ${_schema.exclusionsTable.sqlIdentifier} AS destination
USING (
  SELECT @user_key AS user_key, @suppressed_at AS suppressed_at
) AS source
ON destination.user_key = source.user_key
WHEN MATCHED AND source.suppressed_at < destination.suppressed_at THEN
  UPDATE SET
    suppressed_at = source.suppressed_at,
    updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
  INSERT (user_key, suppressed_at, created_at, updated_at)
  VALUES (source.user_key, source.suppressed_at, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());

COMMIT TRANSACTION;
''',
        parameters: <BigQueryParameter>[
          BigQueryStringParameter(
            name: 'user_key',
            value: target.userKey.value,
          ),
          BigQueryTimestampParameter(
            name: 'suppressed_at',
            value: target.suppressedAt,
          ),
        ],
        referencedDatasets: <BigQueryDatasetReference>[_schema.controlsDataset],
        isMutation: true,
        dryRun: dryRun,
      ),
    );
  }

  Future<bool> permanentExclusionExists({
    required PseudonymousUserKey userKey,
  }) async {
    final result = await _executeBigQuery(
      operation: PrivacyDeletionOperation.readExclusion,
      statement: BigQueryStatement(
        sql:
            '''
SELECT COUNT(*) AS matching_count
FROM ${_schema.exclusionsTable.sqlIdentifier}
WHERE user_key = @user_key
''',
        parameters: <BigQueryParameter>[
          BigQueryStringParameter(name: 'user_key', value: userKey.value),
        ],
        referencedDatasets: <BigQueryDatasetReference>[_schema.controlsDataset],
        isMutation: false,
        dryRun: false,
      ),
    );
    return _singleCount(result: result) == 1;
  }

  Future<AuthExportSnapshot?> latestSuccessfulAuthExport() async {
    final result = await _executeBigQuery(
      operation: PrivacyDeletionOperation.readAuthExport,
      statement: BigQueryStatement(
        sql:
            '''
SELECT
  export.run_cutoff,
  export.published_at,
  config.auth_snapshot_max_age_hours,
  config.clock_skew_allowance_seconds
FROM ${_schema.authExportRunsTable.sqlIdentifier} AS export
CROSS JOIN `${_schema.controlsDataset.projectId.value}.${_schema.controlsDataset.datasetId.value}.analytics_measurement_config` AS config
WHERE config.config_key = 'singleton'
ORDER BY export.published_at DESC, export.run_cutoff DESC
LIMIT 1
''',
        parameters: const <BigQueryParameter>[],
        referencedDatasets: <BigQueryDatasetReference>[
          _schema.authDataset,
          _schema.controlsDataset,
        ],
        isMutation: false,
        dryRun: false,
      ),
    );
    if (result.rows.isEmpty) {
      return null;
    }
    try {
      return AuthExportSnapshot(
        runCutoff: _requiredTimestamp(
          row: result.rows.single,
          field: 'run_cutoff',
        ),
        publishedAt: _requiredTimestamp(
          row: result.rows.single,
          field: 'published_at',
        ),
        maxAge: Duration(
          hours: _requiredPositiveInt(
            row: result.rows.single,
            field: 'auth_snapshot_max_age_hours',
          ),
        ),
        futureClockAllowance: Duration(
          seconds: _requiredPositiveInt(
            row: result.rows.single,
            field: 'clock_skew_allowance_seconds',
          ),
        ),
      );
    } catch (error, stackTrace) {
      throw PrivacyDeletionOperationException(
        failureKind: PrivacyDeletionFailureKind.warehouseRead,
        operation: PrivacyDeletionOperation.readAuthExport,
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
  }

  Future<void> validateKeyedTableInventory({
    required bool allowAuthStagingTables,
  }) async {
    final result = await _executeBigQuery(
      operation: PrivacyDeletionOperation.validateWarehouseSchema,
      statement: BigQueryStatement(
        sql:
            '''
SELECT 'auth' AS dataset_scope, table_name
FROM `${_schema.authDataset.projectId.value}.${_schema.authDataset.datasetId.value}.INFORMATION_SCHEMA.COLUMNS`
WHERE column_name = 'user_key'
UNION ALL
SELECT 'curated' AS dataset_scope, table_name
FROM `${_schema.curatedDataset.projectId.value}.${_schema.curatedDataset.datasetId.value}.INFORMATION_SCHEMA.COLUMNS`
WHERE column_name = 'user_key'
UNION ALL
SELECT 'reporting' AS dataset_scope, table_name
FROM `${_schema.reportingDataset.projectId.value}.${_schema.reportingDataset.datasetId.value}.INFORMATION_SCHEMA.COLUMNS`
WHERE column_name = 'user_key'
ORDER BY dataset_scope, table_name
''',
        parameters: const <BigQueryParameter>[],
        referencedDatasets: <BigQueryDatasetReference>[
          _schema.authDataset,
          _schema.curatedDataset,
          _schema.reportingDataset,
        ],
        isMutation: false,
        dryRun: false,
      ),
    );

    final expectedAuthTables = _schema.authKeyedTables
        .map((final table) => table.tableId.value)
        .toSet();
    final expectedCuratedTables = _schema.curatedKeyedTables
        .map((final table) => table.tableId.value)
        .toSet();
    final expectedReportingTables = _schema.reportingKeyedTables
        .map((final table) => table.tableId.value)
        .toSet();
    final foundExpectedAuthTables = <String>{};
    final foundCuratedTables = <String>{};
    final foundReportingTables = <String>{};
    final unexpectedTables = <String>[];
    var authStagingTableCount = 0;

    try {
      for (final row in result.rows) {
        final datasetScope = _requiredString(row: row, field: 'dataset_scope');
        final tableName = _requiredString(row: row, field: 'table_name');
        switch (datasetScope) {
          case 'auth':
            if (expectedAuthTables.contains(tableName)) {
              foundExpectedAuthTables.add(tableName);
            } else if (RegExp(
              r'^auth_user_milestones_staging_[a-z0-9_]{8,80}$',
            ).hasMatch(tableName)) {
              authStagingTableCount += 1;
            } else {
              unexpectedTables.add('$datasetScope.$tableName');
            }
          case 'curated':
            foundCuratedTables.add(tableName);
            if (!expectedCuratedTables.contains(tableName)) {
              unexpectedTables.add('$datasetScope.$tableName');
            }
          case 'reporting':
            foundReportingTables.add(tableName);
            if (!expectedReportingTables.contains(tableName)) {
              unexpectedTables.add('$datasetScope.$tableName');
            }
          default:
            throw const BigQueryRowShapeException(field: 'dataset_scope');
        }
      }
    } catch (error, stackTrace) {
      throw PrivacyDeletionOperationException(
        failureKind: PrivacyDeletionFailureKind.verification,
        operation: PrivacyDeletionOperation.validateWarehouseSchema,
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }

    final expectedTablesMissing =
        !foundExpectedAuthTables.containsAll(expectedAuthTables) ||
        !foundCuratedTables.containsAll(expectedCuratedTables) ||
        !foundReportingTables.containsAll(expectedReportingTables);
    if (unexpectedTables.isNotEmpty ||
        expectedTablesMissing ||
        (!allowAuthStagingTables && authStagingTableCount != 0)) {
      throw PrivacyDeletionOperationException(
        failureKind: PrivacyDeletionFailureKind.verification,
        operation: PrivacyDeletionOperation.validateWarehouseSchema,
        innerError: KeyedTableInventoryException(
          unexpectedTableCount: unexpectedTables.length,
          expectedTablesMissing: expectedTablesMissing,
          authStagingTableCount: authStagingTableCount,
        ),
        innerStackTrace: StackTrace.current,
      );
    }
  }

  Future<List<PermanentDeletionTombstone>> loadAllPermanentTombstones() async {
    final result = await _executeBigQuery(
      operation: PrivacyDeletionOperation.readTombstones,
      statement: BigQueryStatement(
        sql:
            '''
SELECT exclusion.user_key, exclusion.suppressed_at, target.legacy_firebase_user_id
FROM ${_schema.exclusionsTable.sqlIdentifier} AS exclusion
LEFT JOIN ${_schema.targetsTable.sqlIdentifier} AS target
  ON target.user_key = exclusion.user_key
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY exclusion.user_key
  ORDER BY target.suppressed_at ASC, target.request_id ASC
) = 1
''',
        parameters: const <BigQueryParameter>[],
        referencedDatasets: <BigQueryDatasetReference>[
          _schema.controlsDataset,
          _schema.privacyDataset,
        ],
        isMutation: false,
        dryRun: false,
      ),
    );
    try {
      return List<PermanentDeletionTombstone>.unmodifiable(
        result.rows.map(
          (final row) => PermanentDeletionTombstone(
            userKey: PseudonymousUserKey.parse(
              value: _requiredString(row: row, field: 'user_key'),
            ),
            legacyFirebaseUserId: LegacyFirebaseUserId.parse(
              value: _requiredString(
                row: row,
                field: 'legacy_firebase_user_id',
              ),
            ),
            suppressedAt: _requiredTimestamp(row: row, field: 'suppressed_at'),
          ),
        ),
      );
    } catch (error, stackTrace) {
      throw PrivacyDeletionOperationException(
        failureKind: PrivacyDeletionFailureKind.malformedTarget,
        operation: PrivacyDeletionOperation.readTombstones,
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
  }

  Future<List<AppInstanceId>> discoverInstallationsForTarget({
    required PseudonymousUserKey userKey,
    required UtcDateRange range,
  }) {
    return _discoverInstallations(range: range, onlyUserKey: userKey);
  }

  Future<List<AppInstanceId>> discoverInstallationsForAllTombstones({
    required UtcDateRange range,
  }) {
    return _discoverInstallations(range: range, onlyUserKey: null);
  }

  Future<List<AppInstanceId>> _discoverInstallations({
    required UtcDateRange range,
    required PseudonymousUserKey? onlyUserKey,
  }) async {
    final rawTables = await _rawTables(range: range);
    if (rawTables.isEmpty) {
      return const <AppInstanceId>[];
    }
    final matchingRows = onlyUserKey == null
        ? '''
SELECT DISTINCT raw.user_pseudo_id
FROM raw_keyed_events AS raw
JOIN ${_schema.exclusionsTable.sqlIdentifier} AS exclusion
  ON exclusion.user_key = raw.user_key
'''
        : '''
SELECT DISTINCT raw.user_pseudo_id
FROM raw_keyed_events AS raw
WHERE raw.user_key = @only_user_key
''';
    final result = await _executeBigQuery(
      operation: PrivacyDeletionOperation.discoverInstallations,
      statement: BigQueryStatement(
        sql:
            '''
WITH raw_keyed_events AS (
${_rawKeyedEventsUnion(tables: rawTables)}
)
$matchingRows
''',
        parameters: <BigQueryParameter>[
          if (onlyUserKey != null)
            BigQueryStringParameter(
              name: 'only_user_key',
              value: onlyUserKey.value,
            ),
        ],
        referencedDatasets: <BigQueryDatasetReference>[
          _schema.rawDataset,
          if (onlyUserKey == null) _schema.controlsDataset,
        ],
        isMutation: false,
        dryRun: false,
      ),
    );
    try {
      return List<AppInstanceId>.unmodifiable(
        result.rows.map(
          (final row) => AppInstanceId.parse(
            value: _requiredString(row: row, field: 'user_pseudo_id'),
          ),
        ),
      );
    } catch (error, stackTrace) {
      throw PrivacyDeletionOperationException(
        failureKind: PrivacyDeletionFailureKind.malformedTarget,
        operation: PrivacyDeletionOperation.discoverInstallations,
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
  }

  Future<UpstreamDeletionResult> submitUpstreamDeletions({
    required List<AppInstanceId> appInstanceIds,
    required List<LegacyFirebaseUserId> legacyUserIds,
    required bool dryRun,
  }) async {
    final uniqueAppIds = <String, AppInstanceId>{
      for (final value in appInstanceIds) value.value: value,
    }.values.toList();
    final uniqueLegacyIds = <String, LegacyFirebaseUserId>{
      for (final value in legacyUserIds) value.value: value,
    }.values.toList();
    final planned = uniqueAppIds.length + uniqueLegacyIds.length;
    if (dryRun) {
      return UpstreamDeletionResult(
        plannedSubmissions: planned,
        executedSubmissions: 0,
      );
    }
    var executed = 0;
    try {
      for (final appInstanceId in uniqueAppIds) {
        await _gaUserDeletionClient.submit(
          identifier: GaAppInstanceDeletionIdentifier(
            appInstanceId: appInstanceId,
          ),
        );
        executed += 1;
      }
      for (final legacyUserId in uniqueLegacyIds) {
        await _gaUserDeletionClient.submit(
          identifier: GaLegacyUserDeletionIdentifier(
            legacyUserId: legacyUserId,
          ),
        );
        executed += 1;
      }
      return UpstreamDeletionResult(
        plannedSubmissions: planned,
        executedSubmissions: executed,
      );
    } catch (error, stackTrace) {
      throw PrivacyDeletionOperationException(
        failureKind: _isCredentialFailure(error: error)
            ? PrivacyDeletionFailureKind.credentials
            : PrivacyDeletionFailureKind.upstreamSubmission,
        operation: PrivacyDeletionOperation.submitUpstream,
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
  }

  Future<WarehouseMutationResult> deleteRawContributions({
    required UtcDateRange range,
    required List<PseudonymousUserKey> userKeys,
    required List<LegacyFirebaseUserId> legacyUserIds,
    required List<AppInstanceId> appInstanceIds,
    required bool dryRun,
  }) async {
    final tables = await _rawTables(range: range);
    var total = const WarehouseMutationResult.none();
    total = total.add(
      other: await _deleteRawDimension(
        tables: tables,
        kind: _RawIdentifierKind.userKey,
        values: _uniqueStrings(
          values: userKeys.map((final value) => value.value).toList(),
        ),
        dryRun: dryRun,
      ),
    );
    total = total.add(
      other: await _deleteRawDimension(
        tables: tables,
        kind: _RawIdentifierKind.legacyUserId,
        values: _uniqueStrings(
          values: legacyUserIds.map((final value) => value.value).toList(),
        ),
        dryRun: dryRun,
      ),
    );
    total = total.add(
      other: await _deleteRawDimension(
        tables: tables,
        kind: _RawIdentifierKind.appInstanceId,
        values: _uniqueStrings(
          values: appInstanceIds.map((final value) => value.value).toList(),
        ),
        dryRun: dryRun,
      ),
    );
    return total;
  }

  Future<WarehouseMutationResult> _deleteRawDimension({
    required List<BigQueryTableReference> tables,
    required _RawIdentifierKind kind,
    required List<String> values,
    required bool dryRun,
  }) async {
    if (values.isEmpty || tables.isEmpty) {
      return const WarehouseMutationResult.none();
    }
    var planned = 0;
    var executed = 0;
    var affected = 0;
    for (final batch in _chunks(values: values, size: _parameterBatchSize)) {
      for (final table in tables) {
        planned += 1;
        final result = await _executeBigQuery(
          operation: PrivacyDeletionOperation.deleteRaw,
          statement: BigQueryStatement(
            sql:
                '''
DELETE FROM ${table.sqlIdentifier}
WHERE ${kind.predicate}
''',
            parameters: <BigQueryParameter>[
              BigQueryStringArrayParameter(
                name: 'identifier_values',
                values: batch,
              ),
            ],
            referencedDatasets: <BigQueryDatasetReference>[_schema.rawDataset],
            isMutation: true,
            dryRun: dryRun,
          ),
        );
        if (!dryRun) {
          executed += 1;
          affected += result.affectedRows;
        }
      }
    }
    return WarehouseMutationResult(
      plannedJobs: planned,
      executedJobs: executed,
      affectedRows: affected,
    );
  }

  Future<WarehouseMutationResult> deleteKeyedContributions({
    required List<PseudonymousUserKey> userKeys,
    required bool includeAuthTables,
    required bool dryRun,
  }) async {
    final values = _uniqueStrings(
      values: userKeys.map((final value) => value.value).toList(),
    );
    if (values.isEmpty) {
      return const WarehouseMutationResult.none();
    }
    var planned = 0;
    var executed = 0;
    var affected = 0;
    final tables = <BigQueryTableReference>[
      if (includeAuthTables) ..._schema.authKeyedTables,
      ..._schema.curatedKeyedTables,
      ..._schema.reportingKeyedTables,
    ];
    for (final batch in _chunks(values: values, size: _parameterBatchSize)) {
      for (final table in tables) {
        planned += 1;
        final result = await _executeBigQuery(
          operation: PrivacyDeletionOperation.deleteKeyed,
          statement: BigQueryStatement(
            sql:
                '''
DELETE FROM ${table.sqlIdentifier}
WHERE user_key IN UNNEST(@user_keys)
''',
            parameters: <BigQueryParameter>[
              BigQueryStringArrayParameter(name: 'user_keys', values: batch),
            ],
            referencedDatasets: <BigQueryDatasetReference>[table.dataset],
            isMutation: true,
            dryRun: dryRun,
          ),
        );
        if (!dryRun) {
          executed += 1;
          affected += result.affectedRows;
        }
      }
    }
    return WarehouseMutationResult(
      plannedJobs: planned,
      executedJobs: executed,
      affectedRows: affected,
    );
  }

  Future<AggregateRebuildResult> rebuildAggregates({
    required bool dryRun,
  }) async {
    try {
      return await _aggregateRebuilder.rebuild(dryRun: dryRun);
    } catch (error, stackTrace) {
      throw PrivacyDeletionOperationException(
        failureKind: PrivacyDeletionFailureKind.aggregateRebuild,
        operation: PrivacyDeletionOperation.rebuildAggregates,
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
  }

  Future<WarehouseVerificationResult> verifyNoRepopulation({
    required UtcDateRange rawRange,
    required List<PseudonymousUserKey> userKeys,
    required List<LegacyFirebaseUserId> legacyUserIds,
    required List<AppInstanceId> appInstanceIds,
    required bool includeAuthTables,
  }) async {
    var checks = 0;
    var violations = 0;
    final userKeyValues = _uniqueStrings(
      values: userKeys.map((final value) => value.value).toList(),
    );
    if (userKeyValues.isNotEmpty) {
      for (final batch in _chunks(
        values: userKeyValues,
        size: _parameterBatchSize,
      )) {
        checks += 1;
        final exclusionCount = await _count(
          operation: PrivacyDeletionOperation.verifyDeletion,
          sql:
              '''
SELECT COUNT(DISTINCT user_key) AS matching_count
FROM ${_schema.exclusionsTable.sqlIdentifier}
WHERE user_key IN UNNEST(@identifier_values)
''',
          values: batch,
          datasets: <BigQueryDatasetReference>[_schema.controlsDataset],
        );
        if (exclusionCount != batch.length) {
          violations += 1;
        }
        final keyedTables = <BigQueryTableReference>[
          if (includeAuthTables) ..._schema.authKeyedTables,
          ..._schema.curatedKeyedTables,
          ..._schema.reportingKeyedTables,
        ];
        for (final table in keyedTables) {
          checks += 1;
          final count = await _count(
            operation: PrivacyDeletionOperation.verifyDeletion,
            sql:
                '''
SELECT COUNT(*) AS matching_count
FROM ${table.sqlIdentifier}
WHERE user_key IN UNNEST(@identifier_values)
''',
            values: batch,
            datasets: <BigQueryDatasetReference>[table.dataset],
          );
          if (count != 0) {
            violations += 1;
          }
        }
      }
    }

    final rawTables = await _rawTables(range: rawRange);
    final dimensions = <(_RawIdentifierKind, List<String>)>[
      (_RawIdentifierKind.userKey, userKeyValues),
      (
        _RawIdentifierKind.legacyUserId,
        _uniqueStrings(
          values: legacyUserIds.map((final value) => value.value).toList(),
        ),
      ),
      (
        _RawIdentifierKind.appInstanceId,
        _uniqueStrings(
          values: appInstanceIds.map((final value) => value.value).toList(),
        ),
      ),
    ];
    for (final dimension in dimensions) {
      for (final batch in _chunks(
        values: dimension.$2,
        size: _parameterBatchSize,
      )) {
        for (final table in rawTables) {
          checks += 1;
          final count = await _count(
            operation: PrivacyDeletionOperation.verifyDeletion,
            sql:
                '''
SELECT COUNT(*) AS matching_count
FROM ${table.sqlIdentifier}
WHERE ${dimension.$1.predicate}
''',
            values: batch,
            datasets: <BigQueryDatasetReference>[_schema.rawDataset],
          );
          if (count != 0) {
            violations += 1;
          }
        }
      }
    }
    return WarehouseVerificationResult(
      checksRun: checks,
      violationChecks: violations,
    );
  }

  Future<void> updateTargetStatus({
    required PrivacyRequestId requestId,
    required PrivacyDeletionTargetStatus status,
    required PrivacyDeletionFailureKind? failureKind,
  }) async {
    try {
      await _bigQueryClient.execute(
        statement: BigQueryStatement(
          sql:
              '''
UPDATE ${_schema.targetsTable.sqlIdentifier}
SET
  status = @status,
  last_error_code = @last_error_code,
  completed_at = IF(
    @status = @completed_status,
    COALESCE(completed_at, CURRENT_TIMESTAMP()),
    completed_at
  ),
  updated_at = CURRENT_TIMESTAMP()
WHERE request_id = @request_id
  AND status != @completed_status
''',
          parameters: <BigQueryParameter>[
            BigQueryStringParameter(name: 'status', value: status.wireValue),
            BigQueryStringParameter(
              name: 'last_error_code',
              value: failureKind?.wireValue,
            ),
            BigQueryStringParameter(
              name: 'completed_status',
              value: PrivacyDeletionTargetStatus.completed.wireValue,
            ),
            BigQueryStringParameter(name: 'request_id', value: requestId.value),
          ],
          referencedDatasets: <BigQueryDatasetReference>[
            _schema.privacyDataset,
          ],
          isMutation: true,
          dryRun: false,
        ),
      );
      final verification = await _bigQueryClient.execute(
        statement: BigQueryStatement(
          sql:
              '''
SELECT status
FROM ${_schema.targetsTable.sqlIdentifier}
WHERE request_id = @request_id
LIMIT 2
''',
          parameters: <BigQueryParameter>[
            BigQueryStringParameter(name: 'request_id', value: requestId.value),
          ],
          referencedDatasets: <BigQueryDatasetReference>[
            _schema.privacyDataset,
          ],
          isMutation: false,
          dryRun: false,
        ),
      );
      if (verification.rows.length != 1) {
        throw TargetStatusCardinalityException(
          matchingTargets: verification.rows.length,
        );
      }
      final actualStatus = PrivacyDeletionTargetStatus.parse(
        value: _requiredString(row: verification.rows.single, field: 'status'),
      );
      if (actualStatus != status) {
        throw TargetStatusMismatchException(
          requestedStatus: status,
          actualStatus: actualStatus,
        );
      }
    } catch (error, stackTrace) {
      throw PrivacyDeletionOperationException(
        failureKind: _isCredentialFailure(error: error)
            ? PrivacyDeletionFailureKind.credentials
            : PrivacyDeletionFailureKind.statusUpdate,
        operation: PrivacyDeletionOperation.updateTargetStatus,
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
  }

  Future<DateTime?> latestRawEventTableDate() async {
    final informationSchema =
        '`${_schema.rawDataset.projectId.value}.'
        '${_schema.rawDataset.datasetId.value}.INFORMATION_SCHEMA.TABLES`';
    final result = await _executeBigQuery(
      operation: PrivacyDeletionOperation.readRawTables,
      statement: BigQueryStatement(
        sql:
            '''
WITH measurement AS (
  SELECT DATE_SUB(DATE(raw_export_start_at), INTERVAL 1 DAY) AS controlled_start_date
  FROM `${_schema.controlsDataset.projectId.value}.${_schema.controlsDataset.datasetId.value}.analytics_measurement_config`
  WHERE config_key = 'singleton'
),
raw_tables AS (
  SELECT table_name
  FROM $informationSchema
  WHERE table_type = @table_type
    AND STARTS_WITH(table_name, 'events_')
),
summary AS (
  SELECT
    measurement.controlled_start_date,
    MAX(IF(
      REGEXP_CONTAINS(table_name, r'^events_[0-9]{8}\$'),
      SAFE.PARSE_DATE('%Y%m%d', SUBSTR(table_name, 8)),
      NULL
    )) AS latest_raw_date,
    COUNTIF(REGEXP_CONTAINS(table_name, r'^events_intraday_[0-9]{8}\$')) AS intraday_table_count,
    COUNTIF(NOT REGEXP_CONTAINS(table_name, r'^events_[0-9]{8}\$')) AS unsupported_export_table_count,
    COALESCE(
      ARRAY_AGG(
        IF(
          REGEXP_CONTAINS(table_name, r'^events_[0-9]{8}\$'),
          SAFE.PARSE_DATE('%Y%m%d', SUBSTR(table_name, 8)),
          NULL
        ) IGNORE NULLS
      ),
      ARRAY<DATE>[]
    ) AS daily_dates
  FROM measurement
  LEFT JOIN raw_tables ON TRUE
  GROUP BY measurement.controlled_start_date
),
bounded AS (
  SELECT
    *,
    GREATEST(
      controlled_start_date,
      DATE_SUB(latest_raw_date, INTERVAL 89 DAY)
    ) AS expected_start_date
  FROM summary
)
SELECT
  latest_raw_date,
  intraday_table_count,
  unsupported_export_table_count,
  CASE
    WHEN latest_raw_date IS NULL OR latest_raw_date < controlled_start_date THEN 1
    ELSE DATE_DIFF(latest_raw_date, expected_start_date, DAY) + 1 - (
      SELECT COUNT(DISTINCT event_date)
      FROM UNNEST(daily_dates) AS event_date
      WHERE event_date BETWEEN expected_start_date AND latest_raw_date
    )
  END AS missing_daily_table_count
FROM bounded
''',
        parameters: const <BigQueryParameter>[
          BigQueryStringParameter(name: 'table_type', value: 'BASE TABLE'),
        ],
        referencedDatasets: <BigQueryDatasetReference>[
          _schema.rawDataset,
          _schema.controlsDataset,
        ],
        isMutation: false,
        dryRun: false,
      ),
    );
    try {
      if (result.rows.length != 1) {
        throw const BigQueryResponseShapeException();
      }
      final row = result.rows.single;
      final intradayTableCount = _requiredNonnegativeInteger(
        row: row,
        field: 'intraday_table_count',
      );
      final unsupportedExportTableCount = _requiredNonnegativeInteger(
        row: row,
        field: 'unsupported_export_table_count',
      );
      final missingDailyTableCount = _requiredNonnegativeInteger(
        row: row,
        field: 'missing_daily_table_count',
      );
      if (intradayTableCount != 0 ||
          unsupportedExportTableCount != 0 ||
          missingDailyTableCount != 0) {
        throw RawTableInventoryException(
          intradayTableCount: intradayTableCount,
          unsupportedExportTableCount: unsupportedExportTableCount,
          missingDailyTableCount: missingDailyTableCount,
        );
      }
      final value = row['latest_raw_date'];
      if (value == null) {
        return null;
      }
      if (value is! String) {
        throw const BigQueryRowShapeException(field: 'latest_raw_date');
      }
      final parsed = DateTime.tryParse('${value}T00:00:00Z');
      if (parsed == null) {
        throw const BigQueryRowShapeException(field: 'latest_raw_date');
      }
      return parsed;
    } catch (error, stackTrace) {
      throw PrivacyDeletionOperationException(
        failureKind: PrivacyDeletionFailureKind.warehouseRead,
        operation: PrivacyDeletionOperation.readRawTables,
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
  }

  Future<DateTime?> readLastSweepSuccessDate() async {
    final result = await _executeBigQuery(
      operation: PrivacyDeletionOperation.readSweepCheckpoint,
      statement: BigQueryStatement(
        sql:
            '''
SELECT last_success_through_date
FROM ${_schema.sweepStateTable.sqlIdentifier}
WHERE sweep_name = @sweep_name
LIMIT 1
''',
        parameters: const <BigQueryParameter>[
          BigQueryStringParameter(name: 'sweep_name', value: _sweepName),
        ],
        referencedDatasets: <BigQueryDatasetReference>[_schema.controlsDataset],
        isMutation: false,
        dryRun: false,
      ),
    );
    if (result.rows.isEmpty) {
      return null;
    }
    final raw = _requiredString(
      row: result.rows.single,
      field: 'last_success_through_date',
    );
    final parsed = DateTime.tryParse('${raw}T00:00:00Z');
    if (parsed == null) {
      throw PrivacyDeletionOperationException(
        failureKind: PrivacyDeletionFailureKind.warehouseRead,
        operation: PrivacyDeletionOperation.readSweepCheckpoint,
        innerError: const BigQueryRowShapeException(
          field: 'last_success_through_date',
        ),
        innerStackTrace: StackTrace.current,
      );
    }
    return UtcDateRange.utcDate(dateTime: parsed);
  }

  Future<void> updateSweepSuccessDate({required DateTime throughDate}) async {
    await _executeBigQuery(
      operation: PrivacyDeletionOperation.updateSweepCheckpoint,
      statement: BigQueryStatement(
        sql:
            '''
MERGE ${_schema.sweepStateTable.sqlIdentifier} AS destination
USING (
  SELECT @sweep_name AS sweep_name, @through_date AS through_date
) AS source
ON destination.sweep_name = source.sweep_name
WHEN MATCHED AND destination.last_success_through_date < source.through_date THEN
  UPDATE SET
    last_success_through_date = source.through_date,
    updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
  INSERT (sweep_name, last_success_through_date, updated_at)
  VALUES (source.sweep_name, source.through_date, CURRENT_TIMESTAMP())
''',
        parameters: <BigQueryParameter>[
          const BigQueryStringParameter(name: 'sweep_name', value: _sweepName),
          BigQueryDateParameter(name: 'through_date', value: throughDate),
        ],
        referencedDatasets: <BigQueryDatasetReference>[_schema.controlsDataset],
        isMutation: true,
        dryRun: false,
      ),
    );
  }

  Future<List<BigQueryTableReference>> _rawTables({
    required UtcDateRange range,
  }) async {
    final informationSchema =
        '`${_schema.rawDataset.projectId.value}.'
        '${_schema.rawDataset.datasetId.value}.INFORMATION_SCHEMA.TABLES`';
    final dailyTablePattern = r"r'^events_[0-9]{8}$'";
    final bufferedStart = range.start.subtract(const Duration(days: 1));
    final bufferedEnd = range.end.add(const Duration(days: 1));
    final result = await _executeBigQuery(
      operation: PrivacyDeletionOperation.readRawTables,
      statement: BigQueryStatement(
        sql:
            '''
SELECT table_name
FROM $informationSchema
WHERE table_type = @table_type
  AND REGEXP_CONTAINS(table_name, $dailyTablePattern)
  AND SAFE.PARSE_DATE('%Y%m%d', SUBSTR(table_name, 8)) BETWEEN @from_date AND @through_date
ORDER BY table_name
''',
        parameters: <BigQueryParameter>[
          const BigQueryStringParameter(
            name: 'table_type',
            value: 'BASE TABLE',
          ),
          BigQueryDateParameter(name: 'from_date', value: bufferedStart),
          BigQueryDateParameter(name: 'through_date', value: bufferedEnd),
        ],
        referencedDatasets: <BigQueryDatasetReference>[_schema.rawDataset],
        isMutation: false,
        dryRun: false,
      ),
    );
    try {
      return List<BigQueryTableReference>.unmodifiable(
        result.rows.map((final row) {
          final name = _requiredString(row: row, field: 'table_name');
          if (!RegExp(r'^events_[0-9]{8}$').hasMatch(name)) {
            throw const BigQueryRowShapeException(field: 'table_name');
          }
          return BigQueryTableReference(
            dataset: _schema.rawDataset,
            tableId: BigQueryTableId.parse(field: 'raw_table', value: name),
          );
        }),
      );
    } catch (error, stackTrace) {
      throw PrivacyDeletionOperationException(
        failureKind: PrivacyDeletionFailureKind.warehouseRead,
        operation: PrivacyDeletionOperation.readRawTables,
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
  }

  String _rawKeyedEventsUnion({required List<BigQueryTableReference> tables}) {
    return tables
        .map(
          (final table) =>
              '''
  SELECT
    user_pseudo_id,
    ARRAY(
      SELECT parameter.value.string_value
      FROM UNNEST(event_params) AS parameter
      WHERE parameter.key = 'user_key'
        AND parameter.value.string_value IS NOT NULL
      LIMIT 1
    )[SAFE_OFFSET(0)] AS user_key
  FROM ${table.sqlIdentifier}
  WHERE user_pseudo_id IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM UNNEST(event_params) AS parameter
      WHERE parameter.key = 'user_key'
        AND parameter.value.string_value IS NOT NULL
    )
''',
        )
        .join('\nUNION ALL\n');
  }

  Future<int> _count({
    required PrivacyDeletionOperation operation,
    required String sql,
    required List<String> values,
    required List<BigQueryDatasetReference> datasets,
  }) async {
    final result = await _executeBigQuery(
      operation: operation,
      statement: BigQueryStatement(
        sql: sql,
        parameters: <BigQueryParameter>[
          BigQueryStringArrayParameter(
            name: 'identifier_values',
            values: values,
          ),
        ],
        referencedDatasets: datasets,
        isMutation: false,
        dryRun: false,
      ),
    );
    return _singleCount(result: result);
  }

  int _singleCount({required BigQueryStatementResult result}) {
    return _singleResultCount(result: result);
  }

  Future<BigQueryStatementResult> _executeBigQuery({
    required PrivacyDeletionOperation operation,
    required BigQueryStatement statement,
  }) async {
    try {
      return await _bigQueryClient.execute(statement: statement);
    } catch (error, stackTrace) {
      if (error is PrivacyDeletionOperationException) {
        rethrow;
      }
      throw PrivacyDeletionOperationException(
        failureKind: _isCredentialFailure(error: error)
            ? PrivacyDeletionFailureKind.credentials
            : statement.isMutation
            ? PrivacyDeletionFailureKind.warehouseWrite
            : PrivacyDeletionFailureKind.warehouseRead,
        operation: operation,
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
  }

  PrivacyDeletionOperationException _malformedTarget({
    required Object innerError,
    required StackTrace innerStackTrace,
  }) {
    return PrivacyDeletionOperationException(
      failureKind: PrivacyDeletionFailureKind.malformedTarget,
      operation: PrivacyDeletionOperation.loadTarget,
      innerError: innerError,
      innerStackTrace: innerStackTrace,
    );
  }
}

int _singleResultCount({required BigQueryStatementResult result}) {
  if (result.rows.length != 1) {
    throw const BigQueryResponseShapeException();
  }
  final raw = result.rows.single['matching_count'];
  if (raw is! String || int.tryParse(raw) == null) {
    throw const BigQueryResponseShapeException();
  }
  return int.parse(raw);
}

int _requiredNonnegativeInteger({
  required Map<String, Object?> row,
  required String field,
}) {
  final value = row[field];
  final parsed = value is String ? int.tryParse(value) : null;
  if (parsed == null || parsed < 0) {
    throw BigQueryRowShapeException(field: field);
  }
  return parsed;
}

enum _RawIdentifierKind {
  userKey,
  legacyUserId,
  appInstanceId;

  String get predicate => switch (this) {
    userKey =>
      '''EXISTS (
  SELECT 1
  FROM UNNEST(event_params) AS parameter
  WHERE parameter.key = 'user_key'
    AND parameter.value.string_value IN UNNEST(@identifier_values)
)''',
    legacyUserId => 'user_id IN UNNEST(@identifier_values)',
    appInstanceId => 'user_pseudo_id IN UNNEST(@identifier_values)',
  };
}

List<String> _uniqueStrings({required List<String> values}) {
  return List<String>.unmodifiable(values.toSet());
}

List<List<T>> _chunks<T>({required List<T> values, required int size}) {
  final chunks = <List<T>>[];
  for (var offset = 0; offset < values.length; offset += size) {
    final end = offset + size > values.length ? values.length : offset + size;
    chunks.add(List<T>.unmodifiable(values.sublist(offset, end)));
  }
  return chunks;
}

String _requiredString({
  required Map<String, Object?> row,
  required String field,
}) {
  final value = row[field];
  if (value is! String || value.isEmpty) {
    throw BigQueryRowShapeException(field: field);
  }
  return value;
}

DateTime _requiredTimestamp({
  required Map<String, Object?> row,
  required String field,
}) {
  final raw = _requiredString(row: row, field: field);
  var parsed = DateTime.tryParse(raw);
  if (parsed == null && raw.endsWith(' UTC')) {
    parsed = DateTime.tryParse('${raw.substring(0, raw.length - 4)}Z');
  }
  if (parsed == null) {
    final secondsSinceEpoch = double.tryParse(raw);
    if (secondsSinceEpoch != null) {
      parsed = DateTime.fromMicrosecondsSinceEpoch(
        (secondsSinceEpoch * Duration.microsecondsPerSecond).round(),
        isUtc: true,
      );
    }
  }
  if (parsed == null) {
    throw BigQueryRowShapeException(field: field);
  }
  return parsed.toUtc();
}

int _requiredPositiveInt({
  required Map<String, Object?> row,
  required String field,
}) {
  final raw = row[field];
  final value = switch (raw) {
    int value => value,
    String value => int.tryParse(value),
    _ => null,
  };
  if (value == null || value < 1) {
    throw BigQueryRowShapeException(field: field);
  }
  return value;
}

bool _isCredentialFailure({required Object error}) {
  if (error is AccessTokenAcquisitionException) {
    return true;
  }
  if (error is BigQueryPrivacyDeletionClientException) {
    return _isCredentialFailure(error: error.innerError);
  }
  if (error is GaUserDeletionClientException) {
    return _isCredentialFailure(error: error.innerError);
  }
  return false;
}

final class BigQueryRowShapeException implements Exception {
  const BigQueryRowShapeException({required this.field});

  final String field;
}

final class TargetCardinalityException implements Exception {
  const TargetCardinalityException();
}

final class TargetRequestMismatchException implements Exception {
  const TargetRequestMismatchException();
}

final class TargetStatusCardinalityException implements Exception {
  const TargetStatusCardinalityException({required this.matchingTargets});

  final int matchingTargets;
}

final class TargetStatusMismatchException implements Exception {
  const TargetStatusMismatchException({
    required this.requestedStatus,
    required this.actualStatus,
  });

  final PrivacyDeletionTargetStatus requestedStatus;
  final PrivacyDeletionTargetStatus actualStatus;
}

final class KeyedTableInventoryException implements Exception {
  const KeyedTableInventoryException({
    required this.unexpectedTableCount,
    required this.expectedTablesMissing,
    required this.authStagingTableCount,
  });

  final int unexpectedTableCount;
  final bool expectedTablesMissing;
  final int authStagingTableCount;
}

final class RawTableInventoryException implements Exception {
  const RawTableInventoryException({
    required this.intradayTableCount,
    required this.unsupportedExportTableCount,
    required this.missingDailyTableCount,
  });

  final int intradayTableCount;
  final int unsupportedExportTableCount;
  final int missingDailyTableCount;
}
