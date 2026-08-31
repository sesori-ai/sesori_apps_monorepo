import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

@visibleForTesting
typedef LaunchEnvironmentProcessRunner = Future<ProcessResult> Function({
  required String executable,
  required List<String> arguments,
  required Map<String, String>? environment,
  required Duration timeout,
});

/// Supplies the environment used when the desktop starts its supervised
/// helper.
///
/// A macOS LaunchAgent receives a small launchd environment rather than the
/// user's interactive shell environment. In particular, user-installed
/// harnesses commonly live outside launchd's default PATH. We resolve only the
/// executable search path from a login shell and return it as the only
/// environment override; the process boundary inherits the rest of the app's
/// environment unchanged. Variables from the shell output (including any that
/// may contain credentials) are never imported or persisted.
@LazySingleton(as: BridgeProcessEnvironment)
class IoBridgeProcessEnvironment.forTesting({
  required final bool _isMacOS,
  required final Map<String, String> _baseEnvironment,
  required final LaunchEnvironmentProcessRunner _runProcess,
  required final Duration _shellTimeout,
  required final List<String> _fallbackPathDirectories,
}) implements BridgeProcessEnvironment {
  new()
    : this.forTesting(
        isMacOS: Platform.isMacOS,
        baseEnvironment: Platform.environment,
        runProcess: _runLoginShell,
        shellTimeout: const Duration(seconds: 5),
        fallbackPathDirectories: _defaultFallbackPathDirectories(
          environment: Platform.environment,
          isMacOS: Platform.isMacOS,
        ),
      );

  @visibleForTesting
  this;

  Future<Map<String, String>>? _resolution;

  @override
  Future<Map<String, String>> resolve() => _resolution ??= _resolve();

  Future<Map<String, String>> _resolve() async {
    if (!_isMacOS) {
      return const <String, String>{};
    }
    final String? shellPath = await _readLoginShellPath();
    final String mergedPath = _mergePath(
      shellPath: shellPath,
      basePath: _baseEnvironment["PATH"],
      fallbackPathDirectories: _fallbackPathDirectories,
    );
    return Map<String, String>.unmodifiable(
      mergedPath.isEmpty ? const <String, String>{} : <String, String>{"PATH": mergedPath},
    );
  }

  Future<String?> _readLoginShellPath() async {
    final String shell = _shellExecutable(environment: _baseEnvironment);
    final ProcessResult result;
    try {
      result = await _runProcess(
        executable: shell,
        arguments: const <String>["-ilc", "/usr/bin/env"],
        environment: null,
        timeout: _shellTimeout,
      );
    } on Object catch (error, stackTrace) {
      logw("Failed to resolve the macOS login-shell PATH; using fallback executable paths", error, stackTrace);
      return null;
    }
    if (result.exitCode != 0) {
      logw(
        "The macOS login shell exited with code ${result.exitCode}; using fallback executable paths"
        "${_stderrDetails(stderr: result.stderr.toString())}",
      );
      return null;
    }

    final String? shellPath = _extractPath(output: result.stdout.toString());
    if (shellPath == null) {
      logw(
        "The macOS login shell did not return a usable PATH; using fallback executable paths"
        "${_stderrDetails(stderr: result.stderr.toString())}",
      );
      return null;
    }
    return shellPath;
  }

  /// Reads the exported PATH from `env` rather than expanding `$PATH` in the
  /// shell command. Fish represents PATH as a list and expands a quoted list
  /// once per entry; `env` serializes it to the single colon-delimited value
  /// inherited by child processes for every supported shell.
  static String? _extractPath({required String output}) {
    String? shellPath;
    for (final String line in const LineSplitter().convert(output)) {
      if (line.startsWith("PATH=")) {
        shellPath = line.substring("PATH=".length);
      }
    }
    return shellPath;
  }

  static String _stderrDetails({required Object stderr}) {
    final String value = stderr.toString().trim();
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

  static Future<ProcessResult> _runLoginShell({
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
      final (int exitCode, String stdout, String stderr) = await (
        process.exitCode,
        _readOutputTail(stream: process.stdout),
        _readOutputTail(stream: process.stderr),
      ).wait.timeout(timeout);
      return ProcessResult(process.pid, exitCode, stdout, stderr);
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

  static List<String> _defaultFallbackPathDirectories({
    required Map<String, String> environment,
    required bool isMacOS,
  }) {
    if (!isMacOS) {
      return const <String>[];
    }
    final String? home = _homeDirectory(environment: environment);
    final String? configuredAsdfData = environment["ASDF_DATA_DIR"]?.trim();
    final String? asdfShims = configuredAsdfData != null && configuredAsdfData.startsWith("/")
        ? path.join(configuredAsdfData, "shims")
        : home == null
        ? null
        : path.join(home, ".asdf", "shims");
    return <String>[
      "/opt/homebrew/bin",
      "/usr/local/bin",
      if (home != null) ...<String>[
        path.join(home, ".local", "bin"),
        ...?asdfShims == null ? null : <String>[asdfShims],
        path.join(home, ".bun", "bin"),
        path.join(home, ".sesori", "bin"),
        path.join(home, ".pub-cache", "bin"),
        path.join(home, ".cargo", "bin"),
        path.join(home, ".npm-global", "bin"),
        path.join(home, ".volta", "bin"),
      ],
    ];
  }

  static String? _homeDirectory({required Map<String, String> environment}) {
    for (final String key in const <String>["HOME", "USERPROFILE"]) {
      final String? value = environment[key]?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String _mergePath({
    required String? shellPath,
    required String? basePath,
    required List<String> fallbackPathDirectories,
  }) {
    final List<String> candidates = <String>[
      if (shellPath != null) ..._absolutePathEntries(value: shellPath),
      if (basePath != null) ..._absolutePathEntries(value: basePath),
      ...fallbackPathDirectories,
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
