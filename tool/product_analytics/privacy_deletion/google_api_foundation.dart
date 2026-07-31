import 'dart:convert';
import 'dart:io';

import 'privacy_deletion_models.dart';

const String bigQueryOAuthScope = 'https://www.googleapis.com/auth/bigquery';
const String analyticsEditOAuthScope =
    'https://www.googleapis.com/auth/analytics.edit';

enum AdcCredentialSource {
  notUsed,
  metadataServer,
  gcloudApplicationDefault;

  String get wireValue => switch (this) {
    notUsed => 'not_used',
    metadataServer => 'metadata_server',
    gcloudApplicationDefault => 'gcloud_application_default',
  };
}

final class GoogleAccessToken {
  const GoogleAccessToken({
    required this.value,
    required this.expiresAt,
    required this.source,
    required this.recoveredMetadataFailure,
  });

  final String value;
  final DateTime expiresAt;
  final AdcCredentialSource source;
  final AccessTokenAcquisitionException? recoveredMetadataFailure;
}

abstract interface class GoogleAccessTokenProvider {
  AdcCredentialSource get lastSource;
  bool get usedFallback;

  Future<GoogleAccessToken> accessToken();

  void close();
}

final class ApplicationDefaultAccessTokenProvider
    implements GoogleAccessTokenProvider {
  ApplicationDefaultAccessTokenProvider({
    required Set<String> scopes,
    required Duration metadataTimeout,
    required bool allowGcloudApplicationDefaultFallback,
    required DateTime Function() now,
  }) : _scopes = List<String>.unmodifiable(scopes.toList()..sort()),
       _metadataTimeout = metadataTimeout,
       _allowGcloudApplicationDefaultFallback =
           allowGcloudApplicationDefaultFallback,
       _now = now,
       _metadataClient = HttpClient() {
    if (_scopes.isEmpty) {
      throw const PrivacyDeletionValidationException(
        field: 'oauth_scopes',
        requirement: 'at least one OAuth scope',
      );
    }
    _metadataClient.connectionTimeout = metadataTimeout;
  }

  final List<String> _scopes;
  final Duration _metadataTimeout;
  final bool _allowGcloudApplicationDefaultFallback;
  final DateTime Function() _now;
  final HttpClient _metadataClient;
  GoogleAccessToken? _cachedToken;
  AdcCredentialSource _lastSource = AdcCredentialSource.notUsed;
  bool _usedFallback = false;

  @override
  AdcCredentialSource get lastSource => _lastSource;

  @override
  bool get usedFallback => _usedFallback;

  @override
  Future<GoogleAccessToken> accessToken() async {
    final cached = _cachedToken;
    if (cached != null &&
        cached.expiresAt.isAfter(_now().add(const Duration(minutes: 2)))) {
      return cached;
    }

    AccessTokenAcquisitionException? metadataFailure;
    try {
      final token = await _metadataAccessToken();
      _cachedToken = token;
      _lastSource = token.source;
      return token;
    } catch (error, stackTrace) {
      metadataFailure = AccessTokenAcquisitionException(
        source: AdcCredentialSource.metadataServer,
        innerError: error,
        innerStackTrace: stackTrace,
        priorFailure: null,
      );
    }

    if (!_allowGcloudApplicationDefaultFallback) {
      throw metadataFailure;
    }

    try {
      final token = await _gcloudApplicationDefaultAccessToken(
        metadataFailure: metadataFailure,
      );
      _cachedToken = token;
      _lastSource = token.source;
      _usedFallback = true;
      return token;
    } catch (error, stackTrace) {
      throw AccessTokenAcquisitionException(
        source: AdcCredentialSource.gcloudApplicationDefault,
        innerError: error,
        innerStackTrace: stackTrace,
        priorFailure: metadataFailure,
      );
    }
  }

  Future<GoogleAccessToken> _metadataAccessToken() async {
    final scopes = Uri.encodeQueryComponent(_scopes.join(','));
    final uri = Uri.parse(
      'http://metadata.google.internal/computeMetadata/v1/instance/'
      'service-accounts/default/token?scopes=$scopes',
    );
    final request = await _metadataClient.getUrl(uri).timeout(_metadataTimeout);
    request.headers.set('Metadata-Flavor', 'Google');
    final response = await request.close().timeout(_metadataTimeout);
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>().timeout(_metadataTimeout);
      throw MetadataServerResponseException(statusCode: response.statusCode);
    }
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_metadataTimeout);
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (error, stackTrace) {
      throw CredentialPayloadException(
        source: AdcCredentialSource.metadataServer,
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const CredentialPayloadShapeException(
        source: AdcCredentialSource.metadataServer,
      );
    }
    final token = decoded['access_token'];
    final expiresIn = decoded['expires_in'];
    if (token is! String || token.isEmpty || expiresIn is! num) {
      throw const CredentialPayloadShapeException(
        source: AdcCredentialSource.metadataServer,
      );
    }
    return GoogleAccessToken(
      value: token,
      expiresAt: _now().add(Duration(seconds: expiresIn.toInt())),
      source: AdcCredentialSource.metadataServer,
      recoveredMetadataFailure: null,
    );
  }

  Future<GoogleAccessToken> _gcloudApplicationDefaultAccessToken({
    required AccessTokenAcquisitionException metadataFailure,
  }) async {
    final result = await Process.run(
      'gcloud',
      <String>[
        'auth',
        'application-default',
        'print-access-token',
        '--scopes=${_scopes.join(',')}',
      ],
      environment: applicationDefaultProcessEnvironment(
        parentEnvironment: Platform.environment,
      ),
      includeParentEnvironment: false,
      runInShell: false,
    );
    if (result.exitCode != 0) {
      throw GcloudApplicationDefaultException(exitCode: result.exitCode);
    }
    final token = (result.stdout as String).trim();
    if (token.isEmpty || token.contains(RegExp(r'\s'))) {
      throw const CredentialPayloadShapeException(
        source: AdcCredentialSource.gcloudApplicationDefault,
      );
    }
    return GoogleAccessToken(
      value: token,
      expiresAt: _now().add(const Duration(minutes: 45)),
      source: AdcCredentialSource.gcloudApplicationDefault,
      recoveredMetadataFailure: metadataFailure,
    );
  }

  @override
  void close() {
    _metadataClient.close(force: true);
  }
}

Map<String, String> applicationDefaultProcessEnvironment({
  required Map<String, String> parentEnvironment,
}) {
  return Map<String, String>.from(parentEnvironment)
    ..remove('GOOGLE_APPLICATION_CREDENTIALS');
}

final class AccessTokenAcquisitionException implements Exception {
  const AccessTokenAcquisitionException({
    required this.source,
    required this.innerError,
    required this.innerStackTrace,
    required this.priorFailure,
  });

  final AdcCredentialSource source;
  final Object innerError;
  final StackTrace innerStackTrace;
  final AccessTokenAcquisitionException? priorFailure;

  @override
  String toString() =>
      'Could not acquire Application Default Credentials from '
      '${source.wireValue}.';
}

final class MetadataServerResponseException implements Exception {
  const MetadataServerResponseException({required this.statusCode});

  final int statusCode;
}

final class GcloudApplicationDefaultException implements Exception {
  const GcloudApplicationDefaultException({required this.exitCode});

  final int exitCode;
}

final class CredentialPayloadShapeException implements Exception {
  const CredentialPayloadShapeException({required this.source});

  final AdcCredentialSource source;
}

final class CredentialPayloadException implements Exception {
  const CredentialPayloadException({
    required this.source,
    required this.innerError,
    required this.innerStackTrace,
  });

  final AdcCredentialSource source;
  final Object innerError;
  final StackTrace innerStackTrace;
}

final class GoogleApiHttpException implements Exception {
  const GoogleApiHttpException({required this.statusCode});

  final int statusCode;
}

final class GoogleApiPayloadException implements Exception {
  const GoogleApiPayloadException({
    required this.innerError,
    required this.innerStackTrace,
  });

  final Object innerError;
  final StackTrace innerStackTrace;
}
