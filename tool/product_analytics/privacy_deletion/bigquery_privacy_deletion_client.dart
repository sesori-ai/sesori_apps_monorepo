import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'google_api_foundation.dart';
import 'privacy_deletion_models.dart';

sealed class BigQueryParameter {
  const BigQueryParameter({required this.name});

  final String name;

  Map<String, Object?> toJson();
}

final class BigQueryStringParameter extends BigQueryParameter {
  const BigQueryStringParameter({required super.name, required this.value});

  final String? value;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'parameterType': <String, Object?>{'type': 'STRING'},
    'parameterValue': <String, Object?>{'value': value},
  };
}

final class BigQueryTimestampParameter extends BigQueryParameter {
  const BigQueryTimestampParameter({required super.name, required this.value});

  final DateTime value;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'parameterType': <String, Object?>{'type': 'TIMESTAMP'},
    'parameterValue': <String, Object?>{
      'value': value.toUtc().toIso8601String(),
    },
  };
}

final class BigQueryDateParameter extends BigQueryParameter {
  const BigQueryDateParameter({required super.name, required this.value});

  final DateTime value;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'parameterType': <String, Object?>{'type': 'DATE'},
    'parameterValue': <String, Object?>{'value': formatUtcDate(date: value)},
  };
}

final class BigQueryBoolParameter extends BigQueryParameter {
  const BigQueryBoolParameter({required super.name, required this.value});

  final bool value;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'parameterType': <String, Object?>{'type': 'BOOL'},
    'parameterValue': <String, Object?>{'value': value.toString()},
  };
}

final class BigQueryStringArrayParameter extends BigQueryParameter {
  BigQueryStringArrayParameter({
    required super.name,
    required List<String> values,
  }) : values = List<String>.unmodifiable(values);

  final List<String> values;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'parameterType': <String, Object?>{
      'type': 'ARRAY',
      'arrayType': <String, Object?>{'type': 'STRING'},
    },
    'parameterValue': <String, Object?>{
      'arrayValues': values
          .map((final value) => <String, Object?>{'value': value})
          .toList(),
    },
  };
}

final class BigQueryStatement {
  BigQueryStatement({
    required this.sql,
    required List<BigQueryParameter> parameters,
    required List<BigQueryDatasetReference> referencedDatasets,
    required this.isMutation,
    required this.dryRun,
  }) : parameters = List<BigQueryParameter>.unmodifiable(parameters),
       referencedDatasets = List<BigQueryDatasetReference>.unmodifiable(
         referencedDatasets,
       );

  final String sql;
  final List<BigQueryParameter> parameters;
  final List<BigQueryDatasetReference> referencedDatasets;
  final bool isMutation;
  final bool dryRun;
}

final class BigQueryStatementResult {
  const BigQueryStatementResult({
    required this.rows,
    required this.affectedRows,
    required this.dryRun,
  });

  final List<Map<String, Object?>> rows;
  final int affectedRows;
  final bool dryRun;
}

abstract interface class BigQueryPrivacyDeletionClient {
  Future<BigQueryStatementResult> execute({
    required BigQueryStatement statement,
  });

  void close();
}

final class RestBigQueryPrivacyDeletionClient
    implements BigQueryPrivacyDeletionClient {
  RestBigQueryPrivacyDeletionClient({
    required this.projectId,
    required this.location,
    required List<BigQueryDatasetReference> allowedDatasets,
    required GoogleAccessTokenProvider accessTokenProvider,
    required Duration queryTimeout,
  }) : _allowedDatasetKeys = Set<String>.unmodifiable(
         allowedDatasets.map((final value) => value.allowlistKey),
       ),
       _accessTokenProvider = accessTokenProvider,
       _queryTimeout = queryTimeout,
       _httpClient = HttpClient() {
    if (_allowedDatasetKeys.isEmpty) {
      throw const PrivacyDeletionValidationException(
        field: 'allowed_datasets',
        requirement: 'at least one dataset',
      );
    }
    for (final dataset in allowedDatasets) {
      if (dataset.projectId.value != projectId.value) {
        throw const PrivacyDeletionValidationException(
          field: 'allowed_datasets',
          requirement: 'all datasets in the configured project',
        );
      }
    }
    _httpClient.connectionTimeout = const Duration(seconds: 15);
  }

  final GcpProjectId projectId;
  final BigQueryLocation location;
  final Set<String> _allowedDatasetKeys;
  final GoogleAccessTokenProvider _accessTokenProvider;
  final Duration _queryTimeout;
  final HttpClient _httpClient;

  @override
  Future<BigQueryStatementResult> execute({
    required BigQueryStatement statement,
  }) async {
    _validateStatement(statement: statement);
    try {
      if (statement.dryRun) {
        final dryRunResponse = await _postJson(
          uri: Uri.https(
            'bigquery.googleapis.com',
            '/bigquery/v2/projects/${projectId.value}/jobs',
          ),
          body: <String, Object?>{
            'jobReference': <String, Object?>{
              'projectId': projectId.value,
              'location': location.value,
              'jobId':
                  'privacy_deletion_dry_run_${pid}_'
                  '${DateTime.now().microsecondsSinceEpoch}',
            },
            'configuration': <String, Object?>{
              'dryRun': true,
              'query': <String, Object?>{
                'query': statement.sql,
                'useLegacySql': false,
                'parameterMode': 'NAMED',
                'queryParameters': statement.parameters
                    .map((final parameter) => parameter.toJson())
                    .toList(),
              },
            },
          },
        );
        _throwForJobStatusErrors(response: dryRunResponse);
        return const BigQueryStatementResult(
          rows: <Map<String, Object?>>[],
          affectedRows: 0,
          dryRun: true,
        );
      }
      final initial = await _postJson(
        uri: Uri.https(
          'bigquery.googleapis.com',
          '/bigquery/v2/projects/${projectId.value}/queries',
        ),
        body: <String, Object?>{
          'query': statement.sql,
          'useLegacySql': false,
          'parameterMode': 'NAMED',
          'queryParameters': statement.parameters
              .map((final parameter) => parameter.toJson())
              .toList(),
          'location': location.value,
          'timeoutMs': 10000,
        },
      );
      _throwForQueryErrors(response: initial);

      final pages = <Map<String, dynamic>>[];
      var current = initial;
      final deadline = DateTime.now().add(_queryTimeout);
      while (current['jobComplete'] != true) {
        if (DateTime.now().isAfter(deadline)) {
          throw const BigQueryQueryTimeoutException();
        }
        final jobReference = current['jobReference'];
        if (jobReference is! Map<String, dynamic> ||
            jobReference['jobId'] is! String) {
          throw const BigQueryResponseShapeException();
        }
        await Future<void>.delayed(const Duration(seconds: 1));
        current = await _getQueryResults(
          jobId: jobReference['jobId'] as String,
          pageToken: null,
        );
        _throwForQueryErrors(response: current);
      }
      pages.add(current);

      var pageToken = current['pageToken'];
      final jobReference = current['jobReference'] ?? initial['jobReference'];
      while (pageToken is String && pageToken.isNotEmpty) {
        if (jobReference is! Map<String, dynamic> ||
            jobReference['jobId'] is! String) {
          throw const BigQueryResponseShapeException();
        }
        current = await _getQueryResults(
          jobId: jobReference['jobId'] as String,
          pageToken: pageToken,
        );
        _throwForQueryErrors(response: current);
        pages.add(current);
        pageToken = current['pageToken'];
      }

      final rows = <Map<String, Object?>>[];
      for (final page in pages) {
        rows.addAll(_decodeRows(response: page));
      }
      String? affectedRowsRaw;
      for (final page in pages) {
        final value = page['numDmlAffectedRows'];
        if (value is String) {
          affectedRowsRaw = value;
        }
      }
      return BigQueryStatementResult(
        rows: List<Map<String, Object?>>.unmodifiable(rows),
        affectedRows: affectedRowsRaw == null
            ? 0
            : int.tryParse(affectedRowsRaw) ?? 0,
        dryRun: false,
      );
    } catch (error, stackTrace) {
      if (error is BigQueryPrivacyDeletionClientException) {
        rethrow;
      }
      throw BigQueryPrivacyDeletionClientException(
        mutation: statement.isMutation,
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
  }

  void _validateStatement({required BigQueryStatement statement}) {
    if (statement.sql.trim().isEmpty) {
      throw const PrivacyDeletionValidationException(
        field: 'query',
        requirement: 'non-empty GoogleSQL',
      );
    }
    final declaredKeys = statement.referencedDatasets
        .map((final value) => value.allowlistKey)
        .toSet();
    if (declaredKeys.any((final key) => !_allowedDatasetKeys.contains(key))) {
      throw const PrivacyDeletionValidationException(
        field: 'query_datasets',
        requirement: 'only configured allowlisted datasets',
      );
    }
    final sqlWithoutTemporaryTableCreates = statement.sql.replaceAll(
      RegExp(
        r'\bCREATE\s+(?:OR\s+REPLACE\s+)?TEMP(?:ORARY)?\s+TABLE\b',
        caseSensitive: false,
      ),
      '',
    );
    final forbidden = RegExp(
      r'\b(EXECUTE\s+IMMEDIATE|EXTERNAL_QUERY|EXPORT\s+DATA|LOAD\s+DATA|'
      r'CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE)\b',
      caseSensitive: false,
    );
    if (forbidden.hasMatch(sqlWithoutTemporaryTableCreates)) {
      throw const PrivacyDeletionValidationException(
        field: 'query',
        requirement:
            'no dynamic, external, export, load, connection, or persistent DDL SQL',
      );
    }
    for (final match in RegExp(r'`([^`]+)`').allMatches(statement.sql)) {
      final identifier = match.group(1)!;
      final parts = identifier.split('.');
      if (parts.length < 3) {
        continue;
      }
      final key = '${parts[0]}.${parts[1]}';
      if (!_allowedDatasetKeys.contains(key) || !declaredKeys.contains(key)) {
        throw const PrivacyDeletionValidationException(
          field: 'query_identifiers',
          requirement:
              'fully qualified references in declared allowlisted datasets',
        );
      }
    }
    final unquotedReferencePattern = RegExp(
      r'\b(?:FROM|JOIN|UPDATE|INTO|CALL|TABLE)\s+'
      r'([A-Za-z_][A-Za-z0-9_-]*\.[A-Za-z_][A-Za-z0-9_]*\.'
      r'[A-Za-z_][A-Za-z0-9_*]*)',
      caseSensitive: false,
    );
    for (final match in unquotedReferencePattern.allMatches(statement.sql)) {
      final parts = match.group(1)!.split('.');
      final key = '${parts[0]}.${parts[1]}';
      if (!_allowedDatasetKeys.contains(key) || !declaredKeys.contains(key)) {
        throw const PrivacyDeletionValidationException(
          field: 'query_identifiers',
          requirement:
              'unquoted references in declared allowlisted datasets only',
        );
      }
    }
    final parameterNames = <String>{};
    for (final parameter in statement.parameters) {
      if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,127}$').hasMatch(parameter.name) ||
          !parameterNames.add(parameter.name)) {
        throw const PrivacyDeletionValidationException(
          field: 'query_parameters',
          requirement: 'unique valid named parameters',
        );
      }
    }
  }

  Future<Map<String, dynamic>> _getQueryResults({
    required String jobId,
    required String? pageToken,
  }) {
    return _getJson(
      uri: Uri.https(
        'bigquery.googleapis.com',
        '/bigquery/v2/projects/${projectId.value}/queries/$jobId',
        <String, String>{
          'location': location.value,
          'timeoutMs': '10000',
          if (pageToken != null) 'pageToken': pageToken,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _postJson({
    required Uri uri,
    required Map<String, Object?> body,
  }) async {
    final token = await _accessTokenProvider.accessToken();
    final request = await _httpClient.postUrl(uri);
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${token.value}',
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    return _readResponse(request: request);
  }

  Future<Map<String, dynamic>> _getJson({required Uri uri}) async {
    final token = await _accessTokenProvider.accessToken();
    final request = await _httpClient.getUrl(uri);
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${token.value}',
    );
    return _readResponse(request: request);
  }

  Future<Map<String, dynamic>> _readResponse({
    required HttpClientRequest request,
  }) async {
    final response = await request.close().timeout(_queryTimeout);
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_queryTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleApiHttpException(statusCode: response.statusCode);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (error, stackTrace) {
      throw GoogleApiPayloadException(
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BigQueryResponseShapeException();
    }
    return decoded;
  }

  void _throwForQueryErrors({required Map<String, dynamic> response}) {
    final errors = response['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw BigQueryJobException(errorCount: errors.length);
    }
  }

  void _throwForJobStatusErrors({required Map<String, dynamic> response}) {
    final status = response['status'];
    if (status is! Map<String, dynamic>) {
      throw const BigQueryResponseShapeException();
    }
    final errors = status['errors'];
    if (status['errorResult'] != null ||
        (errors is List && errors.isNotEmpty)) {
      throw BigQueryJobException(
        errorCount: errors is List && errors.isNotEmpty ? errors.length : 1,
      );
    }
  }

  List<Map<String, Object?>> _decodeRows({
    required Map<String, dynamic> response,
  }) {
    final rawRows = response['rows'];
    if (rawRows == null) {
      return const <Map<String, Object?>>[];
    }
    final schema = response['schema'];
    if (rawRows is! List || schema is! Map<String, dynamic>) {
      throw const BigQueryResponseShapeException();
    }
    final rawFields = schema['fields'];
    if (rawFields is! List) {
      throw const BigQueryResponseShapeException();
    }
    final fieldNames = rawFields.map((final rawField) {
      if (rawField is! Map<String, dynamic> || rawField['name'] is! String) {
        throw const BigQueryResponseShapeException();
      }
      return rawField['name'] as String;
    }).toList();

    return rawRows.map((final rawRow) {
      if (rawRow is! Map<String, dynamic> || rawRow['f'] is! List) {
        throw const BigQueryResponseShapeException();
      }
      final cells = rawRow['f'] as List;
      if (cells.length != fieldNames.length) {
        throw const BigQueryResponseShapeException();
      }
      final row = <String, Object?>{};
      for (var index = 0; index < fieldNames.length; index++) {
        final cell = cells[index];
        if (cell is! Map<String, dynamic>) {
          throw const BigQueryResponseShapeException();
        }
        row[fieldNames[index]] = cell['v'];
      }
      return row;
    }).toList();
  }

  @override
  void close() {
    _httpClient.close(force: true);
  }
}

final class BigQueryPrivacyDeletionClientException implements Exception {
  const BigQueryPrivacyDeletionClientException({
    required this.mutation,
    required this.innerError,
    required this.innerStackTrace,
  });

  final bool mutation;
  final Object innerError;
  final StackTrace innerStackTrace;

  @override
  String toString() => mutation
      ? 'A BigQuery privacy-deletion mutation failed.'
      : 'A BigQuery privacy-deletion read failed.';
}

final class BigQueryQueryTimeoutException implements Exception {
  const BigQueryQueryTimeoutException();
}

final class BigQueryResponseShapeException implements Exception {
  const BigQueryResponseShapeException();
}

final class BigQueryJobException implements Exception {
  const BigQueryJobException({required this.errorCount});

  final int errorCount;
}
