import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/updater/api/github_releases_api.dart';
import 'package:sesori_bridge/src/updater/api/update_cache_api.dart';
import 'package:sesori_bridge/src/updater/foundation/release_track.dart';
import 'package:sesori_bridge/src/updater/models/cached_release.dart';
import 'package:sesori_bridge/src/updater/models/distribution_target.dart';
import 'package:sesori_bridge/src/updater/repositories/release_repository.dart';
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart';
import 'package:test/test.dart';

class _NoCache extends UpdateCacheApi {
  _NoCache() : super(cacheDirectory: '', clock: const Clock());

  @override
  Future<CachedRelease?> read({required Duration ttl}) async => null;

  @override
  Future<void> write({required CachedRelease release}) async {}
}

String _repoRoot() {
  return p.normalize(p.join(Directory.current.path, '..', '..'));
}

Map<String, dynamic> _releaseFixture({
  required String tagName,
  required bool draft,
  required bool prerelease,
  required List<String> assets,
}) {
  return {
    'tag_name': tagName,
    'published_at': '2024-06-01T00:00:00Z',
    'draft': draft,
    'prerelease': prerelease,
    'assets': assets
        .map(
          (name) => {
            'name': name,
            'browser_download_url': 'https://example.com/releases/download/$tagName/$name',
          },
        )
        .toList(),
  };
}

Future<String> _readRepoFile({required String relativePath}) {
  final root = _repoRoot();
  return File(p.join(root, relativePath)).readAsString();
}

Future<Map<String, dynamic>> _readRepoJson({required String relativePath}) async {
  final content = await _readRepoFile(relativePath: relativePath);
  return jsonDecode(content) as Map<String, dynamic>;
}

Future<String> _appVersion() async {
  final package = await _readRepoJson(
    relativePath: 'bridge/app/npm/sesori-bridge/package.json',
  );
  return package['version'] as String;
}

void main() {
  group('bridge release contract', () {
    late ReleaseRepository repository;

    setUp(() {
      final target = DistributionTarget(
        os: PlatformOs.macos,
        arch: PlatformArch.arm64,
      );
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode([
            _releaseFixture(
              tagName: 'repo-v9.9.9',
              draft: false,
              prerelease: false,
              assets: [
                target.assetName,
                'checksums.txt',
              ],
            ),
            _releaseFixture(
              tagName: 'v0.4.0-beta.1',
              draft: false,
              prerelease: true,
              assets: [
                target.assetName,
                'checksums.txt',
              ],
            ),
            _releaseFixture(
              tagName: 'v0.3.2',
              draft: false,
              prerelease: false,
              assets: [
                'sesori-bridge-linux-x64.tar.gz',
                'checksums.txt',
              ],
            ),
            _releaseFixture(
              tagName: 'v0.3.1',
              draft: false,
              prerelease: false,
              assets: [
                target.assetName,
                'checksums.txt',
              ],
            ),
          ]),
          200,
        );
      });

      repository = ReleaseRepository(
        api: GitHubReleasesApi(httpClient: client, authToken: null),
        cache: _NoCache(),
        currentVersion: '0.2.0',
        target: target,
        track: ReleaseTrack.stable,
      );
    });

    test('runtime selects newest valid stable bridge release', () async {
      final release = await repository.checkForNewerRelease();

      expect(release, isNotNull);
      expect(release!.version, equals('0.3.1'));
      expect(
        release.assetUrl,
        equals(
          'https://example.com/releases/download/v0.3.1/sesori-bridge-macos-arm64.tar.gz',
        ),
      );
      expect(
        release.checksumsUrl,
        equals('https://example.com/releases/download/v0.3.1/checksums.txt'),
      );
    });

    test('install.sh encodes the latest/download contract with a v-tagged scan fallback', () async {
      final script = await _readRepoFile(relativePath: 'install.sh');

      // Primary path: GitHub-native always-latest static download; the version is
      // read from the versioned download redirect, and both the archive and
      // checksums.txt are required before the latest release is accepted.
      expect(script, contains(r'GITHUB="${GITHUB:-https://github.com}"'));
      expect(script, contains('releases/latest/download'));
      expect(script, contains(r'${latest_base}/${filename}'));
      expect(script, contains(r'${latest_base}/checksums.txt'));
      expect(script, contains('parse_version_from_headers'));
      expect(script, contains('headers_indicate_success'));

      // Fallback scan: still the REST API, but small and reading pages from
      // files (paths-as-args only), never env vars.
      expect(script, contains(r'GITHUB_API="${GITHUB_API:-https://api.github.com}"'));
      expect(script, contains('GITHUB_RELEASES_PER_PAGE=30'));
      expect(script, contains('GITHUB_RELEASES_MAX_PAGES=3'));
      expect(script, contains(r'?per_page=${GITHUB_RELEASES_PER_PAGE}&page=${page}'));
      expect(script, contains('if tag_name.startswith("v"):'));
      expect(script, contains('release.get("draft") or release.get("prerelease")'));
      expect(script, contains('eligible.sort('));
      expect(script, contains('if filename in asset_names and "checksums.txt" in asset_names:'));
      expect(
        script,
        contains(r'''awk -v name="${filename}" '$2 == name || $2 == "*" name { print $1; exit }' '''),
      );
    });

    test('install.ps1 encodes the latest/download contract with a v-tagged scan fallback', () async {
      final script = await _readRepoFile(relativePath: 'install.ps1');

      // Primary path: latest/download static asset + redirect-derived version,
      // requiring the archive and checksums before accepting the latest release.
      expect(script, contains(r'releases/latest/download/$ArchiveName'));
      expect(script, contains('Get-RedirectLocation'));
      expect(script, contains(r'releases/download/(v[0-9]+\.[0-9]+\.[0-9]+)/'));
      expect(script, contains('Test-RemoteAssetExists'));

      // Fallback scan retained, with the smaller paging contract.
      expect(script, contains(r'$ReleasesApiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases"'));
      expect(script, contains(r'$ReleasesPerPage = 30'));
      expect(script, contains(r'$ReleasesMaxPages = 3'));
      expect(script, contains(r'"${ReleasesApiUrl}?per_page=$ReleasesPerPage&page=$page"'));
      expect(script, contains("StartsWith('v')"));
      expect(script, contains(r'''$release.draft -or $release.prerelease'''));
      expect(script, contains('Sort-Object Version -Descending'));
      expect(script, contains(r'''Where-Object { $_.name -eq $ArchiveName }'''));
      expect(script, contains(r'''Where-Object { $_.name -eq 'checksums.txt' }'''));
      expect(script, contains(r'''if ($filePart -eq $ArchiveName) {'''));
    });

    test('workflows and docs lock basename checksums and automatic trusted publishing', () async {
      final npmWorkflow = await _readRepoFile(relativePath: '.github/workflows/bridge-npm-publish.yml');
      final submitWorkflow = await _readRepoFile(relativePath: '.github/workflows/submit-release.yml');
      final internalWorkflow = await _readRepoFile(relativePath: '.github/workflows/release-all-platforms.yml');
      final docs = await _readRepoFile(relativePath: 'bridge/RELEASING.md');

      // npm publishing fires when a stable release goes LIVE (immediate
      // publish or manual pre-release promotion), via trusted publishing.
      expect(npmWorkflow, contains('release:'));
      expect(npmWorkflow, contains('types: [released]'));
      expect(npmWorkflow, contains('needs: gate'));
      expect(npmWorkflow, contains('needs: [gate, publish-platform]'));
      expect(npmWorkflow, contains('id-token: write'));
      // Both publish jobs run in the gated `store-production` environment.
      expect(npmWorkflow, contains('environment: store-production'));
      expect(npmWorkflow, contains('registry-url: "https://registry.npmjs.org"'));
      expect(npmWorkflow, contains(r'gh release download "$RELEASE_TAG"'));
      expect(npmWorkflow, contains('--pattern "*.tar.gz" --pattern "*.zip" --pattern "checksums.txt"'));
      expect(npmWorkflow, contains('Verify release archive checksums'));
      expect(npmWorkflow, contains('checksum_for()'));
      expect(npmWorkflow, contains('verify_archive_checksum()'));
      expect(npmWorkflow, contains('copy_runtime_bundle()'));
      expect(npmWorkflow, contains(r'cp -R "$source_root/bin" "$package_root/lib/runtime/bin"'));
      expect(npmWorkflow, contains(r'cp -R "$source_root/lib" "$package_root/lib/runtime/lib"'));
      expect(npmWorkflow, contains('.bridge-release-provenance.json'));
      expect(npmWorkflow, contains(r'diff -r "$source_root/bin" "$package_root/lib/runtime/bin"'));
      expect(npmWorkflow, contains(r'diff -r "$source_root/lib" "$package_root/lib/runtime/lib"'));
      expect(npmWorkflow, contains('Validate wrapper package metadata'));
      expect(npmWorkflow, isNot(contains('NPM_TOKEN')));

      // Both release-producing workflows generate basename-keyed checksums
      // exactly as the updater and installers expect.
      const checksumLine = r'sha256sum "$file" | awk -v name="$(basename "$file")"';
      expect(submitWorkflow, contains(checksumLine));
      expect(internalWorkflow, contains(checksumLine));
      expect(submitWorkflow, contains('artifacts/checksums.txt'));
      expect(internalWorkflow, contains('artifacts/checksums.txt'));

      expect(docs, contains('## What the release pipeline does'));
      expect(docs, contains('6. publishes the six platform npm bootstrap packages from those tagged release assets'));
      expect(docs, contains('7. publishes the `@sesori/bridge` wrapper package through npm trusted publishing'));
      expect(
        docs,
        contains(
          'The workflow verifies the archived GitHub Release assets against `checksums.txt`, derives each platform npm payload from those exact release artifacts, and then publishes through npm trusted publishing on `ubuntu-latest`.',
        ),
      );
      expect(docs, contains('Use this sequence when you want to test the real packaged distribution flow end to end.'));
      expect(
        docs,
        contains(
          'Configure npm trusted publishing for all seven packages in this repo against the exact workflow file `.github/workflows/bridge-npm-publish.yml`',
        ),
      );
    });

    test('workflow asset names and npm package manifests stay aligned', () async {
      final buildWorkflow = await _readRepoFile(relativePath: '.github/workflows/_reusable-bridge-build.yml');
      final npmWorkflow = await _readRepoFile(relativePath: '.github/workflows/bridge-npm-publish.yml');
      final wrapperPackage = await _readRepoJson(
        relativePath: 'bridge/app/npm/sesori-bridge/package.json',
      );
      final appVersion = await _appVersion();

      const workflowAssets = <String, String>{
        '@sesori/bridge-darwin-arm64': 'sesori-bridge-macos-arm64.tar.gz',
        '@sesori/bridge-darwin-x64': 'sesori-bridge-macos-x64.tar.gz',
        '@sesori/bridge-linux-x64': 'sesori-bridge-linux-x64.tar.gz',
        '@sesori/bridge-linux-arm64': 'sesori-bridge-linux-arm64.tar.gz',
        '@sesori/bridge-win32-x64': 'sesori-bridge-windows-x64.zip',
        '@sesori/bridge-win32-arm64': 'sesori-bridge-windows-arm64.zip',
      };

      for (final entry in workflowAssets.entries) {
        // The reusable build matrix produces each archive name...
        expect(buildWorkflow, contains(entry.value.replaceAll(RegExp(r'\.(tar\.gz|zip)$'), '')));
        // ...and the npm publish workflow consumes each archive into the
        // matching platform package directory.
        expect(npmWorkflow, contains(entry.value));
        expect(npmWorkflow, contains(entry.key.replaceFirst('@sesori/', 'sesori-')));
      }

      final optionalDependencies = wrapperPackage['optionalDependencies'] as Map<String, dynamic>;
      expect(optionalDependencies.keys, equals(workflowAssets.keys));

      for (final packageName in workflowAssets.keys) {
        final package = await _readRepoJson(
          relativePath: 'bridge/app/npm/${packageName.replaceFirst('@sesori/', 'sesori-')}/package.json',
        );
        expect(package['name'], equals(packageName));
        expect(package['files'], equals(['lib/runtime/']));
        expect(package.containsKey('bin'), isFalse);
        expect(package['description'], contains('Bootstrap payload for the managed Sesori Bridge runtime'));
        expect(
          package['sesoriBridge'],
          equals({
            'bootstrapOnly': true,
            'managedRuntimeOwner': false,
            'releaseTag': 'v$appVersion',
            'releaseArtifact': workflowAssets[packageName],
            'runtimeBundlePath': 'lib/runtime',
          }),
        );
      }

      expect(
        wrapperPackage['sesoriBridge'],
        equals({
          'bootstrapOnly': true,
          'managedRuntimeOwner': false,
          'releaseTag': 'v$appVersion',
          'runtimeBundleSource': 'github-release-assets',
        }),
      );
    });

    test('npm package manifests keep uninstall independent from the managed runtime', () async {
      const packageNames = <String>[
        '@sesori/bridge',
        '@sesori/bridge-darwin-arm64',
        '@sesori/bridge-darwin-x64',
        '@sesori/bridge-linux-x64',
        '@sesori/bridge-linux-arm64',
        '@sesori/bridge-win32-x64',
        '@sesori/bridge-win32-arm64',
      ];

      for (final packageName in packageNames) {
        final relativePath = packageName == '@sesori/bridge'
            ? 'bridge/app/npm/sesori-bridge/package.json'
            : 'bridge/app/npm/${packageName.replaceFirst('@sesori/', 'sesori-')}/package.json';
        final package = await _readRepoJson(relativePath: relativePath);
        final scripts = (package['scripts'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

        expect(scripts.containsKey('preuninstall'), isFalse, reason: packageName);
        expect(scripts.containsKey('uninstall'), isFalse, reason: packageName);
        expect(scripts.containsKey('postuninstall'), isFalse, reason: packageName);
      }

      final wrapperPackage = await _readRepoJson(
        relativePath: 'bridge/app/npm/sesori-bridge/package.json',
      );
      expect(wrapperPackage['bin'], equals({'sesori-bridge': 'bin/bridge.js'}));
    });
  });
}
