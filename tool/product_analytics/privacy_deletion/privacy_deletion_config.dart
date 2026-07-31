import 'privacy_deletion_models.dart';

final class PrivacyDeletionConfig {
  const PrivacyDeletionConfig({
    required this.projectId,
    required this.location,
    required this.analyticsPropertyId,
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
    required this.authKeyedTables,
    required this.curatedKeyedTables,
    required this.reportingKeyedTables,
    required this.rawRetentionDays,
    required this.queryTimeout,
    required this.parameterBatchSize,
    required this.allowGcloudAdcFallback,
  });

  final GcpProjectId projectId;
  final BigQueryLocation location;
  final AnalyticsPropertyId analyticsPropertyId;
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
  final int rawRetentionDays;
  final Duration queryTimeout;
  final int parameterBatchSize;
  final bool allowGcloudAdcFallback;

  List<BigQueryDatasetReference> get allowedDatasets =>
      <BigQueryDatasetReference>[
        rawDataset,
        authDataset,
        privacyDataset,
        controlsDataset,
        curatedDataset,
        reportingDataset,
      ];
}

final class PrivacyDeletionCommandConfig {
  const PrivacyDeletionCommandConfig({
    required this.config,
    required this.requestId,
    required this.dryRun,
  });

  factory PrivacyDeletionCommandConfig.parse({
    required List<String> arguments,
    required Map<String, String> environment,
    required bool requestIdRequired,
  }) {
    final parsed = _ParsedArguments.parse(arguments: arguments);
    final projectId = GcpProjectId.parse(
      value: parsed.requiredValue(
        name: 'project',
        environmentName: 'SESORI_ANALYTICS_PROJECT',
        environment: environment,
      ),
    );
    final rawDataset = _dataset(
      projectId: projectId,
      field: 'raw_dataset',
      value: parsed.requiredValue(
        name: 'raw-dataset',
        environmentName: 'SESORI_ANALYTICS_RAW_DATASET',
        environment: environment,
      ),
    );
    final authDataset = _dataset(
      projectId: projectId,
      field: 'auth_dataset',
      value: parsed.requiredValue(
        name: 'auth-dataset',
        environmentName: 'SESORI_ANALYTICS_AUTH_DATASET',
        environment: environment,
      ),
    );
    final privacyDataset = _dataset(
      projectId: projectId,
      field: 'privacy_dataset',
      value: parsed.requiredValue(
        name: 'privacy-dataset',
        environmentName: 'SESORI_ANALYTICS_PRIVACY_DATASET',
        environment: environment,
      ),
    );
    final controlsDataset = _dataset(
      projectId: projectId,
      field: 'controls_dataset',
      value: parsed.requiredValue(
        name: 'controls-dataset',
        environmentName: 'SESORI_ANALYTICS_CONTROLS_DATASET',
        environment: environment,
      ),
    );
    final curatedDataset = _dataset(
      projectId: projectId,
      field: 'curated_dataset',
      value: parsed.requiredValue(
        name: 'curated-dataset',
        environmentName: 'SESORI_ANALYTICS_CURATED_DATASET',
        environment: environment,
      ),
    );
    final reportingDataset = _dataset(
      projectId: projectId,
      field: 'reporting_dataset',
      value: parsed.requiredValue(
        name: 'reporting-dataset',
        environmentName: 'SESORI_ANALYTICS_REPORTING_DATASET',
        environment: environment,
      ),
    );

    final datasets = <BigQueryDatasetReference>[
      rawDataset,
      authDataset,
      privacyDataset,
      controlsDataset,
      curatedDataset,
      reportingDataset,
    ];
    final datasetKeys = datasets
        .map((final value) => value.allowlistKey)
        .toSet();
    if (datasetKeys.length != datasets.length) {
      throw const PrivacyDeletionValidationException(
        field: 'datasets',
        requirement:
            'six distinct raw/auth/privacy/controls/curated/reporting datasets',
      );
    }

    final requestIdValue = parsed.optionalValue(
      name: 'request-id',
      environmentName: 'SESORI_PRIVACY_REQUEST_ID',
      environment: environment,
    );
    if (requestIdRequired && requestIdValue == null) {
      throw const PrivacyDeletionValidationException(
        field: 'request_id',
        requirement: '--request-id for a manual deletion run',
      );
    }
    if (!requestIdRequired && requestIdValue != null) {
      throw const PrivacyDeletionValidationException(
        field: 'request_id',
        requirement: 'no request ID for a sweep',
      );
    }

    final config = PrivacyDeletionConfig(
      projectId: projectId,
      location: BigQueryLocation.parse(
        value: parsed.requiredValue(
          name: 'location',
          environmentName: 'SESORI_ANALYTICS_LOCATION',
          environment: environment,
        ),
      ),
      analyticsPropertyId: AnalyticsPropertyId.parse(
        value: parsed.requiredValue(
          name: 'analytics-property-id',
          environmentName: 'SESORI_ANALYTICS_PROPERTY_ID',
          environment: environment,
        ),
      ),
      rawDataset: rawDataset,
      authDataset: authDataset,
      privacyDataset: privacyDataset,
      controlsDataset: controlsDataset,
      curatedDataset: curatedDataset,
      reportingDataset: reportingDataset,
      targetsTable: _table(
        dataset: privacyDataset,
        field: 'targets_table',
        value: parsed.valueOrDefault(
          name: 'targets-table',
          defaultValue: 'product_analytics_deletion_targets',
        ),
      ),
      exclusionsTable: _table(
        dataset: controlsDataset,
        field: 'exclusions_table',
        value: parsed.valueOrDefault(
          name: 'exclusions-table',
          defaultValue: 'permanent_deletion_exclusions',
        ),
      ),
      publicationGuardTable: _table(
        dataset: controlsDataset,
        field: 'publication_guard_table',
        value: 'keyed_publication_guard',
      ),
      authExportRunsTable: _table(
        dataset: authDataset,
        field: 'auth_export_runs_table',
        value: parsed.valueOrDefault(
          name: 'auth-export-runs-table',
          defaultValue: 'product_analytics_export_runs',
        ),
      ),
      sweepStateTable: _table(
        dataset: controlsDataset,
        field: 'sweep_state_table',
        value: parsed.valueOrDefault(
          name: 'sweep-state-table',
          defaultValue: 'product_analytics_privacy_sweep_state',
        ),
      ),
      authKeyedTables: <BigQueryTableReference>[
        _table(
          dataset: authDataset,
          field: 'auth_keyed_tables',
          value: 'auth_user_milestones',
        ),
      ],
      curatedKeyedTables: <BigQueryTableReference>[
        for (final tableName in const <String>[
          'events_flattened',
          'user_activity_daily',
          'user_milestones',
        ])
          _table(
            dataset: curatedDataset,
            field: 'curated_keyed_tables',
            value: tableName,
          ),
      ],
      reportingKeyedTables: const <BigQueryTableReference>[],
      rawRetentionDays: 90,
      queryTimeout: Duration(
        minutes: parsed.boundedInt(
          name: 'query-timeout-minutes',
          defaultValue: 30,
          minimum: 1,
          maximum: 120,
        ),
      ),
      parameterBatchSize: parsed.boundedInt(
        name: 'parameter-batch-size',
        defaultValue: 500,
        minimum: 1,
        maximum: 5000,
      ),
      allowGcloudAdcFallback: parsed.hasFlag(name: 'allow-gcloud-adc-fallback'),
    );

    return PrivacyDeletionCommandConfig(
      config: config,
      requestId: requestIdValue == null
          ? null
          : PrivacyRequestId.parse(value: requestIdValue),
      dryRun: parsed.hasFlag(name: 'dry-run'),
    );
  }

  final PrivacyDeletionConfig config;
  final PrivacyRequestId? requestId;
  final bool dryRun;
}

BigQueryDatasetReference _dataset({
  required GcpProjectId projectId,
  required String field,
  required String value,
}) {
  return BigQueryDatasetReference(
    projectId: projectId,
    datasetId: BigQueryDatasetId.parse(field: field, value: value),
  );
}

BigQueryTableReference _table({
  required BigQueryDatasetReference dataset,
  required String field,
  required String value,
}) {
  return BigQueryTableReference(
    dataset: dataset,
    tableId: BigQueryTableId.parse(field: field, value: value),
  );
}

final class _ParsedArguments {
  const _ParsedArguments({required this.values});

  factory _ParsedArguments.parse({required List<String> arguments}) {
    const booleanFlags = <String>{'dry-run', 'allow-gcloud-adc-fallback'};
    const valueFlags = <String>{
      'project',
      'location',
      'analytics-property-id',
      'raw-dataset',
      'auth-dataset',
      'privacy-dataset',
      'controls-dataset',
      'curated-dataset',
      'reporting-dataset',
      'targets-table',
      'exclusions-table',
      'auth-export-runs-table',
      'sweep-state-table',
      'query-timeout-minutes',
      'parameter-batch-size',
      'request-id',
    };
    final values = <String, String>{};

    for (var index = 0; index < arguments.length; index++) {
      final raw = arguments[index];
      if (!raw.startsWith('--')) {
        throw const PrivacyDeletionValidationException(
          field: 'arguments',
          requirement: 'named --flag value arguments only',
        );
      }
      final equalsIndex = raw.indexOf('=');
      final name = raw.substring(2, equalsIndex < 0 ? null : equalsIndex);
      if (booleanFlags.contains(name)) {
        if (equalsIndex >= 0 || values.containsKey(name)) {
          throw PrivacyDeletionValidationException(
            field: name,
            requirement: 'a single value-less flag',
          );
        }
        values[name] = 'true';
        continue;
      }
      if (!valueFlags.contains(name)) {
        throw PrivacyDeletionValidationException(
          field: 'arguments',
          requirement: 'a supported option; unknown --$name',
        );
      }
      final String value;
      if (equalsIndex >= 0) {
        value = raw.substring(equalsIndex + 1);
      } else {
        if (index + 1 >= arguments.length ||
            arguments[index + 1].startsWith('--')) {
          throw PrivacyDeletionValidationException(
            field: name,
            requirement: 'a non-empty value',
          );
        }
        index += 1;
        value = arguments[index];
      }
      if (value.isEmpty) {
        throw PrivacyDeletionValidationException(
          field: name,
          requirement: 'a non-empty value',
        );
      }
      if (values.containsKey(name)) {
        throw PrivacyDeletionValidationException(
          field: name,
          requirement: 'a single value',
        );
      } else {
        values[name] = value;
      }
    }
    return _ParsedArguments(values: values);
  }

  final Map<String, String> values;

  bool hasFlag({required String name}) => values[name] == 'true';

  String requiredValue({
    required String name,
    required String environmentName,
    required Map<String, String> environment,
  }) {
    final value = optionalValue(
      name: name,
      environmentName: environmentName,
      environment: environment,
    );
    if (value == null) {
      throw PrivacyDeletionValidationException(
        field: name,
        requirement: '--$name or $environmentName',
      );
    }
    return value;
  }

  String? optionalValue({
    required String name,
    required String environmentName,
    required Map<String, String> environment,
  }) {
    final value = values[name] ?? environment[environmentName];
    return value == null || value.isEmpty ? null : value;
  }

  String valueOrDefault({required String name, required String defaultValue}) {
    return values[name] ?? defaultValue;
  }

  int boundedInt({
    required String name,
    required int defaultValue,
    required int minimum,
    required int maximum,
  }) {
    final raw = values[name];
    final parsed = raw == null ? defaultValue : int.tryParse(raw);
    if (parsed == null || parsed < minimum || parsed > maximum) {
      throw PrivacyDeletionValidationException(
        field: name,
        requirement: 'an integer from $minimum through $maximum',
      );
    }
    return parsed;
  }
}

const String privacyDeletionUsage = '''
Required configuration (flag or SESORI_ANALYTICS_* environment variable):
  --project --location --analytics-property-id
  --raw-dataset --auth-dataset --privacy-dataset --controls-dataset
  --curated-dataset --reporting-dataset

Manual run also requires --request-id. Add --dry-run to execute reads and
BigQuery plans without mutations, status changes, or upstream calls.
Production jobs use the attached metadata-server identity only. An approved
operator may add --allow-gcloud-adc-fallback for an explicit local ADC run.
''';
