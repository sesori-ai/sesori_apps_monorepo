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
# Both the archive probe and the checksums probe go through fetch_redirect_headers;
# a 2xx status line is required so the resolver accepts the latest release.
fetch_redirect_headers() {
  printf '%s\n' 'HTTP/2 200' 'location: https://github.com/sesori-ai/sesori_apps_monorepo/releases/download/v4.5.6/sesori-bridge-macos-arm64.tar.gz'
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

    test('falls back to a scan when the latest release is missing checksums.txt', () async {
      final libraryPath = await _createInstallShLibrary();
      final tempDir = await Directory.systemTemp.createTemp('install-sh-partial-');
      addTearDown(() => tempDir.delete(recursive: true));
      final releasesPath = p.join(tempDir.path, 'releases.json');
      await File(releasesPath).writeAsString(
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

      // Latest has the archive (200) but checksums.txt is still missing (404),
      // e.g. a partial publish window. The resolver must reject it and scan.
      final result = await _runBashSnippet(
        script:
            '''
source ${jsonEncode(libraryPath)}
fetch_redirect_headers() {
  case "\$1" in
    *checksums.txt) printf '%s\n' 'HTTP/2 404' ;;
    *) printf '%s\n' 'HTTP/2 200' 'location: https://github.com/sesori-ai/sesori_apps_monorepo/releases/download/v9.9.9/sesori-bridge-macos-arm64.tar.gz' ;;
  esac
}
fetch_text() { cat ${jsonEncode(releasesPath)}; }
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

    test('falls back when a stale curl returns exit 0 for a 404 archive HEAD', () async {
      final libraryPath = await _createInstallShLibrary();
      final tempDir = await Directory.systemTemp.createTemp('install-sh-oldcurl-');
      addTearDown(() => tempDir.delete(recursive: true));
      final releasesPath = p.join(tempDir.path, 'releases.json');
      await File(releasesPath).writeAsString(
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

      // Simulate old curl: exit 0 even though the final hop is 404 (only 3xx +
      // 4xx, no 2xx). The version is still parseable from the redirect, so the
      // 2xx guard is what prevents wrongly accepting the missing asset.
      final result = await _runBashSnippet(
        script:
            '''
source ${jsonEncode(libraryPath)}
fetch_redirect_headers() {
  printf '%s\n' 'HTTP/2 302' 'location: https://github.com/sesori-ai/sesori_apps_monorepo/releases/download/v9.9.9/sesori-bridge-macos-arm64.tar.gz' 'HTTP/2 404'
}
fetch_text() { cat ${jsonEncode(releasesPath)}; }
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

    test('treats only the final HTTP status as success, ignoring an intermediate proxy 200', () async {
      final libraryPath = await _createInstallShLibrary();
      final tempDir = await Directory.systemTemp.createTemp('install-sh-proxy-');
      addTearDown(() => tempDir.delete(recursive: true));
      final releasesPath = p.join(tempDir.path, 'releases.json');
      await File(releasesPath).writeAsString(
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

      // An HTTP proxy emits "200 Connection established" before the real
      // response. The final status is 404, so the asset must be treated as
      // missing (matching any 2xx line would wrongly accept it).
      final result = await _runBashSnippet(
        script:
            '''
source ${jsonEncode(libraryPath)}
fetch_redirect_headers() {
  printf '%s\n' 'HTTP/1.1 200 Connection established' 'location: https://github.com/sesori-ai/sesori_apps_monorepo/releases/download/v9.9.9/sesori-bridge-macos-arm64.tar.gz' 'HTTP/2 404'
}
fetch_text() { cat ${jsonEncode(releasesPath)}; }
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
      // Styled warning/note prefixes vary (glyph/color depend on the terminal);
      // assert on the stable message text only.
      expect(result.stderr, contains('Another sesori-bridge was found at $shadowPath'));
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
      // Styled confirmation: the rc files are named in the "Added ... to your
      // PATH" line, with the source hint on the following note line.
      expect(
        result.stdout,
        contains(
          'Added ~/.local/bin to your PATH in ${p.join(tempDir.path, '.zshrc')} and ${p.join(tempDir.path, '.zprofile')}',
        ),
      );
      expect(
        result.stdout,
        contains("Run 'source ${p.join(tempDir.path, '.zshrc')}' or open a new terminal to use it."),
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

    test('emits ANSI color and the SESORI banner when FORCE_COLOR is set', () async {
      final libraryPath = await _createInstallShLibrary();

      final result = await _runBashSnippet(
        script: 'source ${jsonEncode(libraryPath)}; init_style; print_banner; step 1 "Downloading release"; ok "done"',
        environment: {
          'PATH': Platform.environment['PATH'] ?? '',
          'FORCE_COLOR': '1',
          'LANG': 'en_US.UTF-8',
        },
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      final out = result.stdout as String;
      // Brand-blue step counter + green check escapes are present.
      expect(out, contains('\u001b[38;5;39m[1/4]'));
      expect(out, contains('\u001b[38;5;42m'));
      // The tagline accompanies the banner.
      expect(out, contains('Installing the Sesori Bridge'));
      // Unicode glyph + wordmark block char in a UTF-8 locale.
      expect(out, contains('\u2713'));
      expect(out, contains('\u2588'));
    });

    test('suppresses all ANSI escapes when NO_COLOR is set', () async {
      final libraryPath = await _createInstallShLibrary();

      final result = await _runBashSnippet(
        script: 'source ${jsonEncode(libraryPath)}; init_style; print_banner; step 1 "Downloading release"; ok "done"',
        environment: {
          'PATH': Platform.environment['PATH'] ?? '',
          'NO_COLOR': '1',
          'LANG': 'en_US.UTF-8',
        },
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      final out = result.stdout as String;
      // No escape sequences at all.
      expect(out, isNot(contains('\u001b[')));
      // Copy still present, just unstyled.
      expect(out, contains('[1/4] Downloading release'));
      expect(out, contains('Installing the Sesori Bridge'));
    });

    test('falls back to ASCII glyphs in a non-UTF-8 locale', () async {
      final libraryPath = await _createInstallShLibrary();

      final result = await _runBashSnippet(
        script: 'source ${jsonEncode(libraryPath)}; init_style; print_banner; ok "done"',
        environment: {
          'PATH': Platform.environment['PATH'] ?? '',
          'FORCE_COLOR': '1',
          'LANG': 'C',
          'LC_ALL': 'C',
        },
      );

      expect(result.exitCode, equals(0), reason: '${result.stdout}\n${result.stderr}');
      final out = result.stdout as String;
      // ASCII success marker instead of the ✓ glyph.
      expect(out, contains('[OK]'));
      expect(out, isNot(contains('\u2713')));
      // ASCII wordmark instead of block-char Unicode.
      expect(out, isNot(contains('\u2588')));
      expect(out, contains('____'));
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
      expect(script, contains('releases/latest/download'));
      expect(script, contains(r'${latest_base}/${filename}'));
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
      // Conflict is surfaced via the styled warning helper.
      expect(script, contains("Write-Warn \"Another sesori-bridge was found at '"));
      expect(script, contains(r'''$pathEntries | Where-Object { $_.TrimEnd('\') -ieq $BinDir.TrimEnd('\') }'''));
      expect(script, contains(r"[Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')"));
      // PATH persistence is confirmed via the styled success helper.
      expect(script, contains(r'Write-Ok "Added $BinDir to your PATH"'));
    });

    test('renders the styled banner, steps, and next-steps panel', () {
      // Banner + tagline header.
      expect(script, contains('function Write-Banner'));
      expect(script, contains('Installing the Sesori Bridge'));
      // Numbered steps use the shared [n/4] helper.
      expect(script, contains("Write-Step 1 'Downloading release'"));
      expect(script, contains("Write-Step 2 'Verifying checksum'"));
      expect(script, contains("Write-Step 3 'Installing managed runtime'"));
      expect(script, contains("Write-Step 4 'Linking command'"));
      // Completion: quiet success line + boxed "Next steps" with highlighted cmd.
      expect(script, contains(r'Sesori Bridge v$resolvedVersionLabel installed'));
      expect(script, contains("Write-PanelRow 'Next steps'"));
      expect(script, contains("Write-PanelEmphasisRow 'In a ' 'new terminal' ' window, run:'"));
      // The runnable command is kept intact: boxed when it fits, otherwise
      // printed in full below the box (never ellipsized).
      expect(script, contains(r"$nextCommand = 'sesori-bridge'"));
      expect(script, contains(r'Write-PanelCommandRow $nextCommand $nextComment'));
      expect(script, contains(r'if (-not $fitsInBox)'));
    });

    test('degrades gracefully: color/unicode detection and ASCII fallback', () {
      // Honors NO_COLOR / FORCE_COLOR / TERM=dumb / redirected output.
      expect(script, contains('function Test-ShouldUseColor'));
      expect(script, contains(r'if ($env:FORCE_COLOR)'));
      expect(script, contains(r'if ($env:NO_COLOR)'));
      expect(script, contains(r"if ($env:TERM -eq 'dumb')"));
      expect(script, contains('IsOutputRedirected'));
      // UTF-8 output + Unicode capability detection, with ASCII glyph fallback.
      expect(script, contains('function Test-ShouldUseUnicode'));
      expect(script, contains(r'[System.Text.UTF8Encoding]::new($false)'));
      expect(script, contains(r"$Script:G_CHECK = '[OK]'"));
      // Palette is centralized for easy retheming.
      expect(script, contains('PALETTE_BANNER'));
      expect(script, contains('PALETTE_BRAND'));
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
