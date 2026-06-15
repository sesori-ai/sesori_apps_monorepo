import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sesori_bridge/src/updater/api/github_releases_api.dart';
import 'package:sesori_bridge/src/updater/foundation/github_rate_limit_exception.dart';
import 'package:test/test.dart';

void main() {
  group('GitHubReleasesApi', () {
    group('authentication', () {
      test('sends a Bearer Authorization header when a token is provided', () async {
        String? authorization;
        final client = MockClient((request) async {
          authorization = request.headers['authorization'];
          return http.Response('[]', 200);
        });

        await GitHubReleasesApi(httpClient: client, authToken: 'secret-token').fetchReleases();

        expect(authorization, equals('Bearer secret-token'));
      });

      test('omits the Authorization header when no token is provided', () async {
        var hadAuthorization = true;
        final client = MockClient((request) async {
          hadAuthorization = request.headers.containsKey('authorization');
          return http.Response('[]', 200);
        });

        await GitHubReleasesApi(httpClient: client).fetchReleases();

        expect(hadAuthorization, isFalse);
      });

      test('omits the Authorization header when the token is empty', () async {
        var hadAuthorization = true;
        final client = MockClient((request) async {
          hadAuthorization = request.headers.containsKey('authorization');
          return http.Response('[]', 200);
        });

        await GitHubReleasesApi(httpClient: client, authToken: '').fetchReleases();

        expect(hadAuthorization, isFalse);
      });
    });

    group('rate limiting', () {
      test('HTTP 403 with x-ratelimit-remaining: 0 → GitHubRateLimitException with reset time', () async {
        final resetEpochSeconds = DateTime.utc(2030, 6, 1, 15).millisecondsSinceEpoch ~/ 1000;
        final client = MockClient(
          (_) async => http.Response('', 403, headers: {
            'x-ratelimit-remaining': '0',
            'x-ratelimit-reset': '$resetEpochSeconds',
          }),
        );

        await expectLater(
          GitHubReleasesApi(httpClient: client).fetchReleases(),
          throwsA(
            isA<GitHubRateLimitException>().having(
              (exception) => exception.resetAt,
              'resetAt',
              equals(
                DateTime.fromMillisecondsSinceEpoch(
                  resetEpochSeconds * 1000,
                  isUtc: true,
                ).toLocal(),
              ),
            ),
          ),
        );
      });

      test('HTTP 429 → GitHubRateLimitException', () async {
        final client = MockClient((_) async => http.Response('', 429));

        await expectLater(
          GitHubReleasesApi(httpClient: client).fetchReleases(),
          throwsA(isA<GitHubRateLimitException>()),
        );
      });

      test('HTTP 403 without an exhausted budget → StateError, not a rate limit', () async {
        final client = MockClient((_) async => http.Response('', 403));

        await expectLater(
          GitHubReleasesApi(httpClient: client).fetchReleases(),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
