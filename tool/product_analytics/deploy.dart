import 'dart:convert';
import 'dart:io';

const String _help = '''
Deploy Sesori product analytics BigQuery SQL.

Usage:
  dart tool/product_analytics/deploy.dart [mode] \\
    --project <project-id> \\
    --location <bigquery-location> \\
    --raw-dataset-id <dataset-id> \\
    --auth-dataset-id <dataset-id> \\
    --privacy-dataset-id <dataset-id> \\
    --controls-dataset-id <dataset-id> \\
    --curated-dataset-id <dataset-id> \\
    --reporting-dataset-id <dataset-id> \\
    --raw-export-start-at <UTC-RFC3339> \\
    --behavioral-schema-v1-start-at <UTC-RFC3339> \\
    [--transform-service-account <service-account-email>] \\
    [--apply-schedules]

Modes:
  (none)       Validate the manifest and render every SQL template in memory.
               No BigQuery command is run and no resource is changed.
  --dry-run    Run a best-effort whole-script BigQuery dry run for each numeric
               SQL asset and print its byte estimate and estimate accuracy.
  --apply      Dry-run and then execute each numeric SQL asset in dependency
               order. This is the only mode that mutates BigQuery resources.

Schedule deployment:
  Scheduled-query transfer configs are created or updated only when --apply,
  --apply-schedules, and --transform-service-account are all supplied. Existing
  configs are matched by exact display name. Scheduled DML/DDL scripts own their
  writes, so transfer configs have no destination table setting. The operation
  fails before schedule writes if a prefixed Sesori config is not in the
  manifest; obsolete configs are never auto-deleted.

Cost guardrail:
  BigQuery's scheduled_query data source does not expose a runtime
  maximum_bytes_billed parameter. schedules.json maxBytesBilled values allocate
  at most 1.75 GiB/day to the transform principal and bound direct apply jobs.
  Configure project/principal query quotas to guard scheduled runs at runtime.
  BigQuery SCRIPT dry-run estimates can be LOWER_BOUND and are best-effort
  validation.

Other:
  --help, -h   Show this help.
''';

const Set<String> _requiredValueFlags = <String>{
  '--project',
  '--location',
  '--raw-dataset-id',
  '--auth-dataset-id',
  '--privacy-dataset-id',
  '--controls-dataset-id',
  '--curated-dataset-id',
  '--reporting-dataset-id',
  '--raw-export-start-at',
  '--behavioral-schema-v1-start-at',
};

const Set<String> _optionalValueFlags = <String>{'--transform-service-account'};

const Set<String> _booleanFlags = <String>{
  '--dry-run',
  '--apply',
  '--apply-schedules',
};

const Set<String> _scheduleManifestFields = <String>{
  'queryFile',
  'displayName',
  'cadence',
  'recentDateRecomputationWindow',
  'maxBytesBilled',
};

const String _scheduleDisplayNamePrefix = 'Sesori Product Analytics - ';
const int _maxScheduledQueryBytes = 536870912;
const int _maxScheduledQueryDailyBytes = 1879048192;

const Map<String, int> _deploymentOnlyMaxBytesBilled = <String, int>{
  '00_datasets.sql': 1073741824,
  '50_reporting_views.sql': 1073741824,
};

const String _runtimeCostNotice =
    'Cost guardrail: scheduled_query has no runtime maximum_bytes_billed '
    'parameter. Manifest allocations total at most 1.75 GiB/day and direct '
    'apply jobs use maximum_bytes_billed; project/principal query quotas must '
    'guard scheduled runs. Whole-script dry-run estimates are best-effort and '
    'may have LOWER_BOUND accuracy.';

final RegExp _projectIdPattern = RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$');
final RegExp _locationPattern = RegExp(r'^[A-Za-z0-9-]+$');
final RegExp _datasetIdPattern = RegExp(r'^[A-Za-z0-9_]{1,1024}$');
final RegExp _serviceAccountPattern = RegExp(
  r'^[a-z0-9][a-z0-9-]{4,28}[a-z0-9]@'
  r'[a-z][a-z0-9-]{4,28}[a-z0-9]\.iam\.gserviceaccount\.com$',
);
final RegExp _utcTimestampPattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})'
  r'(?:\.\d{1,6})?Z$',
);
final RegExp _numericSqlFilePattern = RegExp(r'^([0-9]+)_[a-z0-9_]+\.sql$');
final RegExp _placeholderPattern = RegExp(r'\{\{[^{}]+\}\}');
final RegExp _printableAsciiPattern = RegExp(r'^[\x20-\x7E]+$');
final RegExp _dailyCadencePattern = RegExp(
  r'^every day (?:[01][0-9]|2[0-3]):[0-5][0-9]$',
);

enum _Mode { renderOnly, dryRun, apply }

enum _DryRunAccuracy {
  unknown(wireValue: 'UNKNOWN'),
  precise(wireValue: 'PRECISE'),
  lowerBound(wireValue: 'LOWER_BOUND'),
  upperBound(wireValue: 'UPPER_BOUND');

  const _DryRunAccuracy({required this.wireValue});

  final String wireValue;

  static _DryRunAccuracy? tryParse({required Object? value}) {
    for (final accuracy in values) {
      if (accuracy.wireValue == value) {
        return accuracy;
      }
    }
    return null;
  }
}

class _CliError implements Exception {
  const _CliError({required this.message}) : cause = null;

  const _CliError.withCause({required this.message, required Object cause})
    : cause = cause;

  final String message;
  final Object? cause;
}

class _Options {
  const _Options({
    required this.mode,
    required this.applySchedules,
    required this.projectId,
    required this.location,
    required this.rawDatasetId,
    required this.authDatasetId,
    required this.privacyDatasetId,
    required this.controlsDatasetId,
    required this.curatedDatasetId,
    required this.reportingDatasetId,
    required this.rawExportStartAt,
    required this.behavioralSchemaV1StartAt,
    required this.transformServiceAccount,
  });

  final _Mode mode;
  final bool applySchedules;
  final String projectId;
  final String location;
  final String rawDatasetId;
  final String authDatasetId;
  final String privacyDatasetId;
  final String controlsDatasetId;
  final String curatedDatasetId;
  final String reportingDatasetId;
  final String rawExportStartAt;
  final String behavioralSchemaV1StartAt;
  final String? transformServiceAccount;
}

class _ScheduleDefinition {
  const _ScheduleDefinition({
    required this.queryFile,
    required this.displayName,
    required this.cadence,
    required this.recentDateRecomputationWindow,
    required this.maxBytesBilled,
    required this.dependencyOrder,
  });

  final String queryFile;
  final String displayName;
  final String cadence;
  final int recentDateRecomputationWindow;
  final int maxBytesBilled;
  final int dependencyOrder;
}

class _SqlAsset {
  const _SqlAsset({
    required this.fileName,
    required this.dependencyOrder,
    required this.renderedSql,
    required this.maxBytesBilled,
    required this.schedule,
  });

  final String fileName;
  final int dependencyOrder;
  final String renderedSql;
  final int maxBytesBilled;
  final _ScheduleDefinition? schedule;
}

class _CommandResult {
  const _CommandResult({required this.standardOutput});

  final String standardOutput;
}

class _DryRunEstimate {
  const _DryRunEstimate({
    required this.totalBytesProcessed,
    required this.accuracy,
  });

  final String? totalBytesProcessed;
  final _DryRunAccuracy accuracy;
}

Future<void> main(final List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.write(_help);
    return;
  }

  try {
    final options = _parseOptions(args: args);
    final productAnalyticsDirectory = File.fromUri(Platform.script).parent;
    final sqlDirectory = Directory(
      _joinPath(parent: productAnalyticsDirectory.path, child: 'sql'),
    );
    final schedules = await _loadSchedules(
      path: _joinPath(parent: sqlDirectory.path, child: 'schedules.json'),
    );
    final assets = await _loadSqlAssets(
      directory: sqlDirectory,
      schedules: schedules,
      replacements: _placeholderReplacements(options: options),
    );

    _printValidatedPlan(assets: assets, schedules: schedules);
    stdout.writeln(_runtimeCostNotice);

    if (options.mode == _Mode.renderOnly) {
      stdout.writeln(
        'Validation complete. No BigQuery commands were run and no resources '
        'were changed.',
      );
      return;
    }

    final bq = _BqRunner(
      projectId: options.projectId,
      location: options.location,
    );
    for (final asset in assets) {
      stdout.writeln(
        'Dry-running ${asset.fileName} with allocatedBytes='
        '${asset.maxBytesBilled}.',
      );
      await bq.runQuery(asset: asset, dryRun: true);

      if (options.mode == _Mode.apply) {
        stdout.writeln('Applying ${asset.fileName}.');
        await bq.runQuery(asset: asset, dryRun: false);
      }
    }

    if (options.mode == _Mode.dryRun) {
      stdout.writeln(
        'Best-effort whole-script dry run complete. No resources were changed '
        'by this tool.',
      );
      return;
    }

    if (options.applySchedules) {
      await _applySchedules(
        bq: bq,
        schedules: schedules,
        assets: assets,
        serviceAccount: options.transformServiceAccount!,
      );
    } else {
      stdout.writeln(
        'SQL apply complete. Scheduled-query configs were not changed; '
        '--apply-schedules was not supplied.',
      );
    }
  } on _CliError catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on Object {
    stderr.writeln(
      'Error: Product analytics deployment failed unexpectedly. No backend '
      'error details were printed.',
    );
    exitCode = 1;
  }
}

_Options _parseOptions({required List<String> args}) {
  final values = <String, String>{};
  final enabledFlags = <String>{};
  final valueFlags = <String>{..._requiredValueFlags, ..._optionalValueFlags};

  for (var index = 0; index < args.length; index++) {
    final argument = args[index];

    if (_booleanFlags.contains(argument)) {
      if (!enabledFlags.add(argument)) {
        throw _CliError(
          message: 'Error: $argument was supplied more than once.',
        );
      }
      continue;
    }

    final equalsIndex = argument.indexOf('=');
    final flag = equalsIndex == -1
        ? argument
        : argument.substring(0, equalsIndex);
    if (!valueFlags.contains(flag)) {
      throw const _CliError(
        message:
            'Error: Unknown argument. Use --help to see supported options.',
      );
    }
    if (values.containsKey(flag)) {
      throw _CliError(message: 'Error: $flag was supplied more than once.');
    }

    late final String value;
    if (equalsIndex != -1) {
      value = argument.substring(equalsIndex + 1);
    } else {
      final valueIndex = index + 1;
      if (valueIndex >= args.length || args[valueIndex].startsWith('--')) {
        throw _CliError(message: 'Error: Missing value for $flag.');
      }
      value = args[valueIndex];
      index = valueIndex;
    }

    if (value.isEmpty || value != value.trim()) {
      throw _CliError(message: 'Error: Invalid value for $flag.');
    }
    values[flag] = value;
  }

  for (final flag in _requiredValueFlags) {
    if (!values.containsKey(flag)) {
      throw _CliError(message: 'Error: Missing required argument $flag.');
    }
  }

  final dryRun = enabledFlags.contains('--dry-run');
  final apply = enabledFlags.contains('--apply');
  if (dryRun && apply) {
    throw const _CliError(
      message: 'Error: --dry-run and --apply are mutually exclusive.',
    );
  }

  final mode = dryRun
      ? _Mode.dryRun
      : apply
      ? _Mode.apply
      : _Mode.renderOnly;
  final applySchedules = enabledFlags.contains('--apply-schedules');
  if (applySchedules && mode != _Mode.apply) {
    throw const _CliError(
      message: 'Error: --apply-schedules requires --apply.',
    );
  }
  if (applySchedules && values['--transform-service-account'] == null) {
    throw const _CliError(
      message: 'Error: --apply-schedules requires --transform-service-account.',
    );
  }

  final projectId = values['--project']!;
  final location = values['--location']!;
  if (!_projectIdPattern.hasMatch(projectId)) {
    throw const _CliError(message: 'Error: Invalid value for --project.');
  }
  if (!_locationPattern.hasMatch(location)) {
    throw const _CliError(message: 'Error: Invalid value for --location.');
  }

  final datasetValues = <String, String>{
    '--raw-dataset-id': values['--raw-dataset-id']!,
    '--auth-dataset-id': values['--auth-dataset-id']!,
    '--privacy-dataset-id': values['--privacy-dataset-id']!,
    '--controls-dataset-id': values['--controls-dataset-id']!,
    '--curated-dataset-id': values['--curated-dataset-id']!,
    '--reporting-dataset-id': values['--reporting-dataset-id']!,
  };
  for (final entry in datasetValues.entries) {
    if (!_datasetIdPattern.hasMatch(entry.value)) {
      throw _CliError(message: 'Error: Invalid value for ${entry.key}.');
    }
  }
  final distinctDatasetIds = datasetValues.values.toSet();
  if (distinctDatasetIds.length != datasetValues.length) {
    throw const _CliError(message: 'Error: All dataset IDs must be distinct.');
  }

  final rawExportStartAt = values['--raw-export-start-at']!;
  final behavioralSchemaV1StartAt = values['--behavioral-schema-v1-start-at']!;
  final rawExportStart = _parseUtcTimestamp(
    value: rawExportStartAt,
    flag: '--raw-export-start-at',
  );
  final behavioralSchemaV1Start = _parseUtcTimestamp(
    value: behavioralSchemaV1StartAt,
    flag: '--behavioral-schema-v1-start-at',
  );
  if (behavioralSchemaV1Start.isBefore(rawExportStart)) {
    throw const _CliError(
      message:
          'Error: --behavioral-schema-v1-start-at must not be earlier than '
          '--raw-export-start-at.',
    );
  }

  final transformServiceAccount = values['--transform-service-account'];
  if (transformServiceAccount != null &&
      !_serviceAccountPattern.hasMatch(transformServiceAccount)) {
    throw const _CliError(
      message: 'Error: Invalid value for --transform-service-account.',
    );
  }

  return _Options(
    mode: mode,
    applySchedules: applySchedules,
    projectId: projectId,
    location: location,
    rawDatasetId: datasetValues['--raw-dataset-id']!,
    authDatasetId: datasetValues['--auth-dataset-id']!,
    privacyDatasetId: datasetValues['--privacy-dataset-id']!,
    controlsDatasetId: datasetValues['--controls-dataset-id']!,
    curatedDatasetId: datasetValues['--curated-dataset-id']!,
    reportingDatasetId: datasetValues['--reporting-dataset-id']!,
    rawExportStartAt: rawExportStartAt,
    behavioralSchemaV1StartAt: behavioralSchemaV1StartAt,
    transformServiceAccount: transformServiceAccount,
  );
}

DateTime _parseUtcTimestamp({required String value, required String flag}) {
  final match = _utcTimestampPattern.firstMatch(value);
  final parsed = DateTime.tryParse(value);
  if (match == null || parsed == null || !parsed.isUtc) {
    throw _CliError(
      message:
          'Error: $flag must be a valid UTC RFC3339 timestamp ending in Z.',
    );
  }

  final expectedParts = <int>[
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  ];
  final parsedParts = <int>[
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
  ];
  if (expectedParts[0] == 0 ||
      !_sameIntegers(left: expectedParts, right: parsedParts)) {
    throw _CliError(
      message:
          'Error: $flag must be a valid UTC RFC3339 timestamp ending in Z.',
    );
  }
  return parsed;
}

bool _sameIntegers({required List<int> left, required List<int> right}) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

Map<String, String> _placeholderReplacements({required _Options options}) =>
    <String, String>{
      '{{PROJECT_ID}}': options.projectId,
      '{{RAW_DATASET_ID}}': options.rawDatasetId,
      '{{AUTH_DATASET_ID}}': options.authDatasetId,
      '{{PRIVACY_DATASET_ID}}': options.privacyDatasetId,
      '{{CONTROLS_DATASET_ID}}': options.controlsDatasetId,
      '{{CURATED_DATASET_ID}}': options.curatedDatasetId,
      '{{REPORTING_DATASET_ID}}': options.reportingDatasetId,
      '{{RAW_EXPORT_START_AT}}': options.rawExportStartAt,
      '{{BEHAVIORAL_SCHEMA_V1_START_AT}}': options.behavioralSchemaV1StartAt,
    };

Future<List<_ScheduleDefinition>> _loadSchedules({required String path}) async {
  late final String content;
  try {
    content = await File(path).readAsString();
  } on FileSystemException catch (error) {
    throw _CliError.withCause(
      message: 'Error: Could not read sql/schedules.json.',
      cause: error,
    );
  }

  late final Object? decoded;
  try {
    decoded = jsonDecode(content);
  } on FormatException catch (error) {
    throw _CliError.withCause(
      message: 'Error: sql/schedules.json is not valid JSON.',
      cause: error,
    );
  }
  if (decoded is! List<Object?> || decoded.isEmpty) {
    throw const _CliError(
      message: 'Error: sql/schedules.json must be a non-empty JSON array.',
    );
  }

  final schedules = <_ScheduleDefinition>[];
  final queryFiles = <String>{};
  final displayNames = <String>{};
  for (var index = 0; index < decoded.length; index++) {
    final rawEntry = decoded[index];
    if (rawEntry is! Map<String, Object?> ||
        rawEntry.length != _scheduleManifestFields.length ||
        !_scheduleManifestFields.every(rawEntry.containsKey)) {
      throw _CliError(
        message:
            'Error: Schedule entry ${index + 1} must contain exactly the '
            'documented fields.',
      );
    }

    final queryFile = rawEntry['queryFile'];
    final displayName = rawEntry['displayName'];
    final cadence = rawEntry['cadence'];
    final recentDateRecomputationWindow =
        rawEntry['recentDateRecomputationWindow'];
    final maxBytesBilled = rawEntry['maxBytesBilled'];
    if (queryFile is! String) {
      throw _CliError(
        message: 'Error: Schedule entry ${index + 1} has an invalid queryFile.',
      );
    }
    final fileMatch = _numericSqlFilePattern.firstMatch(queryFile);
    if (fileMatch == null) {
      throw _CliError(
        message: 'Error: Schedule entry ${index + 1} has an invalid queryFile.',
      );
    }
    if (displayName is! String ||
        displayName.isEmpty ||
        displayName != displayName.trim() ||
        displayName.length > 256 ||
        !_printableAsciiPattern.hasMatch(displayName)) {
      throw _CliError(
        message:
            'Error: Schedule entry ${index + 1} has an invalid displayName.',
      );
    }
    if (cadence is! String || !_dailyCadencePattern.hasMatch(cadence)) {
      throw _CliError(
        message: 'Error: Schedule entry ${index + 1} has an invalid cadence.',
      );
    }
    if (recentDateRecomputationWindow is! int ||
        recentDateRecomputationWindow != 3) {
      throw _CliError(
        message:
            'Error: Schedule entry ${index + 1} must declare the SQL-owned '
            'three-date recomputation window.',
      );
    }
    if (maxBytesBilled is! int ||
        maxBytesBilled <= 0 ||
        maxBytesBilled > _maxScheduledQueryBytes) {
      throw _CliError(
        message:
            'Error: Schedule entry ${index + 1} maxBytesBilled must be between '
            '1 and $_maxScheduledQueryBytes.',
      );
    }
    if (!queryFiles.add(queryFile)) {
      throw const _CliError(
        message: 'Error: Schedule queryFile values must be unique.',
      );
    }
    if (!displayNames.add(displayName)) {
      throw const _CliError(
        message: 'Error: Schedule displayName values must be unique.',
      );
    }

    schedules.add(
      _ScheduleDefinition(
        queryFile: queryFile,
        displayName: displayName,
        cadence: cadence,
        recentDateRecomputationWindow: recentDateRecomputationWindow,
        maxBytesBilled: maxBytesBilled,
        dependencyOrder: int.parse(fileMatch.group(1)!),
      ),
    );
  }

  final dailyScheduledBytes = schedules.fold<int>(
    0,
    (total, schedule) => total + schedule.maxBytesBilled,
  );
  if (dailyScheduledBytes > _maxScheduledQueryDailyBytes) {
    throw const _CliError(
      message:
          'Error: Scheduled maxBytesBilled values exceed the 1.75 GiB daily '
          'transform-principal allocation.',
    );
  }

  schedules.sort(_compareSchedules);
  return schedules;
}

int _compareSchedules(
  final _ScheduleDefinition left,
  final _ScheduleDefinition right,
) {
  final order = left.dependencyOrder.compareTo(right.dependencyOrder);
  return order != 0 ? order : left.queryFile.compareTo(right.queryFile);
}

Future<List<_SqlAsset>> _loadSqlAssets({
  required Directory directory,
  required List<_ScheduleDefinition> schedules,
  required Map<String, String> replacements,
}) async {
  late final List<FileSystemEntity> entries;
  try {
    entries = await directory.list(followLinks: false).toList();
  } on FileSystemException catch (error) {
    throw _CliError.withCause(
      message: 'Error: Could not list product analytics SQL.',
      cause: error,
    );
  }

  final scheduleByFile = <String, _ScheduleDefinition>{
    for (final schedule in schedules) schedule.queryFile: schedule,
  };
  final assets = <_SqlAsset>[];
  final foundFiles = <String>{};
  for (final entry in entries) {
    if (entry is! File) {
      continue;
    }
    final fileName = _baseName(path: entry.path);
    final fileMatch = _numericSqlFilePattern.firstMatch(fileName);
    if (fileMatch == null) {
      continue;
    }
    foundFiles.add(fileName);

    final schedule = scheduleByFile[fileName];
    final deploymentOnlyCeiling = _deploymentOnlyMaxBytesBilled[fileName];
    if (schedule != null && deploymentOnlyCeiling != null) {
      throw _CliError(
        message:
            'Error: $fileName cannot be both scheduled and deployment-only.',
      );
    }
    final maxBytesBilled = schedule?.maxBytesBilled ?? deploymentOnlyCeiling;
    if (maxBytesBilled == null) {
      throw _CliError(
        message: 'Error: $fileName has no explicit maxBytesBilled ceiling.',
      );
    }

    late final String template;
    try {
      template = await entry.readAsString();
    } on FileSystemException catch (error) {
      throw _CliError.withCause(
        message: 'Error: Could not read $fileName.',
        cause: error,
      );
    }
    final renderedSql = _renderSql(
      fileName: fileName,
      template: template,
      replacements: replacements,
    );
    assets.add(
      _SqlAsset(
        fileName: fileName,
        dependencyOrder: int.parse(fileMatch.group(1)!),
        renderedSql: renderedSql,
        maxBytesBilled: maxBytesBilled,
        schedule: schedule,
      ),
    );
  }

  if (assets.isEmpty) {
    throw const _CliError(
      message: 'Error: No numeric product analytics SQL files were found.',
    );
  }
  for (final schedule in schedules) {
    if (!foundFiles.contains(schedule.queryFile)) {
      throw _CliError(
        message:
            'Error: Schedule query file ${schedule.queryFile} was not found.',
      );
    }
  }

  assets.sort(_compareSqlAssets);
  return assets;
}

int _compareSqlAssets(final _SqlAsset left, final _SqlAsset right) {
  final order = left.dependencyOrder.compareTo(right.dependencyOrder);
  return order != 0 ? order : left.fileName.compareTo(right.fileName);
}

String _renderSql({
  required String fileName,
  required String template,
  required Map<String, String> replacements,
}) {
  if (template.trim().isEmpty) {
    throw _CliError(message: 'Error: $fileName is empty.');
  }

  for (final match in _placeholderPattern.allMatches(template)) {
    final placeholder = match.group(0)!;
    if (!replacements.containsKey(placeholder)) {
      throw _CliError(
        message:
            'Error: $fileName contains an unsupported template placeholder.',
      );
    }
  }

  var rendered = template;
  for (final replacement in replacements.entries) {
    rendered = rendered.replaceAll(replacement.key, replacement.value);
  }
  if (_placeholderPattern.hasMatch(rendered) ||
      rendered.contains('{{') ||
      rendered.contains('}}')) {
    throw _CliError(
      message: 'Error: $fileName contains an unresolved template placeholder.',
    );
  }
  return rendered;
}

void _printValidatedPlan({
  required List<_SqlAsset> assets,
  required List<_ScheduleDefinition> schedules,
}) {
  stdout.writeln(
    'Validated and rendered ${assets.length} SQL assets in numeric dependency '
    'order:',
  );
  for (final asset in assets) {
    final kind = asset.schedule == null ? 'deployment-only' : 'scheduled';
    stdout.writeln(
      '  ${asset.fileName}: $kind, maxBytesBilled=${asset.maxBytesBilled}',
    );
  }
  stdout.writeln('Loaded ${schedules.length} scheduled-query definitions:');
  for (final schedule in schedules) {
    stdout.writeln(
      '  ${schedule.queryFile}: ${schedule.cadence}, recompute '
      '${schedule.recentDateRecomputationWindow} recent UTC dates',
    );
  }
  final dailyScheduledBytes = schedules.fold<int>(
    0,
    (total, schedule) => total + schedule.maxBytesBilled,
  );
  stdout.writeln(
    'Scheduled daily allocation: $dailyScheduledBytes bytes '
    '(limit $_maxScheduledQueryDailyBytes).',
  );
}

Future<void> _applySchedules({
  required _BqRunner bq,
  required List<_ScheduleDefinition> schedules,
  required List<_SqlAsset> assets,
  required String serviceAccount,
}) async {
  final assetsByFile = <String, _SqlAsset>{
    for (final asset in assets) asset.fileName: asset,
  };
  final existingConfigs = await bq.listScheduledQueryConfigs();
  final manifestDisplayNames = schedules
      .map((schedule) => schedule.displayName)
      .toSet();
  final obsoleteConfigCount = existingConfigs.entries
      .where(
        (entry) =>
            entry.key.startsWith(_scheduleDisplayNamePrefix) &&
            !manifestDisplayNames.contains(entry.key),
      )
      .fold<int>(0, (count, entry) => count + entry.value.length);
  if (obsoleteConfigCount > 0) {
    throw _CliError(
      message:
          'Error: Found $obsoleteConfigCount Sesori Product Analytics '
          'scheduled-query config(s) not declared in sql/schedules.json. No '
          'schedules were created or updated; review obsolete configs '
          'manually.',
    );
  }

  for (final schedule in schedules) {
    final matchingConfigs =
        existingConfigs[schedule.displayName] ?? const <String>[];
    if (matchingConfigs.length > 1) {
      throw _CliError(
        message:
            'Error: More than one scheduled-query config has the exact '
            'display name for ${schedule.queryFile}. No schedules were '
            'created or updated.',
      );
    }
  }

  for (final schedule in schedules) {
    final matchingConfigs =
        existingConfigs[schedule.displayName] ?? const <String>[];
    final asset = assetsByFile[schedule.queryFile]!;
    if (matchingConfigs.isEmpty) {
      stdout.writeln('Creating schedule for ${schedule.queryFile}.');
      await bq.createScheduledQuery(
        schedule: schedule,
        renderedSql: asset.renderedSql,
        serviceAccount: serviceAccount,
      );
    } else {
      stdout.writeln('Updating schedule for ${schedule.queryFile}.');
      await bq.updateScheduledQuery(
        resourceName: matchingConfigs.single,
        schedule: schedule,
        renderedSql: asset.renderedSql,
        serviceAccount: serviceAccount,
      );
    }
  }

  stdout.writeln(
    'SQL and scheduled-query apply complete. Runtime byte guardrails remain '
    'the responsibility of project/principal query quotas.',
  );
}

class _BqRunner {
  const _BqRunner({required this.projectId, required this.location});

  final String projectId;
  final String location;

  Future<void> runQuery({
    required _SqlAsset asset,
    required bool dryRun,
  }) async {
    final result = await _run(
      arguments: <String>[
        ..._globalArguments(format: dryRun ? 'json' : 'none'),
        'query',
        '--use_legacy_sql=false',
        if (!dryRun) '--maximum_bytes_billed=${asset.maxBytesBilled}',
        '--dry_run=$dryRun',
      ],
      standardInput: asset.renderedSql,
      operation: dryRun
          ? 'dry-run ${asset.fileName}'
          : 'apply ${asset.fileName}',
    );
    if (dryRun) {
      final estimate = _parseDryRunEstimate(
        standardOutput: result.standardOutput,
        fileName: asset.fileName,
      );
      stdout.writeln(
        'Dry-run estimate for ${asset.fileName}: totalBytesProcessed='
        '${estimate.totalBytesProcessed ?? 'unavailable'}, accuracy='
        '${estimate.accuracy.wireValue}.',
      );
    }
  }

  Future<Map<String, List<String>>> listScheduledQueryConfigs() async {
    final result = await _run(
      arguments: <String>[
        ..._globalArguments(format: 'json'),
        'ls',
        '--transfer_config=true',
        '--transfer_location=$location',
        '--filter=dataSourceIds:scheduled_query',
        '--max_results=1000',
      ],
      standardInput: null,
      operation: 'list scheduled-query configs',
    );

    late final Object? decoded;
    try {
      decoded = jsonDecode(result.standardOutput);
    } on FormatException catch (error) {
      throw _CliError.withCause(
        message: 'Error: bq returned an invalid scheduled-query config list.',
        cause: error,
      );
    }
    if (decoded is! List<Object?>) {
      throw const _CliError(
        message: 'Error: bq returned an invalid scheduled-query config list.',
      );
    }

    final configsByDisplayName = <String, List<String>>{};
    for (final rawConfig in decoded) {
      if (rawConfig is! Map<String, Object?>) {
        throw const _CliError(
          message: 'Error: bq returned an invalid scheduled-query config.',
        );
      }
      final dataSourceId =
          rawConfig['dataSourceId'] ?? rawConfig['data_source_id'];
      if (dataSourceId != null && dataSourceId != 'scheduled_query') {
        continue;
      }
      final displayName = rawConfig['displayName'] ?? rawConfig['display_name'];
      final resourceName = rawConfig['name'];
      if (displayName is! String || resourceName is! String) {
        throw const _CliError(
          message: 'Error: bq returned an incomplete scheduled-query config.',
        );
      }
      if (!_validTransferConfigName(
        resourceName: resourceName,
        expectedLocation: location,
      )) {
        throw const _CliError(
          message:
              'Error: bq returned an invalid scheduled-query resource name.',
        );
      }
      configsByDisplayName
          .putIfAbsent(displayName, () => <String>[])
          .add(resourceName);
    }
    return configsByDisplayName;
  }

  Future<void> createScheduledQuery({
    required _ScheduleDefinition schedule,
    required String renderedSql,
    required String serviceAccount,
  }) async {
    await _run(
      arguments: <String>[
        ..._globalArguments(format: 'none'),
        'mk',
        '--transfer_config=true',
        '--data_source=scheduled_query',
        '--display_name=${schedule.displayName}',
        '--schedule=${schedule.cadence}',
        '--params=${jsonEncode(<String, String>{'query': renderedSql})}',
        '--service_account_name=$serviceAccount',
      ],
      standardInput: null,
      operation: 'create schedule for ${schedule.queryFile}',
    );
  }

  Future<void> updateScheduledQuery({
    required String resourceName,
    required _ScheduleDefinition schedule,
    required String renderedSql,
    required String serviceAccount,
  }) async {
    await _run(
      arguments: <String>[
        ..._globalArguments(format: 'none'),
        'update',
        '--transfer_config=true',
        '--display_name=${schedule.displayName}',
        '--schedule=${schedule.cadence}',
        '--params=${jsonEncode(<String, String>{'query': renderedSql})}',
        '--service_account_name=$serviceAccount',
        '--update_credentials=true',
        resourceName,
      ],
      standardInput: null,
      operation: 'update schedule for ${schedule.queryFile}',
    );
  }

  List<String> _globalArguments({required String format}) => <String>[
    '--headless=true',
    '--quiet=true',
    '--synchronous_mode=true',
    '--project_id=$projectId',
    '--location=$location',
    '--format=$format',
  ];

  Future<_CommandResult> _run({
    required List<String> arguments,
    required String? standardInput,
    required String operation,
  }) async {
    late final Process process;
    try {
      process = await Process.start('bq', arguments, runInShell: false);
    } on ProcessException catch (error) {
      throw _CliError.withCause(
        message:
            'Error: Could not start bq. Install the Google Cloud CLI and make '
            'bq available on PATH.',
        cause: error,
      );
    }

    final standardOutputFuture = process.stdout.transform(utf8.decoder).join();
    final standardErrorFuture = process.stderr.transform(utf8.decoder).join();
    try {
      if (standardInput != null) {
        process.stdin.write(standardInput);
      }
      await process.stdin.close();
    } on Object catch (error) {
      process.kill();
      await standardOutputFuture;
      await standardErrorFuture;
      throw _CliError.withCause(
        message:
            'Error: Could not send input to bq while attempting to $operation.',
        cause: error,
      );
    }

    final commandExitCode = await process.exitCode;
    final standardOutput = await standardOutputFuture;
    await standardErrorFuture;
    if (commandExitCode != 0) {
      throw _CliError(
        message:
            'Error: bq failed while attempting to $operation '
            '(exit code $commandExitCode). Backend error details were '
            'suppressed.',
      );
    }
    return _CommandResult(standardOutput: standardOutput);
  }
}

_DryRunEstimate _parseDryRunEstimate({
  required String standardOutput,
  required String fileName,
}) {
  late final Object? decoded;
  try {
    decoded = jsonDecode(standardOutput);
  } on FormatException catch (error) {
    throw _CliError.withCause(
      message: 'Error: bq returned invalid dry-run JSON for $fileName.',
      cause: error,
    );
  }

  final statistics = decoded is Map<String, Object?>
      ? decoded['statistics']
      : null;
  final queryStatistics = statistics is Map<String, Object?>
      ? statistics['query']
      : null;
  if (queryStatistics is! Map<String, Object?>) {
    throw _CliError(
      message: 'Error: bq returned invalid dry-run statistics for $fileName.',
    );
  }

  final totalBytesProcessed = queryStatistics['totalBytesProcessed'];
  if (totalBytesProcessed != null &&
      (totalBytesProcessed is! String ||
          !RegExp(r'^\d+$').hasMatch(totalBytesProcessed))) {
    throw _CliError(
      message: 'Error: bq returned invalid dry-run statistics for $fileName.',
    );
  }
  final accuracy = totalBytesProcessed == null
      ? _DryRunAccuracy.unknown
      : _DryRunAccuracy.tryParse(
              value: queryStatistics['totalBytesProcessedAccuracy'],
            ) ??
            _DryRunAccuracy.unknown;
  return _DryRunEstimate(
    totalBytesProcessed: totalBytesProcessed as String?,
    accuracy: accuracy,
  );
}

bool _validTransferConfigName({
  required String resourceName,
  required String expectedLocation,
}) {
  final parts = resourceName.split('/');
  return parts.length == 6 &&
      parts[0] == 'projects' &&
      parts[1].isNotEmpty &&
      parts[2] == 'locations' &&
      parts[3].toLowerCase() == expectedLocation.toLowerCase() &&
      parts[4] == 'transferConfigs' &&
      parts[5].isNotEmpty &&
      parts.every(_printableAsciiPattern.hasMatch);
}

String _joinPath({required String parent, required String child}) =>
    '$parent${Platform.pathSeparator}$child';

String _baseName({required String path}) =>
    path.split(Platform.pathSeparator).last;
