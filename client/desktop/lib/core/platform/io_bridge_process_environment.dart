import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// Result of the bounded process used to inspect the login-shell environment.
///
/// [environment] is null when the shell's environment exceeded the capture
/// limit and was discarded.
@visibleForTesting
class const LaunchEnvironmentProcessResult({
  required final int exitCode,
  required final Map<String, String>? environment,
  required final String stderr,
});

@visibleForTesting
typedef LaunchEnvironmentProcessRunner = Future<LaunchEnvironmentProcessResult> Function({
  required String executable,
  required List<String> arguments,
  required Map<String, String>? environment,
  required Duration timeout,
});

/// Supplies the environment used when the desktop starts its supervised
/// helper.
///
/// A macOS LaunchAgent receives a small launchd environment rather than the
/// user's interactive shell environment, so harness configuration exported
/// from a shell profile (user-installed harnesses on PATH, gateway base URLs,
/// auth tokens, proxies) would otherwise be missing. Like VS Code, we run the
/// user's login shell once per bridge start and import its full environment,
/// so the supervised bridge sees what a terminal-started bridge sees. This
/// deliberately includes credential-bearing variables: the bridge and its
/// harnesses need them, and they come from the user's own shell profile.
///
/// The imported values stay in memory and reach only the bridge process
/// boundary; they are never persisted or logged (variable names may be logged
/// at debug level). Shell values override inherited ones, except
/// [_excludedShellVariables]. PATH merges the shell entries ahead of the
/// inherited ones. Any probe failure, timeout or oversized output imports
/// nothing, so the bridge inherits the app's environment unchanged.
@LazySingleton(as: BridgeProcessEnvironment)
class IoBridgeProcessEnvironment.forTesting({
  required final bool _isMacOS,
  required final Map<String, String> _baseEnvironment,
  required final LaunchEnvironmentProcessRunner _runProcess,
  required final Duration _shellTimeout,
}) implements BridgeProcessEnvironment {
  new()
    : this.forTesting(
        isMacOS: Platform.isMacOS,
        baseEnvironment: Platform.environment,
        runProcess: _runLoginShell,
        shellTimeout: const Duration(seconds: 5),
      );

  @visibleForTesting
  this;

  Future<Map<String, String>?>? _resolutionInFlight;

  @override
  Future<Map<String, String>> resolve() async {
    final Future<Map<String, String>?> resolution = _resolutionInFlight ??= _resolve();
    try {
      final Map<String, String>? resolved = await resolution;
      return resolved ?? const <String, String>{};
    } finally {
      if (identical(_resolutionInFlight, resolution)) {
        _resolutionInFlight = null;
      }
    }
  }

  Future<Map<String, String>?> _resolve() async {
    if (!_isMacOS) {
      return const <String, String>{};
    }
    final Map<String, String>? shellEnvironment = await _readLoginShellEnvironment();
    if (shellEnvironment == null) {
      // A failed probe must not rewrite the inherited environment based on guesses.
      return null;
    }
    final String? shellPath = shellEnvironment["PATH"];
    final Iterable<String> shellEntries = shellPath == null ? const <String>[] : _absolutePathEntries(value: shellPath);
    if (shellEntries.isEmpty) {
      logw("The macOS login shell returned no usable absolute PATH entries; preserving the inherited environment");
      return null;
    }
    final Map<String, String> imported = <String, String>{
      for (final MapEntry<String, String>(:String key, :String value) in shellEnvironment.entries)
        if (!_excludedShellVariables.contains(key)) key: value,
      "PATH": _mergePath(shellEntries: shellEntries, basePath: _baseEnvironment["PATH"]),
    };
    // Names only: values can hold credentials.
    logd(
      "Imported ${imported.length} variables from the macOS login shell: "
      "${(imported.keys.toList()..sort()).join(", ")}",
    );
    return Map<String, String>.unmodifiable(imported);
  }

  /// Shell variables never imported, so the inherited value (if any) is kept.
  ///
  /// `PWD`, `OLDPWD`, `SHLVL` and `_` describe the probe shell itself rather
  /// than the user's configuration. `AUTH_BACKEND_URL` redirects the bridge's
  /// auth backend; the app hands its own session to its bridge, so the app,
  /// not a shell export meant for a terminal bridge, decides that backend.
  static const Set<String> _excludedShellVariables = <String>{
    "PWD",
    "OLDPWD",
    "SHLVL",
    "_",
    "AUTH_BACKEND_URL",
  };

  Future<Map<String, String>?> _readLoginShellEnvironment() async {
    final String shell = _shellExecutable(environment: _baseEnvironment);
    final LaunchEnvironmentProcessResult result;
    try {
      result = await _runProcess(
        executable: shell,
        arguments: const <String>["-ilc", r"/usr/bin/printf '\000'; /usr/bin/env -0"],
        environment: null,
        timeout: _shellTimeout,
      );
    } on Object catch (error, stackTrace) {
      logw(
        "Failed to resolve the macOS login-shell environment; preserving the inherited environment",
        error,
        stackTrace,
      );
      return null;
    }
    if (result.exitCode != 0) {
      logw(
        "The macOS login shell exited with code ${result.exitCode}; preserving the inherited environment"
        "${_stderrDetails(stderr: result.stderr)}",
      );
      return null;
    }

    final Map<String, String>? shellEnvironment = result.environment;
    if (shellEnvironment == null) {
      logw(
        "The macOS login-shell environment exceeded $_maxCapturedShellEnvironmentBytes bytes; "
        "preserving the inherited environment",
      );
      return null;
    }
    return shellEnvironment;
  }

  /// Parses the `printf '\0'; env -0` output without retaining more than
  /// [_maxCapturedShellEnvironmentBytes] of records. Bytes before the first
  /// NUL are output from interactive startup files and an unterminated
  /// trailing fragment is logout-file output; both are drained, not buffered
  /// or parsed. Returns null when the environment exceeds the cap.
  @visibleForTesting
  static Future<Map<String, String>?> parseEnvironmentStream({required Stream<List<int>> stream}) =>
      _readEnvironmentStream(stream: stream);

  static Future<Map<String, String>?> _readEnvironmentStream({required Stream<List<int>> stream}) async {
    final Map<String, String> environment = <String, String>{};
    final List<int> recordBytes = <int>[];
    bool markerSeen = false;
    bool oversized = false;
    int capturedBytes = 0;

    void addRecord() {
      final String record = utf8.decode(recordBytes, allowMalformed: true);
      recordBytes.clear();
      final int separator = record.indexOf("=");
      if (separator > 0) {
        environment[record.substring(0, separator)] = record.substring(separator + 1);
      }
    }

    await for (final List<int> chunk in stream) {
      // Keep draining after an overflow so the shell is not blocked on a full pipe.
      if (oversized) continue;
      for (final int byte in chunk) {
        if (!markerSeen) {
          markerSeen = byte == 0;
        } else if (byte == 0) {
          addRecord();
        } else if (++capturedBytes > _maxCapturedShellEnvironmentBytes) {
          oversized = true;
          break;
        } else {
          recordBytes.add(byte);
        }
      }
    }
    if (oversized) {
      return null;
    }
    return environment;
  }

  static String _stderrDetails({required String stderr}) {
    final String value = stderr.trim();
    if (value.isEmpty) return "";
    final String bounded = value.length <= _maxLoggedShellStderrCharacters
        ? value
        : "…${value.substring(value.length - _maxLoggedShellStderrCharacters)}";
    return "; stderr: $bounded";
  }

  static const int _maxLoggedShellStderrCharacters = 4 * 1024;

  static String _shellExecutable({required Map<String, String> environment}) {
    final String? configured = environment["SHELL"]?.trim();
    if (configured != null && _isExecutableFile(path: configured)) {
      return configured;
    }
    return "/bin/zsh";
  }

  // POSIX owner/group/other execute bits (octal 0111).
  static const int _posixExecuteBits = 0x49;

  static bool _isExecutableFile({required String path}) {
    if (!path.startsWith("/") || path.contains("\u0000") || path.contains("\n") || path.contains("\r")) {
      return false;
    }
    try {
      final FileStat stat = FileStat.statSync(path);
      return stat.type == FileSystemEntityType.file && (stat.mode & _posixExecuteBits) != 0;
    } on Object catch (error, stackTrace) {
      logw("Failed to inspect the configured macOS login shell; using /bin/zsh", error, stackTrace);
      return false;
    }
  }

  static const int _maxCapturedShellOutputBytes = 64 * 1024;
  static const int _maxCapturedShellEnvironmentBytes = 64 * 1024;

  static Future<LaunchEnvironmentProcessResult> _runLoginShell({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required Duration timeout,
  }) async {
    final Process process = await Process.start(
      executable,
      arguments,
      environment: environment,
      runInShell: false,
      mode: ProcessStartMode.normal,
    );
    try {
      final (int exitCode, Map<String, String>? environment, String stderr) = await (
        process.exitCode,
        _readEnvironmentStream(stream: process.stdout),
        _readOutputTail(stream: process.stderr),
      ).wait.timeout(timeout);
      return LaunchEnvironmentProcessResult(exitCode: exitCode, environment: environment, stderr: stderr);
    } on Object {
      process.kill(ProcessSignal.sigkill);
      rethrow;
    }
  }

  static Future<String> _readOutputTail({required Stream<List<int>> stream}) async {
    final List<int> bytes = <int>[];
    await for (final List<int> chunk in stream) {
      bytes.addAll(chunk);
      if (bytes.length > _maxCapturedShellOutputBytes) {
        bytes.removeRange(0, bytes.length - _maxCapturedShellOutputBytes);
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static String _mergePath({
    required Iterable<String> shellEntries,
    required String? basePath,
  }) {
    final List<String> candidates = <String>[
      ...shellEntries,
      if (basePath != null) ..._absolutePathEntries(value: basePath),
    ];
    final Set<String> seen = <String>{};
    return candidates.where(seen.add).join(":");
  }

  static Iterable<String> _absolutePathEntries({required String value}) sync* {
    for (final String rawEntry in value.split(":")) {
      final String entry = rawEntry.trim();
      if (entry.isEmpty ||
          !entry.startsWith("/") ||
          entry.contains("\u0000") ||
          entry.contains("\n") ||
          entry.contains("\r")) {
        continue;
      }
      yield entry;
    }
  }
}
