import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/updater/api/github_releases_api.dart';
import 'package:sesori_bridge/src/updater/api/update_cache_api.dart';
import 'package:sesori_bridge/src/updater/foundation/platform_info.dart';
import 'package:sesori_bridge/src/updater/models/cached_release.dart';
import 'package:sesori_bridge/src/updater/models/distribution_target.dart';
import 'package:sesori_bridge/src/updater/repositories/release_repository.dart';
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
        os: DistributionPlatformOs.macos,
        arch: DistributionPlatformArch.arm64,
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
              tagName: 'bridge-v0.4.0-beta.1',
              draft: false,
              prerelease: true,
              assets: [
                target.assetName,
                'checksums.txt',
              ],
            ),
            _releaseFixture(
              tagName: 'bridge-v0.3.2',
              draft: false,
              prerelease: false,
              assets: [
                'sesori-bridge-linux-x64.tar.gz',
                'checksums.txt',
              ],
            ),
            _releaseFixture(
              tagName: 'bridge-v0.3.1',
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
        api: GitHubReleasesApi(httpClient: client),
        cache: _NoCache(),
        currentVersion: '0.2.0',
        target: target,
      );
    });

    test('runtime selects newest valid stable bridge release', () async {
      final release = await repository.checkForNewerRelease();

      expect(release, isNotNull);
      expect(release!.version, equals('0.3.1'));
      expect(
        release.assetUrl,
        equals(
          'https://example.com/releases/download/bridge-v0.3.1/sesori-bridge-macos-arm64.tar.gz',
        ),
      );
      expect(
        release.checksumsUrl,
        equals('https://example.com/releases/download/bridge-v0.3.1/checksums.txt'),
      );
    });

    test('install.sh encodes the same bridge-tagged asset and basename checksum contract', () async {
      final script = await _readRepoFile(relativePath: 'install.sh');

      expect(script, contains(r'GITHUB_RELEASES_API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases"'));
      expect(script, contains('GITHUB_RELEASES_PER_PAGE=100'));
      expect(script, contains('GITHUB_RELEASES_MAX_PAGES=10'));
      expect(script, contains(r'?per_page=${GITHUB_RELEASES_PER_PAGE}&page=${page}'));
      expect(script, contains('bridge-v'));
      expect(script, contains('release.get("draft") or release.get("prerelease")'));
      expect(script, contains('eligible.sort('));
      expect(script, contains('asset_url = assets.get(filename)'));
      expect(script, contains('checksums_url = assets.get("checksums.txt")'));
      expect(
        script,
        contains(r'''awk -v name="${filename}" '$2 == name || $2 == "*" name { print $1; exit }' '''),
      );
    });

    test('install.ps1 encodes the same bridge-tagged asset and basename checksum contract', () async {
      final script = await _readRepoFile(relativePath: 'install.ps1');

      expect(script, contains(r'$ReleasesApiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases"'));
      expect(script, contains(r'$ReleasesPerPage = 100'));
      expect(script, contains(r'$ReleasesMaxPages = 10'));
      expect(script, contains(r'"$ReleasesApiUrl?per_page=$ReleasesPerPage&page=$page"'));
      expect(script, contains("StartsWith('bridge-v')"));
      expect(script, contains(r'''$release.draft -or $release.prerelease'''));
      expect(script, contains('Sort-Object Version -Descending'));
      expect(script, contains(r'''Where-Object { $_.name -eq $ArchiveName }'''));
      expect(script, contains(r'''Where-Object { $_.name -eq 'checksums.txt' }'''));
      expect(script, contains(r'''if ($filePart -eq $ArchiveName) {'''));
    });

    test('workflow and docs lock basename checksums and tag-driven npm publish path', () async {
      final workflow = await _readRepoFile(relativePath: '.github/workflows/bridge-release.yml');
      final docs = await _readRepoFile(relativePath: 'bridge/RELEASING.md');

      expect(workflow, contains('tags: ["bridge-v*"]'));
      expect(workflow, contains('workflow_dispatch:'));
      expect(workflow, contains('dry_run:'));
      expect(
        workflow,
        contains("if: github.event.inputs.dry_run != 'true' && startsWith(github.ref_name, 'bridge-v')"),
      );
      expect(workflow, contains(r'RELEASE_TAG: ${{ github.ref_name }}'));
      expect(workflow, contains(r'gh release download "$RELEASE_TAG"'));
      expect(workflow, contains('--pattern "*.tar.gz" --pattern "*.zip" --pattern "checksums.txt"'));
      expect(workflow, contains(r'if [[ "$CURRENT_VERSION" == "${{ steps.version.outputs.VERSION }}" ]]'));
      expect(workflow, contains('Verify release archive checksums'));
      expect(workflow, contains('checksum_for()'));
      expect(workflow, contains('verify_archive_checksum()'));
      expect(workflow, contains('copy_runtime_bundle()'));
      expect(workflow, contains(r'cp -R "$source_root/bin" "$package_root/lib/runtime/bin"'));
      expect(workflow, contains(r'cp -R "$source_root/lib" "$package_root/lib/runtime/lib"'));
      expect(workflow, contains('.bridge-release-provenance.json'));
      expect(workflow, contains(r'diff -r "$source_root/bin" "$package_root/lib/runtime/bin"'));
      expect(workflow, contains(r'diff -r "$source_root/lib" "$package_root/lib/runtime/lib"'));
      expect(workflow, contains(r'sha256sum "$file" | awk -v name="$(basename "$file")"'));
      expect(workflow, contains(r'Version already set to $CURRENT_VERSION; skipping bump.'));

      expect(docs, contains('## What the workflow does on tag push'));
      expect(docs, contains('6. publishes the five platform npm bootstrap packages from those tagged release assets'));
      expect(docs, contains('gh workflow run bridge-release.yml -f dry_run=true'));
      expect(
        docs,
        contains(
          'The tag-triggered workflow verifies the archived GitHub Release assets against `checksums.txt`, derives each platform npm payload from those exact release artifacts, and then publishes through npm trusted publishing on `ubuntu-latest`.',
        ),
      );
      expect(docs, contains('Use this sequence when you want to test the real packaged distribution flow end to end.'));
    });

    test('workflow asset names and npm package manifests stay aligned', () async {
      final workflow = await _readRepoFile(relativePath: '.github/workflows/bridge-release.yml');
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
      };

      for (final entry in workflowAssets.entries) {
        expect(workflow, contains(entry.value));
        expect(workflow, contains(entry.key.replaceFirst('@sesori/', 'sesori-')));
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
            'releaseTag': 'bridge-v$appVersion',
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
