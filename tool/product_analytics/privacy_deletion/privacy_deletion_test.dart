import 'dart:convert';

import 'bigquery_privacy_deletion_client.dart';
import 'ga_user_deletion_client.dart';
import 'google_api_foundation.dart';
import 'privacy_deletion_api.dart';
import 'privacy_deletion_config.dart';
import 'privacy_deletion_models.dart';
import 'privacy_deletion_repository.dart';

Future<void> main() async {
  _testIdentifiers();
  _testConfigurationAllowlistAndDefaults();
  _testSweepRanges();
  _testCleanupPhases();
  _testAnalyticsAdminRequestShapes();
  await _testLatestSuccessfulAuthExportSql();
  await _testKeyedTableInventory();
  await _testRawDateAndInstallationDiscovery();
  await _testFixedAggregateChain();
  await _testStatusVerification();
  _testAggregateOnlyOutput();
}

void _testIdentifiers() {
  for (final value in <String>['A_1-b2C3', '${'A' * 126}_-', 'request_123']) {
    _expect(
      condition: PrivacyRequestId.parse(value: value).value == value,
      message: 'valid request ID was not retained',
    );
  }
  for (final value in <String>[
    'A' * 7,
    'A' * 129,
    'abc.defgh',
    'abc:defgh',
    'abcdefg/',
    'abcdé123',
  ]) {
    _expectThrows<PrivacyDeletionValidationException>(
      body: () => PrivacyRequestId.parse(value: value),
      message: 'request ID outside ^[A-Za-z0-9_-]{8,128}\$ was accepted',
    );
  }

  final lowercaseKey = 'a' * 64;
  _expect(
    condition:
        PseudonymousUserKey.parse(value: lowercaseKey).value == lowercaseKey,
    message: 'valid lowercase key was not retained',
  );
  _expectThrows<PrivacyDeletionValidationException>(
    body: () => PseudonymousUserKey.parse(value: lowercaseKey.toUpperCase()),
    message: 'uppercase key was accepted',
  );
  _expectThrows<PrivacyDeletionValidationException>(
    body: () => LegacyFirebaseUserId.parse(value: 'a' * 63),
    message: 'short legacy ID was accepted',
  );
}

void _testConfigurationAllowlistAndDefaults() {
  final command = PrivacyDeletionCommandConfig.parse(
    arguments: <String>[..._baseArguments(includeRequestId: true), '--dry-run'],
    environment: const <String, String>{},
    requestIdRequired: true,
  );
  _expect(
    condition: command.config.allowedDatasets.length == 6,
    message: 'the six datasets were not allowlisted',
  );
  _expect(
    condition:
        command.config.exclusionsTable.tableId.value ==
        'permanent_deletion_exclusions',
    message: 'the permanent deletion exclusions default is incorrect',
  );
  _expect(
    condition:
        command.config.rawRetentionDays == 90 &&
        command.config.authKeyedTables
                .map((final table) => table.tableId.value)
                .join(',') ==
            'auth_user_milestones' &&
        command.config.curatedKeyedTables
                .map((final table) => table.tableId.value)
                .join(',') ==
            'events_flattened,user_activity_daily,user_milestones' &&
        command.config.reportingKeyedTables.isEmpty,
    message:
        'privacy coverage inventory is not pinned to the warehouse contract',
  );
  _expect(condition: command.dryRun, message: 'dry-run flag was not parsed');
  _expect(
    condition: !command.config.allowGcloudAdcFallback,
    message: 'gcloud ADC fallback must be disabled by default',
  );
  final localOperatorCommand = PrivacyDeletionCommandConfig.parse(
    arguments: <String>[
      ..._baseArguments(includeRequestId: false),
      '--allow-gcloud-adc-fallback',
    ],
    environment: const <String, String>{},
    requestIdRequired: false,
  );
  _expect(
    condition: localOperatorCommand.config.allowGcloudAdcFallback,
    message: 'explicit local gcloud ADC fallback was not parsed',
  );
  final fallbackEnvironment = applicationDefaultProcessEnvironment(
    parentEnvironment: const <String, String>{
      'PATH': '/approved/bin',
      'GOOGLE_APPLICATION_CREDENTIALS': '/forbidden/key.json',
    },
  );
  _expect(
    condition:
        fallbackEnvironment['PATH'] == '/approved/bin' &&
        !fallbackEnvironment.containsKey('GOOGLE_APPLICATION_CREDENTIALS'),
    message: 'gcloud fallback environment retained an arbitrary key path',
  );

  _expectThrows<PrivacyDeletionValidationException>(
    body: () => PrivacyDeletionCommandConfig.parse(
      arguments: <String>[
        ..._baseArguments(includeRequestId: false),
        '--aggregate-rebuild-command',
        '/tmp/rebuild',
      ],
      environment: const <String, String>{},
      requestIdRequired: false,
    ),
    message: 'arbitrary aggregate command configuration was accepted',
  );
  for (final option in const <String>[
    '--auth-keyed-tables',
    '--curated-keyed-tables',
    '--reporting-keyed-tables',
    '--raw-retention-days',
    '--auth-wait-minutes',
    '--auth-poll-seconds',
  ]) {
    _expectThrows<PrivacyDeletionValidationException>(
      body: () => PrivacyDeletionCommandConfig.parse(
        arguments: <String>[
          ..._baseArguments(includeRequestId: false),
          option,
          'unsafe_override',
        ],
        environment: const <String, String>{},
        requestIdRequired: false,
      ),
      message: 'unsupported privacy lifecycle option $option was accepted',
    );
  }

  final duplicateDatasets = _baseArguments(includeRequestId: false);
  duplicateDatasets[duplicateDatasets.indexOf('--auth-dataset') + 1] =
      'analytics_123456789';
  _expectThrows<PrivacyDeletionValidationException>(
    body: () => PrivacyDeletionCommandConfig.parse(
      arguments: duplicateDatasets,
      environment: const <String, String>{},
      requestIdRequired: false,
    ),
    message: 'duplicate datasets were accepted',
  );
}

void _testCleanupPhases() {
  _expect(
    condition:
        !PrivacyDeletionCleanupPhase.preliminary.includeAuthTables &&
        PrivacyDeletionCleanupPhase.finalPass.includeAuthTables,
    message:
        'preliminary cleanup must preserve auth publication until the final pass',
  );
}

void _testSweepRanges() {
  final now = DateTime.utc(2026, 7, 31, 15);
  final latestComplete =
      PrivacyDeletionRepository.calculateLatestCompleteRawDate(
        now: now,
        latestRawTableDate: DateTime.utc(2026, 7, 31),
      );
  _expect(
    condition: formatUtcDate(date: latestComplete) == '2026-07-30',
    message: 'latest raw table suffix was not reduced by one day',
  );
  final capped = PrivacyDeletionRepository.calculateLatestCompleteRawDate(
    now: now,
    latestRawTableDate: DateTime.utc(2026, 8, 3),
  );
  _expect(
    condition: formatUtcDate(date: capped) == '2026-07-30',
    message: 'latest complete raw date was not capped at yesterday UTC',
  );
  final delayed = PrivacyDeletionRepository.calculateLatestCompleteRawDate(
    now: now,
    latestRawTableDate: DateTime.utc(2026, 7, 29),
  );
  _expect(
    condition: formatUtcDate(date: delayed) == '2026-07-28',
    message: 'delayed raw exports did not conservatively move the sweep anchor',
  );

  final gapRange = PrivacyDeletionRepository.calculateSweepRange(
    latestCompleteRawDate: latestComplete,
    lastSuccessDate: DateTime.utc(2026, 7, 20),
    rawRetentionDays: 90,
  );
  _expect(
    condition: formatUtcDate(date: gapRange.start) == '2026-07-21',
    message: 'watermark gap did not start at continuation',
  );
  _expect(
    condition: formatUtcDate(date: gapRange.end) == '2026-07-30',
    message: 'sweep did not end at the latest complete raw date',
  );
  final overlapRange = PrivacyDeletionRepository.calculateSweepRange(
    latestCompleteRawDate: latestComplete,
    lastSuccessDate: DateTime.utc(2026, 7, 29),
    rawRetentionDays: 90,
  );
  _expect(
    condition: formatUtcDate(date: overlapRange.start) == '2026-07-28',
    message: 'latest three complete UTC dates were not rescanned',
  );
  _expectThrows<PrivacyDeletionValidationException>(
    body: () => PrivacyDeletionRepository.calculateSweepRange(
      latestCompleteRawDate: latestComplete,
      lastSuccessDate: DateTime.utc(2026, 7, 31),
      rawRetentionDays: 90,
    ),
    message: 'checkpoint after the latest complete raw date was accepted',
  );
}

void _testAnalyticsAdminRequestShapes() {
  final appIdentifier = GaAppInstanceDeletionIdentifier(
    appInstanceId: AppInstanceId.parse(value: 'app-instance'),
  );
  _expect(
    condition:
        jsonEncode(appIdentifier.toRequestBody()) ==
        '{"appInstanceId":"app-instance"}',
    message: 'app-instance request does not use Admin API appInstanceId',
  );
  final legacyId = 'b' * 64;
  final legacyIdentifier = GaLegacyUserDeletionIdentifier(
    legacyUserId: LegacyFirebaseUserId.parse(value: legacyId),
  );
  _expect(
    condition: legacyIdentifier.toRequestBody().keys.single == 'userId',
    message: 'legacy Firebase request does not use Admin API userId',
  );

  final parameter = BigQueryStringArrayParameter(
    name: 'user_keys',
    values: <String>[legacyId],
  ).toJson();
  _expect(
    condition: parameter['name'] == 'user_keys',
    message: 'BigQuery value was not represented as a named parameter',
  );
}

Future<void> _testLatestSuccessfulAuthExportSql() async {
  final client = _FakeBigQueryClient(
    handler: ({required statement, required index}) {
      return const BigQueryStatementResult(
        rows: <Map<String, Object?>>[
          <String, Object?>{
            'run_cutoff': '2026-07-30T10:00:00Z',
            'published_at': '2026-07-30T10:05:00Z',
          },
        ],
        affectedRows: 0,
        dryRun: false,
      );
    },
  );
  final snapshot = await _api(client: client).latestSuccessfulAuthExport();
  _expect(condition: snapshot != null, message: 'auth snapshot was not loaded');
  _expect(
    condition:
        snapshot!.runCutoff == DateTime.utc(2026, 7, 30, 10) &&
        snapshot.publishedAt == DateTime.utc(2026, 7, 30, 10, 5),
    message: 'auth snapshot timestamps were parsed incorrectly',
  );
  final statement = client.statements.single;
  _expect(
    condition: statement.sql.contains(
      'ORDER BY published_at DESC, run_cutoff DESC',
    ),
    message: 'latest auth snapshot ordering is incorrect',
  );
  _expect(
    condition:
        !statement.sql.contains('status') &&
        !statement.sql.contains('reconciliation_passed') &&
        statement.parameters.isEmpty,
    message: 'latest auth query references columns absent from successful runs',
  );
}

Future<void> _testKeyedTableInventory() async {
  final validRows = <Map<String, Object?>>[
    <String, Object?>{
      'dataset_scope': 'auth',
      'table_name': 'auth_user_milestones',
    },
    <String, Object?>{
      'dataset_scope': 'auth',
      'table_name': 'auth_user_milestones_staging_run_12345',
    },
    for (final tableName in const <String>[
      'events_flattened',
      'user_activity_daily',
      'user_milestones',
    ])
      <String, Object?>{'dataset_scope': 'curated', 'table_name': tableName},
  ];
  final validClient = _FakeBigQueryClient(
    handler: ({required statement, required index}) => BigQueryStatementResult(
      rows: validRows,
      affectedRows: 0,
      dryRun: false,
    ),
  );
  await _api(
    client: validClient,
  ).validateKeyedTableInventory(allowAuthStagingTables: true);
  _expect(
    condition:
        validClient.statements.single.sql.contains(
          'INFORMATION_SCHEMA.COLUMNS',
        ) &&
        validClient.statements.single.sql.contains("column_name = 'user_key'"),
    message: 'keyed-table inventory does not inspect deployed user_key columns',
  );

  final stagingClient = _FakeBigQueryClient(
    handler: ({required statement, required index}) => BigQueryStatementResult(
      rows: validRows,
      affectedRows: 0,
      dryRun: false,
    ),
  );
  final stagingFailure =
      await _expectThrowsAsync<PrivacyDeletionOperationException>(
        body: () => _api(
          client: stagingClient,
        ).validateKeyedTableInventory(allowAuthStagingTables: false),
        message: 'auth staging table was accepted during final cleanup',
      );
  _expect(
    condition:
        stagingFailure.innerError is KeyedTableInventoryException &&
        (stagingFailure.innerError as KeyedTableInventoryException)
                .authStagingTableCount ==
            1,
    message: 'active auth staging inventory was not classified safely',
  );

  final invalidClient = _FakeBigQueryClient(
    handler: ({required statement, required index}) => BigQueryStatementResult(
      rows: <Map<String, Object?>>[
        ...validRows,
        <String, Object?>{
          'dataset_scope': 'curated',
          'table_name': 'untracked_user_export',
        },
      ],
      affectedRows: 0,
      dryRun: false,
    ),
  );
  final failure = await _expectThrowsAsync<PrivacyDeletionOperationException>(
    body: () => _api(
      client: invalidClient,
    ).validateKeyedTableInventory(allowAuthStagingTables: true),
    message: 'an untracked keyed table was accepted',
  );
  _expect(
    condition:
        failure.operation == PrivacyDeletionOperation.validateWarehouseSchema &&
        failure.innerError is KeyedTableInventoryException,
    message: 'untracked keyed table failure was not classified as verification',
  );
}

Future<void> _testRawDateAndInstallationDiscovery() async {
  final client = _FakeBigQueryClient(
    handler: ({required statement, required index}) {
      return switch (index) {
        0 => const BigQueryStatementResult(
          rows: <Map<String, Object?>>[
            <String, Object?>{
              'latest_raw_date': '2026-07-31',
              'intraday_table_count': '0',
              'unsupported_export_table_count': '0',
              'missing_daily_table_count': '0',
            },
          ],
          affectedRows: 0,
          dryRun: false,
        ),
        1 || 3 => const BigQueryStatementResult(
          rows: <Map<String, Object?>>[
            <String, Object?>{'table_name': 'events_20260710'},
            <String, Object?>{'table_name': 'events_20260713'},
          ],
          affectedRows: 0,
          dryRun: false,
        ),
        2 => const BigQueryStatementResult(
          rows: <Map<String, Object?>>[
            <String, Object?>{'user_pseudo_id': 'target-installation'},
          ],
          affectedRows: 0,
          dryRun: false,
        ),
        4 => const BigQueryStatementResult(
          rows: <Map<String, Object?>>[
            <String, Object?>{'user_pseudo_id': 'tombstone-installation'},
          ],
          affectedRows: 0,
          dryRun: false,
        ),
        _ => throw StateError('unexpected BigQuery statement'),
      };
    },
  );
  final api = _api(client: client);
  final latestRawDate = await api.latestRawEventTableDate();
  _expect(
    condition: latestRawDate == DateTime.utc(2026, 7, 31),
    message: 'latest raw table date was not discovered',
  );
  _expect(
    condition:
        client.statements.first.sql.contains('SAFE.PARSE_DATE') &&
        client.statements.first.sql.contains("r'^events_[0-9]{8}\$'") &&
        client.statements.first.sql.contains('intraday_table_count') &&
        client.statements.first.sql.contains('missing_daily_table_count'),
    message: 'raw inventory query does not fail closed on export drift or gaps',
  );

  final driftedClient = _FakeBigQueryClient(
    handler: ({required statement, required index}) =>
        const BigQueryStatementResult(
          rows: <Map<String, Object?>>[
            <String, Object?>{
              'latest_raw_date': '2026-07-31',
              'intraday_table_count': '1',
              'unsupported_export_table_count': '1',
              'missing_daily_table_count': '0',
            },
          ],
          affectedRows: 0,
          dryRun: false,
        ),
  );
  final driftFailure =
      await _expectThrowsAsync<PrivacyDeletionOperationException>(
        body: () => _api(client: driftedClient).latestRawEventTableDate(),
        message: 'intraday export drift was accepted by deletion',
      );
  _expect(
    condition:
        driftFailure.operation == PrivacyDeletionOperation.readRawTables &&
        driftFailure.innerError is RawTableInventoryException,
    message: 'raw export drift was not surfaced as an inventory failure',
  );

  final range = UtcDateRange.fromDates(
    start: DateTime.utc(2026, 7, 10),
    end: DateTime.utc(2026, 7, 12),
  );
  final targetInstallations = await api.discoverInstallationsForTarget(
    userKey: PseudonymousUserKey.parse(value: 'c' * 64),
    range: range,
  );
  _expect(
    condition: targetInstallations.single.value == 'target-installation',
    message: 'target installation was not decoded',
  );
  final targetTableScan = client.statements[1];
  final bufferedStart = _parameter<BigQueryDateParameter>(
    statement: targetTableScan,
    name: 'from_date',
  );
  final bufferedEnd = _parameter<BigQueryDateParameter>(
    statement: targetTableScan,
    name: 'through_date',
  );
  _expect(
    condition:
        formatUtcDate(date: bufferedStart.value) == '2026-07-09' &&
        formatUtcDate(date: bufferedEnd.value) == '2026-07-13',
    message: 'raw table discovery did not include a one-day date buffer',
  );
  final targetDiscovery = client.statements[2];
  _expect(
    condition:
        targetDiscovery.sql.contains('WHERE raw.user_key = @only_user_key') &&
        !targetDiscovery.sql.contains('permanent_deletion_exclusions') &&
        targetDiscovery.referencedDatasets.length == 1,
    message: 'target discovery still depends on a persisted exclusion row',
  );

  final tombstoneInstallations = await api
      .discoverInstallationsForAllTombstones(range: range);
  _expect(
    condition: tombstoneInstallations.single.value == 'tombstone-installation',
    message: 'tombstone installation was not decoded',
  );
  final tombstoneDiscovery = client.statements[4];
  _expect(
    condition:
        tombstoneDiscovery.sql.contains('permanent_deletion_exclusions') &&
        tombstoneDiscovery.sql.contains('JOIN') &&
        tombstoneDiscovery.parameters.isEmpty &&
        tombstoneDiscovery.referencedDatasets.length == 2,
    message: 'all-tombstone discovery no longer joins permanent exclusions',
  );
}

Future<void> _testFixedAggregateChain() async {
  final schema = _schema();
  _expect(
    condition:
        AggregateTransform.values
            .map((final transform) => transform.fileName)
            .join(',') ==
        '20_user_activity_daily.sql,30_user_milestones.sql,'
            '40_activation_retention.sql',
    message: 'fixed aggregate transform assets or order changed',
  );
  const repositoryLoader = RepositoryAggregateTransformLoader();
  for (final transform in AggregateTransform.values) {
    final checkedInTemplate = await repositoryLoader.load(transform: transform);
    _expect(
      condition:
          checkedInTemplate.isNotEmpty &&
          checkedInTemplate.contains('{{PROJECT_ID}}'),
      message: 'checked-in aggregate transform could not be loaded',
    );
  }
  final templates = <AggregateTransform, String>{
    for (final transform in AggregateTransform.values)
      transform:
          '-- ${transform.fileName}\n'
          'SELECT * FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.source`;\n'
          'DELETE FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.'
          '${transform.modelName}` WHERE TRUE;',
  };
  final dryRunLoader = _FakeAggregateTransformLoader(templates: templates);
  final dryRunClient = _FakeBigQueryClient(
    handler: ({required statement, required index}) => BigQueryStatementResult(
      rows: const <Map<String, Object?>>[],
      affectedRows: 0,
      dryRun: statement.dryRun,
    ),
  );
  final dryRunResult = await FixedAggregateRebuilder(
    client: dryRunClient,
    schema: schema,
    loader: dryRunLoader,
  ).rebuild(dryRun: true);
  _expect(
    condition:
        dryRunResult.plannedOperations == 3 &&
        dryRunResult.executedOperations == 0 &&
        dryRunClient.statements.length == 3,
    message: 'dry-run did not plan exactly the fixed three-script chain',
  );
  _expect(
    condition:
        dryRunLoader.loaded.join(',') == AggregateTransform.values.join(','),
    message: 'aggregate scripts were not loaded sequentially',
  );
  for (var index = 0; index < dryRunClient.statements.length; index++) {
    final statement = dryRunClient.statements[index];
    _expect(
      condition:
          statement.dryRun &&
          statement.isMutation &&
          statement.parameters.isEmpty &&
          statement.sql.contains(AggregateTransform.values[index].fileName) &&
          !statement.sql.contains('{{'),
      message: 'aggregate dry-run script was not safely rendered and planned',
    );
  }
  _expectThrows<PrivacyDeletionValidationException>(
    body: () => renderAggregateTransform(
      template: "SELECT TIMESTAMP('{{RAW_EXPORT_START_AT}}')",
      schema: schema,
    ),
    message: 'timestamp placeholder was accepted by aggregate rendering',
  );
  _expectThrows<PrivacyDeletionValidationException>(
    body: () => renderAggregateTransform(
      template: 'SELECT * FROM `{{project}}.dataset.table`',
      schema: schema,
    ),
    message: 'lowercase arbitrary placeholder was accepted',
  );

  final applyClient = _FakeBigQueryClient(
    handler: ({required statement, required index}) {
      return switch (index) {
        0 => const BigQueryStatementResult(
          rows: <Map<String, Object?>>[
            <String, Object?>{'rebuild_started_at': '2026-07-31T12:00:00Z'},
          ],
          affectedRows: 0,
          dryRun: false,
        ),
        4 => const BigQueryStatementResult(
          rows: <Map<String, Object?>>[
            <String, Object?>{'matching_count': '3'},
          ],
          affectedRows: 0,
          dryRun: false,
        ),
        _ => const BigQueryStatementResult(
          rows: <Map<String, Object?>>[],
          affectedRows: 0,
          dryRun: false,
        ),
      };
    },
  );
  final applyResult = await FixedAggregateRebuilder(
    client: applyClient,
    schema: schema,
    loader: _FakeAggregateTransformLoader(templates: templates),
  ).rebuild(dryRun: false);
  _expect(
    condition:
        applyResult.executedOperations == 3 &&
        applyClient.statements.length == 5 &&
        applyClient.statements.first.sql.contains('CURRENT_TIMESTAMP()'),
    message: 'apply did not timestamp and execute the fixed chain',
  );
  final verification = applyClient.statements.last;
  _expect(
    condition:
        verification.sql.contains('user_activity_daily') &&
        verification.sql.contains('user_milestones') &&
        verification.sql.contains('activation_retention') &&
        verification.sql.contains('completed_at >= @rebuild_started_at') &&
        verification.sql.contains(
          'ORDER BY published_at DESC, run_cutoff DESC',
        ) &&
        verification.sql.contains('auth_snapshot_published_at'),
    message: 'aggregate completion verification is incomplete',
  );

  final failedClient = _FakeBigQueryClient(
    handler: ({required statement, required index}) {
      return switch (index) {
        0 => const BigQueryStatementResult(
          rows: <Map<String, Object?>>[
            <String, Object?>{'rebuild_started_at': '2026-07-31T12:00:00Z'},
          ],
          affectedRows: 0,
          dryRun: false,
        ),
        4 => const BigQueryStatementResult(
          rows: <Map<String, Object?>>[
            <String, Object?>{'matching_count': '2'},
          ],
          affectedRows: 0,
          dryRun: false,
        ),
        _ => const BigQueryStatementResult(
          rows: <Map<String, Object?>>[],
          affectedRows: 0,
          dryRun: false,
        ),
      };
    },
  );
  final failure = await _expectThrowsAsync<AggregateRebuildException>(
    body: () => FixedAggregateRebuilder(
      client: failedClient,
      schema: schema,
      loader: _FakeAggregateTransformLoader(templates: templates),
    ).rebuild(dryRun: false),
    message: 'incomplete aggregate transform state was accepted',
  );
  _expect(
    condition: failure.innerError is AggregateTransformVerificationException,
    message: 'aggregate verification failure lost its typed inner error',
  );
}

Future<void> _testStatusVerification() async {
  final completedClient = _FakeBigQueryClient(
    handler: ({required statement, required index}) {
      return index == 0
          ? const BigQueryStatementResult(
              rows: <Map<String, Object?>>[],
              affectedRows: 0,
              dryRun: false,
            )
          : const BigQueryStatementResult(
              rows: <Map<String, Object?>>[
                <String, Object?>{'status': 'completed'},
              ],
              affectedRows: 0,
              dryRun: false,
            );
    },
  );
  await _api(client: completedClient).updateTargetStatus(
    requestId: PrivacyRequestId.parse(value: 'request_123'),
    status: PrivacyDeletionTargetStatus.completed,
    failureKind: null,
  );
  _expect(
    condition:
        completedClient.statements.length == 2 &&
        completedClient.statements.first.sql.contains(
          'status != @completed_status',
        ) &&
        completedClient.statements.last.sql.contains('SELECT status'),
    message: 'completed status is not terminal and read-back verified',
  );

  final mismatchClient = _FakeBigQueryClient(
    handler: ({required statement, required index}) {
      return index == 0
          ? const BigQueryStatementResult(
              rows: <Map<String, Object?>>[],
              affectedRows: 0,
              dryRun: false,
            )
          : const BigQueryStatementResult(
              rows: <Map<String, Object?>>[
                <String, Object?>{'status': 'processing'},
              ],
              affectedRows: 0,
              dryRun: false,
            );
    },
  );
  final failure = await _expectThrowsAsync<PrivacyDeletionOperationException>(
    body: () => _api(client: mismatchClient).updateTargetStatus(
      requestId: PrivacyRequestId.parse(value: 'request_123'),
      status: PrivacyDeletionTargetStatus.completed,
      failureKind: null,
    ),
    message: 'status update succeeded without reaching requested state',
  );
  _expect(
    condition:
        failure.failureKind == PrivacyDeletionFailureKind.statusUpdate &&
        failure.innerError is TargetStatusMismatchException,
    message: 'status read-back failure lost its typed cause',
  );

  final missingClient = _FakeBigQueryClient(
    handler: ({required statement, required index}) =>
        const BigQueryStatementResult(
          rows: <Map<String, Object?>>[],
          affectedRows: 0,
          dryRun: false,
        ),
  );
  final missingFailure =
      await _expectThrowsAsync<PrivacyDeletionOperationException>(
        body: () => _api(client: missingClient).updateTargetStatus(
          requestId: PrivacyRequestId.parse(value: 'request_123'),
          status: PrivacyDeletionTargetStatus.retryable,
          failureKind: PrivacyDeletionFailureKind.warehouseRead,
        ),
        message: 'status update succeeded for a missing target',
      );
  _expect(
    condition:
        missingFailure.failureKind == PrivacyDeletionFailureKind.statusUpdate &&
        missingFailure.innerError is TargetStatusCardinalityException,
    message: 'missing target status failure lost its typed cause',
  );
}

void _testAggregateOnlyOutput() {
  final summary = PrivacyDeletionSummary(
    operation: PrivacyDeletionOperationKind.request,
    outcome: PrivacyDeletionOutcome.planned,
    dryRun: true,
    targetsConsidered: 1,
    authExportReadiness: AuthExportReadiness.notReady,
    cleanup: const CleanupResult.none(),
    failureKind: null,
  );
  final output = jsonEncode(
    summary.toAggregateJson(
      credentialSource: AdcCredentialSource.notUsed.wireValue,
      credentialFallback: false,
    ),
  );
  for (final forbidden in const <String>[
    'request_id',
    'user_key',
    'user_pseudo_id',
    'app_instance_id',
  ]) {
    _expect(
      condition: !output.contains(forbidden),
      message: 'aggregate output exposed $forbidden',
    );
  }
}

List<String> _baseArguments({required bool includeRequestId}) {
  return <String>[
    '--project',
    'sesori-ai',
    '--location',
    'EU',
    '--analytics-property-id',
    '123456789',
    '--raw-dataset',
    'analytics_123456789',
    '--auth-dataset',
    'sesori_analytics_auth_private',
    '--privacy-dataset',
    'sesori_analytics_privacy_private',
    '--controls-dataset',
    'sesori_analytics_controls',
    '--curated-dataset',
    'sesori_analytics_curated',
    '--reporting-dataset',
    'sesori_analytics_reporting',
    if (includeRequestId) ...<String>['--request-id', 'request_123'],
  ];
}

PrivacyDeletionApi _api({required BigQueryPrivacyDeletionClient client}) {
  return PrivacyDeletionApi(
    bigQueryClient: client,
    gaUserDeletionClient: const _FakeGaUserDeletionClient(),
    schema: _schema(),
    aggregateRebuilder: const _FakeAggregateRebuilder(),
    parameterBatchSize: 10,
  );
}

PrivacyDeletionWarehouseSchema _schema() {
  final projectId = GcpProjectId.parse(value: 'sesori-ai');
  final raw = _dataset(projectId: projectId, datasetId: 'analytics_123456789');
  final auth = _dataset(projectId: projectId, datasetId: 'auth_private');
  final privacy = _dataset(projectId: projectId, datasetId: 'privacy_private');
  final controls = _dataset(projectId: projectId, datasetId: 'controls');
  final curated = _dataset(projectId: projectId, datasetId: 'curated');
  final reporting = _dataset(projectId: projectId, datasetId: 'reporting');
  return PrivacyDeletionWarehouseSchema(
    rawDataset: raw,
    authDataset: auth,
    privacyDataset: privacy,
    controlsDataset: controls,
    curatedDataset: curated,
    reportingDataset: reporting,
    targetsTable: _table(
      dataset: privacy,
      tableId: 'product_analytics_deletion_targets',
    ),
    exclusionsTable: _table(
      dataset: controls,
      tableId: 'permanent_deletion_exclusions',
    ),
    authExportRunsTable: _table(
      dataset: auth,
      tableId: 'product_analytics_export_runs',
    ),
    sweepStateTable: _table(
      dataset: controls,
      tableId: 'product_analytics_privacy_sweep_state',
    ),
    authKeyedTables: <BigQueryTableReference>[
      _table(dataset: auth, tableId: 'auth_user_milestones'),
    ],
    curatedKeyedTables: <BigQueryTableReference>[
      _table(dataset: curated, tableId: 'events_flattened'),
      _table(dataset: curated, tableId: 'user_activity_daily'),
      _table(dataset: curated, tableId: 'user_milestones'),
    ],
    reportingKeyedTables: const <BigQueryTableReference>[],
  );
}

BigQueryDatasetReference _dataset({
  required GcpProjectId projectId,
  required String datasetId,
}) {
  return BigQueryDatasetReference(
    projectId: projectId,
    datasetId: BigQueryDatasetId.parse(field: 'test_dataset', value: datasetId),
  );
}

BigQueryTableReference _table({
  required BigQueryDatasetReference dataset,
  required String tableId,
}) {
  return BigQueryTableReference(
    dataset: dataset,
    tableId: BigQueryTableId.parse(field: 'test_table', value: tableId),
  );
}

T _parameter<T extends BigQueryParameter>({
  required BigQueryStatement statement,
  required String name,
}) {
  return statement.parameters.whereType<T>().singleWhere(
    (final parameter) => parameter.name == name,
  );
}

void _expect({required bool condition, required String message}) {
  if (!condition) {
    throw StateError(message);
  }
}

T _expectThrows<T extends Object>({
  required void Function() body,
  required String message,
}) {
  try {
    body();
  } catch (error) {
    if (error is T) {
      return error;
    }
    throw StateError('$message; received ${error.runtimeType}');
  }
  throw StateError(message);
}

Future<T> _expectThrowsAsync<T extends Object>({
  required Future<void> Function() body,
  required String message,
}) async {
  try {
    await body();
  } catch (error) {
    if (error is T) {
      return error;
    }
    throw StateError('$message; received ${error.runtimeType}');
  }
  throw StateError(message);
}

typedef _BigQueryHandler =
    BigQueryStatementResult Function({
      required BigQueryStatement statement,
      required int index,
    });

final class _FakeBigQueryClient implements BigQueryPrivacyDeletionClient {
  _FakeBigQueryClient({required _BigQueryHandler handler}) : _handler = handler;

  final _BigQueryHandler _handler;
  final List<BigQueryStatement> statements = <BigQueryStatement>[];

  @override
  Future<BigQueryStatementResult> execute({
    required BigQueryStatement statement,
  }) async {
    final index = statements.length;
    statements.add(statement);
    return _handler(statement: statement, index: index);
  }

  @override
  void close() {}
}

final class _FakeAggregateTransformLoader implements AggregateTransformLoader {
  _FakeAggregateTransformLoader({
    required Map<AggregateTransform, String> templates,
  }) : _templates = Map<AggregateTransform, String>.unmodifiable(templates);

  final Map<AggregateTransform, String> _templates;
  final List<AggregateTransform> loaded = <AggregateTransform>[];

  @override
  Future<String> load({required AggregateTransform transform}) async {
    loaded.add(transform);
    return _templates[transform]!;
  }
}

final class _FakeAggregateRebuilder implements AggregateRebuilder {
  const _FakeAggregateRebuilder();

  @override
  Future<AggregateRebuildResult> rebuild({required bool dryRun}) async {
    return AggregateRebuildResult(
      plannedOperations: 3,
      executedOperations: dryRun ? 0 : 3,
    );
  }
}

final class _FakeGaUserDeletionClient implements GaUserDeletionClient {
  const _FakeGaUserDeletionClient();

  @override
  Future<GaUserDeletionSubmission> submit({
    required GaUserDeletionIdentifier identifier,
  }) async {
    return const GaUserDeletionSubmission(deletionRequestTime: null);
  }

  @override
  void close() {}
}
