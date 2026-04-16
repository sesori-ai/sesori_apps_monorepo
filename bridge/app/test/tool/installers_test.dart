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

    test('resolves the newest stable bridge release with matching asset and checksums', () async {
      final libraryPath = await _createInstallShLibrary();
      final tempDir = await Directory.systemTemp.createTemp('install-sh-release-');
      addTearDown(() => tempDir.delete(recursive: true));
      final releasesPath = p.join(tempDir.path, 'releases.json');
      await File(releasesPath).writeAsString(
        jsonEncode([
          {
            'tag_name': 'repo-v9.9.9',
            'draft': false,
            'prerelease': false,
            'assets': [
              {
                'name': 'sesori-bridge-macos-arm64.tar.gz',
                'browser_download_url': 'https://example.com/repo-v9.9.9/sesori-bridge-macos-arm64.tar.gz',
              },
              {
                'name': 'checksums.txt',
                'browser_download_url': 'https://example.com/repo-v9.9.9/checksums.txt',
              },
            ],
          },
          {
            'tag_name': 'bridge-v0.4.0-beta.1',
            'draft': false,
            'prerelease': true,
            'assets': [
              {
                'name': 'sesori-bridge-macos-arm64.tar.gz',
                'browser_download_url': 'https://example.com/bridge-v0.4.0-beta.1/sesori-bridge-macos-arm64.tar.gz',
              },
              {
                'name': 'checksums.txt',
                'browser_download_url': 'https://example.com/bridge-v0.4.0-beta.1/checksums.txt',
              },
            ],
          },
          {
            'tag_name': 'bridge-v0.3.1',
            'draft': false,
            'prerelease': false,
            'assets': [
              {
                'name': 'sesori-bridge-macos-arm64.tar.gz',
                'browser_download_url': 'https://example.com/bridge-v0.3.1/sesori-bridge-macos-arm64.tar.gz',
              },
              {
                'name': 'checksums.txt',
                'browser_download_url': 'https://example.com/bridge-v0.3.1/checksums.txt',
              },
            ],
          },
          {
            'tag_name': 'bridge-v0.4.0',
            'draft': false,
            'prerelease': false,
            'assets': [
              {
                'name': 'sesori-bridge-macos-arm64.tar.gz',
                'browser_download_url': 'https://example.com/bridge-v0.4.0/sesori-bridge-macos-arm64.tar.gz',
              },
              {
                'name': 'checksums.txt',
                'browser_download_url': 'https://example.com/bridge-v0.4.0/checksums.txt',
              },
            ],
          },
        ]),
      );

      final result = await _runBashSnippet(
        script:
            '''
source ${jsonEncode(libraryPath)}
fetch_text() { cat ${jsonEncode(releasesPath)}; }
resolve_release_contract sesori-bridge-macos-arm64.tar.gz
printf '%s\n%s\n%s\n' "\$RESOLVED_RELEASE_TAG" "\$RESOLVED_ARCHIVE_URL" "\$RESOLVED_CHECKSUMS_URL"
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
            'bridge-v0.4.0',
            'https://example.com/bridge-v0.4.0/sesori-bridge-macos-arm64.tar.gz',
            'https://example.com/bridge-v0.4.0/checksums.txt',
          ].join('\n'),
        ),
      );
    });

    test('paginates release resolution until a later page contains the highest eligible stable release', () async {
      final libraryPath = await _createInstallShLibrary();
      final tempDir = await Directory.systemTemp.createTemp('install-sh-pagination-');
      addTearDown(() => tempDir.delete(recursive: true));
      final pageOnePath = p.join(tempDir.path, 'page-1.json');
      final pageTwoPath = p.join(tempDir.path, 'page-2.json');
      await File(pageOnePath).writeAsString(
        jsonEncode(
          List.generate(100, (index) {
            final version = '0.3.${index + 1}';
            return {
              'tag_name': 'bridge-v$version',
              'draft': false,
              'prerelease': false,
              'assets': [
                {
                  'name': 'sesori-bridge-linux-x64.tar.gz',
                  'browser_download_url': 'https://example.com/bridge-v$version/sesori-bridge-linux-x64.tar.gz',
                },
                {
                  'name': 'checksums.txt',
                  'browser_download_url': 'https://example.com/bridge-v$version/checksums.txt',
                },
              ],
            };
          }),
        ),
      );
      await File(pageTwoPath).writeAsString(
        jsonEncode([
          {
            'tag_name': 'bridge-v0.4.0',
            'draft': false,
            'prerelease': false,
            'assets': [
              {
                'name': 'sesori-bridge-macos-arm64.tar.gz',
                'browser_download_url': 'https://example.com/bridge-v0.4.0/sesori-bridge-macos-arm64.tar.gz',
              },
              {
                'name': 'checksums.txt',
                'browser_download_url': 'https://example.com/bridge-v0.4.0/checksums.txt',
              },
            ],
          },
        ]),
      );

      final result = await _runBashSnippet(
        script:
            '''
source ${jsonEncode(libraryPath)}
fetch_text() {
  case "\$1" in
    *page=1) cat ${jsonEncode(pageOnePath)} ;;
    *page=2) cat ${jsonEncode(pageTwoPath)} ;;
    *) printf '[]' ;;
  esac
}
resolve_release_contract sesori-bridge-macos-arm64.tar.gz
printf '%s\n%s\n%s\n' "\$RESOLVED_RELEASE_TAG" "\$RESOLVED_ARCHIVE_URL" "\$RESOLVED_CHECKSUMS_URL"
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
            'bridge-v0.4.0',
            'https://example.com/bridge-v0.4.0/sesori-bridge-macos-arm64.tar.gz',
            'https://example.com/bridge-v0.4.0/checksums.txt',
          ].join('\n'),
        ),
      );
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
add_to_path "\$HOME/.sesori/bin"
add_to_path "\$HOME/.sesori/bin"
cat "\$HOME/.zshrc"
''',
        environment: {
          'PATH': '/usr/bin:/bin',
          'HOME': tempDir.path,
          'SHELL': '/bin/zsh',
        },
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      expect(
        RegExp(r'export PATH="\$HOME/.sesori/bin:\$PATH"').allMatches(result.stdout as String).length,
        equals(1),
      );
      expect(result.stdout, contains('PATH: persisted ~/.sesori/bin in ${p.join(tempDir.path, '.zshrc')}.'));
    });

    test('writes managed runtime manifest with resolved version', () {
      final script = File(_installShPath()).readAsStringSync();

      expect(script, contains(r'MANAGED_MANIFEST="${INSTALL_DIR}/.managed-runtime.json"'));
      expect(script, contains(r'"${RESOLVED_RELEASE_TAG#bridge-v}" > "${MANAGED_MANIFEST}"'));
    });
  });

  group('install.ps1 contract', () {
    late String script;

    setUp(() async {
      script = await File(_installPs1Path()).readAsString();
    });

    test('limits Windows installs to x64 architecture detection paths', () {
      expect(script, contains('function Resolve-OsArchitecture'));
      expect(script, contains(r'$env:PROCESSOR_ARCHITEW6432'));
      expect(script, contains('Get-CimInstance Win32_OperatingSystem'));
      expect(script, contains(r"'64-bit' { $arch = 'x64' }"));
      expect(script, contains(r"'X64'    { $arch = 'x64' }"));
      expect(script, contains(r"'AMD64'  { $arch = 'x64' }"));
      expect(script, contains(r"Unsupported architecture '$detectedOsArchitecture'"));
      expect(script, contains('Only x64 (AMD64) is supported on Windows.'));
      expect(script, contains(r'sesori-bridge-windows-$arch.zip'));
    });

    test('resolves stable bridge-tagged release assets and checksum basenames', () {
      expect(script, contains(r"$tagName.StartsWith('bridge-v')"));
      expect(script, contains(r'''$release.draft -or $release.prerelease'''));
      expect(script, contains(r'[version]::TryParse($versionText, [ref]$parsedVersion)'));
      expect(script, contains(r'$page -le $ReleasesMaxPages'));
      expect(script, contains(r'"$ReleasesApiUrl?per_page=$ReleasesPerPage&page=$page"'));
      expect(script, contains('Sort-Object Version -Descending'));
      expect(script, contains(r'''Where-Object { $_.name -eq $ArchiveName }'''));
      expect(script, contains(r'''Where-Object { $_.name -eq 'checksums.txt' }'''));
      expect(script, contains(r'''if ($line -match '^([a-fA-F0-9]{64})\s+\*?(.+)$')'''));
      expect(script, contains(r'''if ($filePart -eq $ArchiveName) {'''));
    });

    test('warns about PATH conflicts and only appends the managed bin dir once', () {
      expect(script, contains("Get-Command 'sesori-bridge' -ErrorAction SilentlyContinue"));
      expect(script, contains("Write-Warning \"Another sesori-bridge was found at '"));
      expect(script, contains(r'''$pathEntries | Where-Object { $_.TrimEnd('\') -ieq $BinDir.TrimEnd('\') }'''));
      expect(script, contains(r"[Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')"));
      expect(script, contains(r'PATH: persisted $BinDir in the user PATH.'));
      expect(script, contains('Write-Host "sesori-bridge"'));
      expect(script, contains(r'Write-Host "& \"$BinaryPath\""'));
    });

    test('writes managed runtime manifest with resolved version', () {
      expect(script, contains(r"$ManagedManifest = Join-Path $InstallRoot '.managed-runtime.json'"));
      expect(
        script,
        contains(r'$managedManifestJson = @{ version = $Release.TagName.Substring(8) } | ConvertTo-Json -Compress'),
      );
      expect(script, contains('[System.IO.File]::WriteAllText('));
      expect(script, contains(r'[System.Text.UTF8Encoding]::new($false)'));
    });
  });
}
