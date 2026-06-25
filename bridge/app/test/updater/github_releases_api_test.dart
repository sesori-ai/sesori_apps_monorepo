import 'dart:io';

import 'package:clock/clock.dart';
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

        await GitHubReleasesApi(httpClient: client, authToken: null).fetchReleases();

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

    group('opportunistic auth fallback', () {
      test('rejected token (401) → retries once without Authorization and succeeds', () async {
        final authHeaderSeen = <bool>[];
        final client = MockClient((request) async {
          final attempt = authHeaderSeen.length;
          authHeaderSeen.add(request.headers.containsKey('authorization'));
          return attempt == 0
              ? http.Response('Bad credentials', 401)
              : http.Response('[]', 200);
        });

        final releases =
            await GitHubReleasesApi(httpClient: client, authToken: 'stale-token').fetchReleases();

        expect(releases, isEmpty);
        // Authenticated first, then an unauthenticated retry.
        expect(authHeaderSeen, equals([true, false]));
      });

      test('token-related 403 (no rate-limit signal) → retries unauthenticated', () async {
        final authHeaderSeen = <bool>[];
        final client = MockClient((request) async {
          final attempt = authHeaderSeen.length;
          authHeaderSeen.add(request.headers.containsKey('authorization'));
          return attempt == 0 ? http.Response('', 403) : http.Response('[]', 200);
        });

        final releases =
            await GitHubReleasesApi(httpClient: client, authToken: 'scopeless-token').fetchReleases();

        expect(releases, isEmpty);
        expect(authHeaderSeen, equals([true, false]));
      });

      test('rate-limited 403 with a token → does NOT retry, surfaces the rate limit', () async {
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return http.Response('', 403, headers: {'x-ratelimit-remaining': '0'});
        });

        await expectLater(
          GitHubReleasesApi(httpClient: client, authToken: 'valid-token').fetchReleases(),
          throwsA(
            isA<GitHubRateLimitException>().having(
              (exception) => exception.authenticated,
              'authenticated',
              isTrue,
            ),
          ),
        );
        expect(calls, equals(1));
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
          GitHubReleasesApi(httpClient: client, authToken: null).fetchReleases(),
          throwsA(
            isA<GitHubRateLimitException>()
                .having(
                  (exception) => exception.resetAt,
                  'resetAt',
                  equals(
                    DateTime.fromMillisecondsSinceEpoch(
                      resetEpochSeconds * 1000,
                      isUtc: true,
                    ).toLocal(),
                  ),
                )
                .having((exception) => exception.authenticated, 'authenticated', isFalse),
          ),
        );
      });

      test('HTTP 429 → GitHubRateLimitException', () async {
        final client = MockClient((_) async => http.Response('', 429));

        await expectLater(
          GitHubReleasesApi(httpClient: client, authToken: null).fetchReleases(),
          throwsA(isA<GitHubRateLimitException>()),
        );
      });

      test('retry-after takes precedence over x-ratelimit-reset for the reset hint', () async {
        final now = DateTime.utc(2030, 6, 1, 15);
        final farFutureReset = now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
        final client = MockClient(
          (_) async => http.Response('', 403, headers: {
            'x-ratelimit-remaining': '0',
            'x-ratelimit-reset': '$farFutureReset',
            'retry-after': '60',
          }),
        );

        Object? caught;
        await withClock(Clock.fixed(now), () async {
          try {
            await GitHubReleasesApi(httpClient: client, authToken: null).fetchReleases();
          } on Object catch (error) {
            caught = error;
          }
        });

        // The shorter secondary cooldown (retry-after) wins over the hourly
        // primary window.
        expect(
          (caught! as GitHubRateLimitException).resetAt,
          equals(now.add(const Duration(seconds: 60))),
        );
      });

      test('secondary HTTP 403 with retry-after → GitHubRateLimitException, reset from clock', () async {
        final now = DateTime.utc(2030, 6, 1, 15);
        final client = MockClient(
          (_) async => http.Response('', 403, headers: {'retry-after': '120'}),
        );

        Object? caught;
        await withClock(Clock.fixed(now), () async {
          try {
            await GitHubReleasesApi(httpClient: client, authToken: null).fetchReleases();
          } on Object catch (error) {
            caught = error;
          }
        });

        expect(caught, isA<GitHubRateLimitException>());
        expect(
          (caught! as GitHubRateLimitException).resetAt,
          equals(now.add(const Duration(seconds: 120))),
        );
      });

      test('HTTP 403 without an exhausted budget or retry-after → StateError, not a rate limit', () async {
        final client = MockClient((_) async => http.Response('', 403));

        await expectLater(
          GitHubReleasesApi(httpClient: client, authToken: null).fetchReleases(),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('transient outages', () {
      for (final status in [500, 502, 503, 504, 408]) {
        test('HTTP $status → HttpException (retryable), not a genuine StateError', () async {
          final client = MockClient((_) async => http.Response('', status));

          await expectLater(
            GitHubReleasesApi(httpClient: client, authToken: null).fetchReleases(),
            throwsA(isA<HttpException>()),
          );
        });
      }

      test('HTTP 404 stays a genuine StateError', () async {
        final client = MockClient((_) async => http.Response('', 404));

        await expectLater(
          GitHubReleasesApi(httpClient: client, authToken: null).fetchReleases(),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
