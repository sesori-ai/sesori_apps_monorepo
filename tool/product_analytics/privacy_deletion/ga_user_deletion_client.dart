import 'dart:convert';
import 'dart:io';

import 'google_api_foundation.dart';
import 'privacy_deletion_models.dart';

sealed class GaUserDeletionIdentifier {
  const GaUserDeletionIdentifier();

  Map<String, String> toRequestBody();
}

final class GaAppInstanceDeletionIdentifier extends GaUserDeletionIdentifier {
  const GaAppInstanceDeletionIdentifier({required this.appInstanceId});

  final AppInstanceId appInstanceId;

  @override
  Map<String, String> toRequestBody() => <String, String>{
    'appInstanceId': appInstanceId.value,
  };
}

final class GaLegacyUserDeletionIdentifier extends GaUserDeletionIdentifier {
  const GaLegacyUserDeletionIdentifier({required this.legacyUserId});

  final LegacyFirebaseUserId legacyUserId;

  @override
  Map<String, String> toRequestBody() => <String, String>{
    'userId': legacyUserId.value,
  };
}

final class GaUserDeletionSubmission {
  const GaUserDeletionSubmission({required this.deletionRequestTime});

  final DateTime? deletionRequestTime;
}

abstract interface class GaUserDeletionClient {
  Future<GaUserDeletionSubmission> submit({
    required GaUserDeletionIdentifier identifier,
  });

  void close();
}

final class GoogleAnalyticsAdminUserDeletionClient
    implements GaUserDeletionClient {
  GoogleAnalyticsAdminUserDeletionClient({
    required this.propertyId,
    required GoogleAccessTokenProvider accessTokenProvider,
    required Duration requestTimeout,
  }) : _accessTokenProvider = accessTokenProvider,
       _requestTimeout = requestTimeout,
       _httpClient = HttpClient() {
    _httpClient.connectionTimeout = const Duration(seconds: 15);
  }

  final AnalyticsPropertyId propertyId;
  final GoogleAccessTokenProvider _accessTokenProvider;
  final Duration _requestTimeout;
  final HttpClient _httpClient;

  @override
  Future<GaUserDeletionSubmission> submit({
    required GaUserDeletionIdentifier identifier,
  }) async {
    try {
      final token = await _accessTokenProvider.accessToken();
      final uri = Uri.https(
        'analyticsadmin.googleapis.com',
        '/v1alpha/properties/${propertyId.value}:submitUserDeletion',
      );
      final request = await _httpClient.postUrl(uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${token.value}',
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(identifier.toRequestBody()));
      final response = await request.close().timeout(_requestTimeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_requestTimeout);
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
        throw const GaUserDeletionResponseShapeException();
      }
      final rawTime = decoded['deletionRequestTime'];
      final deletionRequestTime = rawTime == null
          ? null
          : rawTime is String
          ? DateTime.tryParse(rawTime)?.toUtc()
          : null;
      if (rawTime != null && deletionRequestTime == null) {
        throw const GaUserDeletionResponseShapeException();
      }
      return GaUserDeletionSubmission(deletionRequestTime: deletionRequestTime);
    } catch (error, stackTrace) {
      if (error is GaUserDeletionClientException) {
        rethrow;
      }
      throw GaUserDeletionClientException(
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
  }

  @override
  void close() {
    _httpClient.close(force: true);
  }
}

final class GaUserDeletionClientException implements Exception {
  const GaUserDeletionClientException({
    required this.innerError,
    required this.innerStackTrace,
  });

  final Object innerError;
  final StackTrace innerStackTrace;

  @override
  String toString() =>
      'Google Analytics Admin API user-deletion submission failed.';
}

final class GaUserDeletionResponseShapeException implements Exception {
  const GaUserDeletionResponseShapeException();
}
