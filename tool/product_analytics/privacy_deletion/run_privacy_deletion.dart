import 'dart:convert';
import 'dart:io';

import 'bigquery_privacy_deletion_client.dart';
import 'ga_user_deletion_client.dart';
import 'google_api_foundation.dart';
import 'privacy_deletion_api.dart';
import 'privacy_deletion_config.dart';
import 'privacy_deletion_models.dart';
import 'privacy_deletion_repository.dart';
import 'privacy_deletion_service.dart';

Future<void> main(final List<String> arguments) async {
  if (arguments.contains('--help')) {
    stdout.write(privacyDeletionUsage);
    return;
  }

  ApplicationDefaultAccessTokenProvider? tokenProvider;
  BigQueryPrivacyDeletionClient? bigQueryClient;
  GaUserDeletionClient? gaClient;
  try {
    final command = PrivacyDeletionCommandConfig.parse(
      arguments: arguments,
      environment: Platform.environment,
      requestIdRequired: true,
    );
    final config = command.config;
    final requestId = command.requestId;
    if (requestId == null) {
      throw const PrivacyDeletionValidationException(
        field: 'request_id',
        requirement: 'required for request processing',
      );
    }
    tokenProvider = ApplicationDefaultAccessTokenProvider(
      scopes: const <String>{bigQueryOAuthScope, analyticsEditOAuthScope},
      metadataTimeout: const Duration(seconds: 1),
      allowGcloudApplicationDefaultFallback: config.allowGcloudAdcFallback,
      now: DateTime.now,
    );
    bigQueryClient = RestBigQueryPrivacyDeletionClient(
      projectId: config.projectId,
      location: config.location,
      allowedDatasets: config.allowedDatasets,
      accessTokenProvider: tokenProvider,
      queryTimeout: config.queryTimeout,
    );
    gaClient = GoogleAnalyticsAdminUserDeletionClient(
      propertyId: config.analyticsPropertyId,
      accessTokenProvider: tokenProvider,
      requestTimeout: config.queryTimeout,
    );
    final schema = _warehouseSchema(config: config);
    final api = PrivacyDeletionApi(
      bigQueryClient: bigQueryClient,
      gaUserDeletionClient: gaClient,
      schema: schema,
      aggregateRebuilder: FixedAggregateRebuilder(
        client: bigQueryClient,
        schema: schema,
        loader: const RepositoryAggregateTransformLoader(),
      ),
      parameterBatchSize: config.parameterBatchSize,
    );
    final repository = PrivacyDeletionRepository(
      api: api,
      rawRetentionDays: config.rawRetentionDays,
      now: DateTime.now,
    );
    final service = PrivacyDeletionService(
      repository: repository,
      now: DateTime.now,
    );
    final summary = await service.runRequest(
      requestId: requestId,
      dryRun: command.dryRun,
    );
    _writeSummary(summary: summary, tokenProvider: tokenProvider);
    if (!summary.succeeded) {
      exitCode = 2;
    }
  } on PrivacyDeletionValidationException {
    _writeFailure(
      operation: PrivacyDeletionOperationKind.request,
      failureKind: PrivacyDeletionFailureKind.invalidInput,
      dryRun: arguments.contains('--dry-run'),
      tokenProvider: tokenProvider,
    );
    exitCode = 64;
  } on PrivacyDeletionRecoveryException {
    _writeFailure(
      operation: PrivacyDeletionOperationKind.request,
      failureKind: PrivacyDeletionFailureKind.statusUpdate,
      dryRun: arguments.contains('--dry-run'),
      tokenProvider: tokenProvider,
    );
    exitCode = 2;
  } catch (_) {
    _writeFailure(
      operation: PrivacyDeletionOperationKind.request,
      failureKind: PrivacyDeletionFailureKind.unexpected,
      dryRun: arguments.contains('--dry-run'),
      tokenProvider: tokenProvider,
    );
    exitCode = 2;
  } finally {
    gaClient?.close();
    bigQueryClient?.close();
    tokenProvider?.close();
  }
}

PrivacyDeletionWarehouseSchema _warehouseSchema({
  required PrivacyDeletionConfig config,
}) {
  return PrivacyDeletionWarehouseSchema(
    rawDataset: config.rawDataset,
    authDataset: config.authDataset,
    privacyDataset: config.privacyDataset,
    controlsDataset: config.controlsDataset,
    curatedDataset: config.curatedDataset,
    reportingDataset: config.reportingDataset,
    targetsTable: config.targetsTable,
    exclusionsTable: config.exclusionsTable,
    publicationGuardTable: config.publicationGuardTable,
    authExportRunsTable: config.authExportRunsTable,
    sweepStateTable: config.sweepStateTable,
    authKeyedTables: config.authKeyedTables,
    curatedKeyedTables: config.curatedKeyedTables,
    reportingKeyedTables: config.reportingKeyedTables,
  );
}

void _writeSummary({
  required PrivacyDeletionSummary summary,
  required ApplicationDefaultAccessTokenProvider tokenProvider,
}) {
  stdout.writeln(
    jsonEncode(
      summary.toAggregateJson(
        credentialSource: tokenProvider.lastSource.wireValue,
        credentialFallback: tokenProvider.usedFallback,
      ),
    ),
  );
}

void _writeFailure({
  required PrivacyDeletionOperationKind operation,
  required PrivacyDeletionFailureKind failureKind,
  required bool dryRun,
  required ApplicationDefaultAccessTokenProvider? tokenProvider,
}) {
  final summary = PrivacyDeletionSummary(
    operation: operation,
    outcome: PrivacyDeletionOutcome.retryable,
    dryRun: dryRun,
    targetsConsidered: 0,
    authExportReadiness: null,
    cleanup: const CleanupResult.none(),
    failureKind: failureKind,
  );
  stdout.writeln(
    jsonEncode(
      summary.toAggregateJson(
        credentialSource:
            tokenProvider?.lastSource.wireValue ??
            AdcCredentialSource.notUsed.wireValue,
        credentialFallback: tokenProvider?.usedFallback ?? false,
      ),
    ),
  );
}
