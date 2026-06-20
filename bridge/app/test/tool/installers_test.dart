import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String _repoRoot() => p.normalize(p.join(Directory.current.path, '..', '..'));

String _installShPath() => p.join(_repoRoot(), 'install.sh');

String _installPs1Path() => p.join(_repoRoot(), 'install.ps1');

Future<String> _createInstallShLibrary() async {
  final tempDir = await Directory.systemTemp.createTemp('install-sh-lib-');
  addTearDown(() => tempDir.delete(recursive: true));

  final original = await File(_installShPath()).readAsString();
  final librarySource = original.replaceFirst(RegExp(r'\nmain\s*\n?$'), '\n');
  final libraryPath = p.join(tempDir.path, 'install-lib.sh');
  await File(libraryPath).writeAsString(librarySource);
  return libraryPath;
}

Future<ProcessResult> _runBashSnippet({
  required String script,
  required Map<String, String> environment,
}) {
  return Process.run('/bin/bash', ['-c', script], environment: environment);
}

Future<String> _createExecutable({
  required Directory binDir,
  required String name,
  required String body,
}) async {
  final filePath = p.join(binDir.path, name);
  await File(filePath).writeAsString(body);
  final chmod = await Process.run('chmod', ['+x', filePath]);
  if (chmod.exitCode != 0) {
    fail('chmod failed for $name: ${chmod.stderr}');
  }
  return filePath;
}

void main() {
  group('install.sh', () {
    test('detects macOS and arm64 using uname output', () async {
      final libraryPath = await _createInstallShLibrary();
      final tempDir = await Directory.systemTemp.createTemp('install-sh-detect-');
      addTearDown(() => tempDir.delete(recursive: true));
      final binDir = await Directory(p.join(tempDir.path, 'bin')).create();
      await _createExecutable(
        binDir: binDir,
        name: 'uname',
        body: '#!/bin/sh\nif [ "\$1" = "-s" ]; then\n  printf "Darwin\\n"\nelse\n  printf "arm64\\n"\nfi\n',
      );

      final result = await _runBashSnippet(
        script: 'source ${jsonEncode(libraryPath)}; printf "%s/%s" "\$(detect_os)" "\$(detect_arch)"',
        environment: {
          'PATH': '${binDir.path}:${Platform.environment['PATH'] ?? ''}',
          'HOME': tempDir.path,
        },
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      expect((result.stdout as String).trim(), equals('macos/arm64'));
    });

    test('rejects unsupported operating systems', () async {
      final libraryPath = await _createInstallShLibrary();
      final tempDir = await Directory.systemTemp.createTemp('install-sh-os-');
      addTearDown(() => tempDir.delete(recursive: true));
      final binDir = await Directory(p.join(tempDir.path, 'bin')).create();
      await _createExecutable(
        binDir: binDir,
        name: 'uname',
        body: '#!/bin/sh\nprintf "FreeBSD\\n"\n',
      );

      final result = await _runBashSnippet(
        script: 'source ${jsonEncode(libraryPath)}; detect_os',
        environment: {
          'PATH': '${binDir.path}:${Platform.environment['PATH'] ?? ''}',
          'HOME': tempDir.path,
        },
      );

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains('Unsupported operating system: FreeBSD'));
      expect(result.stderr, contains('Sesori Bridge supports macOS and Linux only.'));
    });

    test('parses the version from a release-download redirect Location header', () async {
      final libraryPath = await _createInstallShLibrary();
      final tempDir = await Directory.systemTemp.createTemp('install-sh-parse-');
      addTearDown(() => tempDir.delete(recursive: true));

      final result = await _runBashSnippet(
        script:
            '''
source ${jsonEncode(libraryPath)}
printf '%s\n' 'HTTP/2 302' 'location: https://github.com/sesori-ai/sesori_apps_monorepo/releases/download/v1.2.3/sesori-bridge-linux-x64.tar.gz' | parse_version_from_headers
''',
        environment: {
          'PATH': Platform.environment['PATH'] ?? '',
          'HOME': tempDir.path,
        },
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      expect((result.stdout as String).trim(), equals('1.2.3'));
    });

    test('resolves the latest release via the static latest/download redirect (no API, no Python)', () async {
      final libraryPath = await _createInstallShLibrary();
      final tempDir = await Directory.systemTemp.createTemp('install-sh-latest-');
      addTearDown(() => tempDir.delete(recursive: true));
      final binDir = await Directory(p.join(tempDir.path, 'bin')).create();
      // A python3 that always fails proves the primary path never invokes it.
      await _createExecutable(
        binDir: binDir,
        name: 'python3',
        body: '#!/bin/sh\nexit 1\n',
      );

      final result = await _runBashSnippet(
        script:
            '''
source ${jsonEncode(libraryPath)}
fetch_redirect_headers() {
  printf '%s\n' 'location: https://github.com/sesori-ai/sesori_apps_monorepo/releases/download/v4.5.6/sesori-bridge-macos-arm64.tar.gz'
}
resolve_release sesori-bridge-macos-arm64.tar.gz
printf '%s\n%s\n%s\n' "\$RESOLVED_VERSION" "\$RESOLVED_ARCHIVE_URL" "\$RESOLVED_CHECKSUMS_URL"
''',
        environment: {
          'PATH': '${binDir.path}:${Platform.environment['PATH'] ?? ''}',
          'HOME': tempDir.path,
        },
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      expect(
        (result.stdout as String).trim(),
        equals(
          [
            '4.5.6',
            'https://github.com/sesori-ai/sesori_apps_monorepo/releases/download/v4.5.6/sesori-bridge-macos-arm64.tar.gz',
            'https://github.com/sesori-ai/sesori_apps_monorepo/releases/download/v4.5.6/checksums.txt',
          ].join('\n'),
        ),
      );
    });

    test('falls back to scanning older releases when latest/download lacks the asset', () async {
      final libraryPath = await _createInstallShLibrary();
      final tempDir = await Directory.systemTemp.createTemp('install-sh-fallback-');
      addTearDown(() => tempDir.delete(recursive: true));
      final releasesPath = p.join(tempDir.path, 'releases.json');
      await File(releasesPath).writeAsString(
        jsonEncode([
          // Non-"v" tag: ignored.
          {
            'tag_name': 'repo-v9.9.9',
            'draft': false,
            'prerelease': false,
            'assets': [
              {'name': 'sesori-bridge-macos-arm64.tar.gz'},
              {'name': 'checksums.txt'},
            ],
          },
          // Prerelease: ignored even though it is the newest.
          {
            'tag_name': 'v0.4.0-beta.1',
            'draft': false,
            'prerelease': true,
            'assets': [
              {'name': 'sesori-bridge-macos-arm64.tar.gz'},
              {'name': 'checksums.txt'},
            ],
          },
          {
            'tag_name': 'v0.3.1',
            'draft': false,
            'prerelease': false,
            'assets': [
              {'name': 'sesori-bridge-macos-arm64.tar.gz'},
              {'name': 'checksums.txt'},
            ],
          },
          {
            'tag_name': 'v0.4.0',
            'draft': false,
            'prerelease': false,
            'assets': [
              {'name': 'sesori-bridge-macos-arm64.tar.gz'},
              {'name': 'checksums.txt'},
            ],
          },
        ]),
      );

      final result = await _runBashSnippet(
        script:
            '''
source ${jsonEncode(libraryPath)}
fetch_redirect_headers() { return 1; }
fetch_text() { cat ${jsonEncode(releasesPath)}; }
resolve_release sesori-bridge-macos-arm64.tar.gz
printf '%s\n%s\n%s\n' "\$RESOLVED_VERSION" "\$RESOLVED_ARCHIVE_URL" "\$RESOLVED_CHECKSUMS_URL"
''',
        environment: {
          'PATH': Platform.environment['PATH'] ?? '',
          'HOME': tempDir.path,
        },
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      expect(
        (result.stdout as String).trim(),
        equals(
          [
            '0.4.0',
            'https://github.com/sesori-ai/sesori_apps_monorepo/releases/download/v0.4.0/sesori-bridge-macos-arm64.tar.gz',
            'https://github.com/sesori-ai/sesori_apps_monorepo/releases/download/v0.4.0/checksums.txt',
          ].join('\n'),
        ),
      );
    });

    test('paginates the fallback scan until a later page contains the highest eligible stable release', () async {
      final libraryPath = await _createInstallShLibrary();
      final tempDir = await Directory.systemTemp.createTemp('install-sh-pagination-');
      addTearDown(() => tempDir.delete(recursive: true));
      final pageOnePath = p.join(tempDir.path, 'page-1.json');
      final pageTwoPath = p.join(tempDir.path, 'page-2.json');
      // A full page (per_page=30) forces the scan to fetch a second page.
      await File(pageOnePath).writeAsString(
        jsonEncode(
          List.generate(30, (index) {
            final version = '0.3.${index + 1}';
            return {
              'tag_name': 'v$version',
              'draft': false,
              'prerelease': false,
              'assets': [
                {'name': 'sesori-bridge-macos-arm64.tar.gz'},
                {'name': 'checksums.txt'},
              ],
            };
          }),
        ),
      );
      await File(pageTwoPath).writeAsString(
        jsonEncode([
          {
            'tag_name': 'v0.4.0',
            'draft': false,
            'prerelease': false,
            'assets': [
              {'name': 'sesori-bridge-macos-arm64.tar.gz'},
              {'name': 'checksums.txt'},
            ],
          },
        ]),
      );

      final result = await _runBashSnippet(
        script:
            '''
source ${jsonEncode(libraryPath)}
fetch_redirect_headers() { return 1; }
fetch_text() {
  case "\$1" in
    *page=1) cat ${jsonEncode(pageOnePath)} ;;
    *page=2) cat ${jsonEncode(pageTwoPath)} ;;
    *) printf '[]' ;;
  esac
}
resolve_release sesori-bridge-macos-arm64.tar.gz
printf '%s\n' "\$RESOLVED_VERSION"
''',
        environment: {
          'PATH': Platform.environment['PATH'] ?? '',
          'HOME': tempDir.path,
        },
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      expect((result.stdout as String).trim(), equals('0.4.0'));
    });

    test('resolves a >128KB release page through the fallback without an argument-length failure', () async {
      final libraryPath = await _createInstallShLibrary();
      final tempDir = await Directory.systemTemp.createTemp('install-sh-bigpage-');
      addTearDown(() => tempDir.delete(recursive: true));
      final releasesPath = p.join(tempDir.path, 'releases.json');
      // A single release whose body alone exceeds Linux MAX_ARG_STRLEN (128KB).
      // The previous implementation passed this JSON through an env var and
      // failed with "Argument list too long"; reading from a file must not.
      await File(releasesPath).writeAsString(
        jsonEncode([
          {
            'tag_name': 'v0.9.9',
            'draft': false,
            'prerelease': false,
            'body': 'x' * 200000,
            'assets': [
              {'name': 'sesori-bridge-linux-x64.tar.gz'},
              {'name': 'checksums.txt'},
            ],
          },
        ]),
      );
      expect(await File(releasesPath).length(), greaterThan(131072));

      final result = await _runBashSnippet(
        script:
            '''
source ${jsonEncode(libraryPath)}
fetch_redirect_headers() { return 1; }
fetch_text() { cat ${jsonEncode(releasesPath)}; }
resolve_release sesori-bridge-linux-x64.tar.gz
printf '%s\n' "\$RESOLVED_VERSION"
''',
        environment: {
          'PATH': Platform.environment['PATH'] ?? '',
          'HOME': tempDir.path,
        },
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      expect((result.stdout as String).trim(), equals('0.9.9'));
    });

    test('verifies checksum manifests by asset basename', () async {
      final libraryPath = await _createInstallShLibrary();
      final tempDir = await Directory.systemTemp.createTemp('install-sh-checksum-');
      addTearDown(() => tempDir.delete(recursive: true));

      final archivePath = p.join(tempDir.path, 'downloaded-archive.tar.gz');
      const filename = 'sesori-bridge-macos-arm64.tar.gz';
      await File(archivePath).writeAsString('archive payload');
      final digestResult = await Process.run('shasum', ['-a', '256', archivePath]);
      expect(digestResult.exitCode, equals(0), reason: '${digestResult.stdout}\n${digestResult.stderr}');
      final digest = (digestResult.stdout as String).split(' ').first;
      final checksumsPath = p.join(tempDir.path, 'checksums.txt');
      await File(checksumsPath).writeAsString('$digest  *$filename\n');

      final result = await _runBashSnippet(
        script:
            'source ${jsonEncode(libraryPath)}; verify_checksum ${jsonEncode(archivePath)} ${jsonEncode(checksumsPath)} ${jsonEncode(filename)} macos',
        environment: {
          'PATH': Platform.environment['PATH'] ?? '',
          'HOME': tempDir.path,
        },
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
    });

    test('warns when another sesori-bridge shadows the managed install', () async {
      final libraryPath = await _createInstallShLibrary();
      final tempDir = await Directory.systemTemp.createTemp('install-sh-conflict-');
      addTearDown(() => tempDir.delete(recursive: true));
      final binDir = await Directory(p.join(tempDir.path, 'bin')).create();
      final shadowPath = await _createExecutable(
        binDir: binDir,
        name: 'sesori-bridge',
        body: '#!/bin/sh\nexit 0\n',
      );

      final result = await _runBashSnippet(
        script: 'source ${jsonEncode(libraryPath)}; check_conflicts',
        environment: {
          'PATH': '${binDir.path}:${Platform.environment['PATH'] ?? ''}',
          'HOME': tempDir.path,
        },
      );

      expect(result.exitCode, equals(0));
      expect(result.stderr, contains('Warning: another sesori-bridge found at $shadowPath'));
      expect(result.stderr, contains('It may shadow the newly installed version.'));
    });

    test('adds the managed bin directory to zsh PATH only once', () async {
      final libraryPath = await _createInstallShLibrary();
      final tempDir = await Directory.systemTemp.createTemp('install-sh-path-');
      addTearDown(() => tempDir.delete(recursive: true));

      final result = await _runBashSnippet(
        script:
            '''
source ${jsonEncode(libraryPath)}
add_to_path "\$HOME/.local/bin"
add_to_path "\$HOME/.local/bin"
cat "\$HOME/.zshrc"
cat "\$HOME/.zprofile"
''',
        environment: {
          'PATH': '/usr/bin:/bin',
          'HOME': tempDir.path,
          'SHELL': '/bin/zsh',
        },
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      expect(
        RegExp(r'export PATH="\$HOME/.local/bin:\$PATH"').allMatches(result.stdout as String).length,
        equals(2),
      );
      expect(
        result.stdout,
        contains(
          "PATH: persisted ~/.local/bin in ${p.join(tempDir.path, '.zshrc')} and ${p.join(tempDir.path, '.zprofile')}. Run 'source ${p.join(tempDir.path, '.zshrc')}' or open a new terminal.",
        ),
      );
    });

    test('writes managed runtime manifest with the resolved version', () {
      final script = File(_installShPath()).readAsStringSync();

      expect(script, contains(r'MANAGED_MANIFEST="${INSTALL_DIR}/.managed-runtime.json"'));
      expect(script, contains(r'local resolved_version="${RESOLVED_VERSION}"'));
      expect(script, contains(r'"${BINARY}" --version'));
      expect(script, contains('printf'));
      expect(script, contains('"%s"'));
      expect(script, contains(r'"${resolved_version}" > "${MANAGED_MANIFEST}"'));
    });

    test('the fallback scan accepts only stable v release tags', () {
      final script = File(_installShPath()).readAsStringSync();

      expect(script, contains('if tag_name.startswith("v"):'));
      expect(script, contains('version = tag_name.replace("v", "", 1)'));
      expect(script, isNot(contains('bridge-v')));
    });

    test('never passes release JSON through argv/env and uses static latest/download', () {
      final script = File(_installShPath()).readAsStringSync();

      // The original "Argument list too long" failure came from passing the
      // release JSON to python3 via RELEASES_JSON/PAGE_JSON environment vars.
      expect(script, isNot(contains('RELEASES_JSON=')));
      expect(script, isNot(contains('PAGE_JSON=')));
      // Primary path is GitHub's native always-latest static download.
      expect(script, contains(r'releases/latest/download/${filename}'));
      // The fallback scan streams each page to a file (paths-as-args only).
      expect(script, contains(r'> "${page_file}"'));
    });
  });

  group('install.ps1 contract', () {
    late String script;

    setUp(() async {
      script = await File(_installPs1Path()).readAsString();
    });

    test('supports x64 and arm64 architecture detection paths', () {
      expect(script, contains('function Resolve-OsArchitecture'));
      expect(script, contains(r'$env:PROCESSOR_ARCHITEW6432'));
      expect(script, contains('Get-CimInstance Win32_OperatingSystem'));
      expect(script, contains(r"'64-bit' { $arch = 'x64' }"));
      expect(script, contains(r"'X64'    { $arch = 'x64' }"));
      expect(script, contains(r"'AMD64'  { $arch = 'x64' }"));
      expect(script, contains(r"'ARM64'  { $arch = 'arm64' }"));
      expect(script, contains(r"'ARM 64-bit Processor' { $arch = 'arm64' }"));
      expect(script, contains(r"Unsupported architecture '$detectedOsArchitecture'"));
      expect(script, contains('Only x64 (AMD64) and arm64 are supported on Windows.'));
      expect(script, contains(r'sesori-bridge-windows-$arch.zip'));
      expect(script, contains(r"if ($arch -notin @('x64', 'arm64'))"));
      expect(script, contains('falling back to the x64 build'));
    });

    test('resolves via latest/download with a retained scan fallback', () {
      // Coordinator dispatches to two peer resolvers.
      expect(script, contains('function Resolve-BridgeRelease {'));
      expect(script, contains('function Resolve-BridgeReleaseViaLatest {'));
      expect(script, contains('function Resolve-BridgeReleaseViaScan {'));

      // Primary: GitHub-native always-latest static asset; version from redirect.
      expect(script, contains(r'releases/latest/download/$ArchiveName'));
      expect(script, contains('Get-RedirectLocation'));
      expect(script, contains(r'releases/download/(v[0-9]+\.[0-9]+\.[0-9]+)/'));
      expect(script, contains('Test-RemoteAssetExists'));

      // Fallback scan retained: pagination + client-side filtering + version sort.
      expect(script, contains(r"$tagName.StartsWith('v')"));
      expect(script, contains(r'''$release.draft -or $release.prerelease'''));
      expect(script, contains(r'[version]::TryParse($versionText, [ref]$parsedVersion)'));
      expect(script, contains(r'$page -le $ReleasesMaxPages'));
      expect(script, contains(r'"${ReleasesApiUrl}?per_page=$ReleasesPerPage&page=$page"'));
      expect(script, contains('Sort-Object Version -Descending'));
      expect(script, contains(r'''Where-Object { $_.name -eq $ArchiveName }'''));
      expect(script, contains(r'''Where-Object { $_.name -eq 'checksums.txt' }'''));

      // Checksum entries are still matched by asset basename (unchanged).
      expect(script, contains(r'''if ($line -match '^([a-fA-F0-9]{64})\s+\*?(.+)$')'''));
      expect(script, contains(r'''if ($filePart -eq $ArchiveName) {'''));
    });

    test('warns about PATH conflicts and only appends the managed bin dir once', () {
      expect(script, contains("Get-Command 'sesori-bridge' -ErrorAction SilentlyContinue"));
      expect(script, contains("Write-Warning \"Another sesori-bridge was found at '"));
      expect(script, contains(r'''$pathEntries | Where-Object { $_.TrimEnd('\') -ieq $BinDir.TrimEnd('\') }'''));
      expect(script, contains(r"[Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')"));
      expect(script, contains(r'PATH: persisted $BinDir in the user PATH.'));
      expect(script, contains('Write-Host "Start the bridge:"'));
      expect(script, contains('Write-Host "   sesori-bridge"'));
      expect(script, contains('Write-Host "1. Open a new terminal"'));
      expect(script, contains('Write-Host "2. Run the bridge:"'));
    });

    test('writes managed runtime manifest with resolved version', () {
      expect(script, contains(r"$ManagedManifest = Join-Path $InstallRoot '.managed-runtime.json'"));
      expect(script, contains(r'$resolvedVersion = $Release.TagName'));
      expect(script, contains(r"if ($resolvedVersion.StartsWith('v'))"));
      expect(script, contains(r'$resolvedVersion = $resolvedVersion.Substring(1)'));
      expect(script, contains(r'$managedManifestJson = @{ version = $resolvedVersion } | ConvertTo-Json -Compress'));
      expect(script, contains('[System.IO.File]::WriteAllText('));
      expect(script, contains(r'[System.Text.UTF8Encoding]::new($false)'));
    });

    test('accepts only v release tags', () {
      expect(script, contains(r"if ($tagName.StartsWith('v')) {"));
      expect(script, contains(r'$versionText = $tagName.Substring(1)'));
      expect(script, isNot(contains('bridge-v')));
    });
  });
}
