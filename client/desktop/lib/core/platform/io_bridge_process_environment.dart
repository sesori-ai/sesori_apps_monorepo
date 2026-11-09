import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// Variables captured from the login shell's `env -0` output.
@visibleForTesting
sealed class const LaunchShellEnvironment();

/// The whole environment fit within the capture limit.
@visibleForTesting
class const CompleteLaunchShellEnvironment({required final Map<String, String> variables})
    extends LaunchShellEnvironment;

/// The environment exceeded the capture limit, so only its PATH record (null
/// when absent or itself oversized) was kept.
@visibleForTesting
class const OversizedLaunchShellEnvironment({required final String? path}) extends LaunchShellEnvironment;

/// Result of the bounded process used to inspect the login-shell environment.
@visibleForTesting
class const LaunchEnvironmentProcessResult({
  required final int exitCode,
  required final LaunchShellEnvironment environment,
  required final String stderr,
});

@visibleForTesting
typedef LaunchEnvironmentProcessRunner = Future<LaunchEnvironmentProcessResult> Function({
  required String executable,
  required List<String> arguments,
  required Map<String, String>? environment,
  required Duration timeout,
});

/// Desktop platforms whose GUI launches miss the login-shell environment.
@visibleForTesting
enum LoginShellPlatform() {
  /// Falls back to `/bin/zsh`, the default macOS login shell.
  macOS,

  /// Falls back to the user's `/etc/passwd` shell, then `/bin/sh`.
  linux,
}

/// Supplies the environment used when the desktop starts its supervised
/// helper.
///
/// A macOS LaunchAgent receives a small launchd environment, and a Linux
/// desktop started from an application menu, a `.desktop` file or XDG
/// autostart receives the graphical session's environment. Neither includes
/// what the user exports from shell startup files such as `.zshrc` or
/// `.bashrc`, so harness configuration (user-installed harnesses on PATH,
/// gateway base URLs, auth tokens, proxies) would otherwise be missing. Like
/// VS Code, we run the user's login shell once per bridge start and import its
/// full environment, so the supervised bridge sees what a terminal-started
/// bridge sees. This deliberately includes credential-bearing variables: the
/// bridge and its harnesses need them, and they come from the user's own shell
/// profile. Windows has no such gap, so it never runs a shell.
///
/// While the probe runs, the shell sees [resolvingEnvironmentVariable] set to
/// `1`, so profiles can skip slow interactive work (the counterpart of VS
/// Code's `VSCODE_RESOLVING_ENVIRONMENT`).
///
/// The imported values stay in memory and reach only the bridge process
/// boundary; they are never persisted or logged (variable names may be logged
/// at debug level). Shell values override inherited ones, except
/// [_excludedShellVariables]. PATH merges the shell entries ahead of the
/// inherited ones. An environment larger than the capture limit imports only
/// its PATH. Any probe failure or timeout, or a missing usable PATH, imports
/// nothing, so the bridge inherits the app's environment unchanged.
@LazySingleton(as: BridgeProcessEnvironment)
class IoBridgeProcessEnvironment.forTesting({
  required final LoginShellPlatform? _platform,
  required final Map<String, String> _baseEnvironment,
  required final LaunchEnvironmentProcessRunner _runProcess,
  required final Duration _shellTimeout,
  required final String? Function() _readPasswdFile,
}) implements BridgeProcessEnvironment {
  new()
    : this.forTesting(
        platform: Platform.isMacOS
            ? LoginShellPlatform.macOS
            : Platform.isLinux
            ? LoginShellPlatform.linux
            : null,
        baseEnvironment: Platform.environment,
        runProcess: _runLoginShell,
        shellTimeout: const Duration(seconds: 5),
        readPasswdFile: _readSystemPasswdFile,
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
    final LoginShellPlatform? platform = _platform;
    if (platform == null) {
      return const <String, String>{};
    }
    final Map<String, String>? shellEnvironment = await _readLoginShellEnvironment(platform: platform);
    if (shellEnvironment == null) {
      // A failed probe must not rewrite the inherited environment based on guesses.
      return null;
    }
    final String? shellPath = shellEnvironment["PATH"];
    final Iterable<String> shellEntries = shellPath == null ? const <String>[] : _absolutePathEntries(value: shellPath);
    if (shellEntries.isEmpty) {
      logw("The login shell returned no usable absolute PATH entries; preserving the inherited environment");
      return null;
    }
    final Map<String, String> imported = <String, String>{
      for (final MapEntry<String, String>(:String key, :String value) in shellEnvironment.entries)
        if (!_excludedShellVariables.contains(key)) key: value,
      "PATH": _mergePath(shellEntries: shellEntries, basePath: _baseEnvironment["PATH"]),
    };
    // Names only: values can hold credentials.
    logd(
      "Imported ${imported.length} variables from the login shell: "
      "${(imported.keys.toList()..sort()).join(", ")}",
    );
    return Map<String, String>.unmodifiable(imported);
  }

  /// Set to `1` in the probe shell's environment so startup files can detect
  /// that Sesori is only reading the environment.
  static const String resolvingEnvironmentVariable = "SESORI_RESOLVING_ENVIRONMENT";

  /// Shell variables never imported, so the inherited value (if any) is kept.
  ///
  /// `PWD`, `OLDPWD`, `SHLVL`, `_` and [resolvingEnvironmentVariable] describe
  /// the probe shell itself rather than the user's configuration.
  /// `AUTH_BACKEND_URL` redirects the bridge's auth backend; the app hands its
  /// own session to its bridge, so the app, not a shell export meant for a
  /// terminal bridge, decides that backend.
  static const Set<String> _excludedShellVariables = <String>{
    "PWD",
    "OLDPWD",
    "SHLVL",
    "_",
    resolvingEnvironmentVariable,
    "AUTH_BACKEND_URL",
  };

  /// Flags that run [command] in an interactive login [shell], following VS
  /// Code's shell-environment probe. csh and tcsh accept `-l` only as their
  /// sole flag, so they run as an interactive non-login shell (reading
  /// `.cshrc`/`.tcshrc`, not `.login`); nushell and xonsh take separate flags.
  /// PowerShell's `-Login` must come first and sources the POSIX login
  /// profiles through `/bin/sh`; `-Command` still loads `$PROFILE`, and
  /// `-NonInteractive` makes a prompting profile fail instead of hanging.
  @visibleForTesting
  static List<String> loginShellArguments({required String shell, required String command}) =>
      switch (_shellName(shell: shell)) {
        "csh" || "tcsh" => <String>["-ic", command],
        "nu" || "xonsh" => <String>["-l", "-i", "-c", command],
        "pwsh" || "pwsh-preview" => <String>[
          "-Login",
          "-NonInteractive",
          "-Command",
          command,
        ],
        _ => <String>["-ilc", command],
      };

  /// The command that prints a NUL marker, then the NUL-separated environment.
  ///
  /// It works unchanged in zsh, bash, dash, fish, csh/tcsh, nushell and
  /// PowerShell. xonsh decodes escapes inside quoted arguments, so it gets a
  /// raw string that passes `\000` through to printf. The marker is printed by
  /// a printf executable rather than a shell builtin or function; macOS always
  /// ships /usr/bin/printf, while some Linux distributions (such as NixOS) only
  /// guarantee /usr/bin/env.
  @visibleForTesting
  static String probeCommand({required String shell, required LoginShellPlatform platform}) {
    final String printf = switch (platform) {
      LoginShellPlatform.macOS => "/usr/bin/printf",
      LoginShellPlatform.linux => "/usr/bin/env printf",
    };
    final String marker = _shellName(shell: shell) == "xonsh" ? r"r'\000'" : r"'\000'";
    return "$printf $marker; /usr/bin/env -0";
  }

  static String _shellName({required String shell}) => shell.substring(shell.lastIndexOf("/") + 1);

  Future<Map<String, String>?> _readLoginShellEnvironment({required LoginShellPlatform platform}) async {
    final String shell = _shellExecutable(platform: platform);
    final String command = probeCommand(shell: shell, platform: platform);
    final LaunchEnvironmentProcessResult result;
    try {
      result = await _runProcess(
        executable: shell,
        arguments: loginShellArguments(shell: shell, command: command),
        // Process.start adds this to the inherited environment.
        environment: const <String, String>{resolvingEnvironmentVariable: "1"},
        timeout: _shellTimeout,
      );
    } on Object catch (error, stackTrace) {
      logw(
        "Failed to resolve the login-shell environment; preserving the inherited environment",
        error,
        stackTrace,
      );
      return null;
    }
    if (result.exitCode != 0) {
      logw(
        "The login shell exited with code ${result.exitCode}; preserving the inherited environment"
        "${_stderrDetails(stderr: result.stderr)}",
      );
      return null;
    }

    switch (result.environment) {
      case CompleteLaunchShellEnvironment(:final Map<String, String> variables):
        return variables;
      case OversizedLaunchShellEnvironment(:final String? path):
        logw(
          "The login-shell environment exceeded $_maxCapturedShellEnvironmentBytes bytes; "
          "importing only its PATH",
        );
        return path == null ? const <String, String>{} : <String, String>{"PATH": path};
    }
  }

  /// Parses the [probeCommand] (`printf '\0'; env -0`) output. Bytes before the first NUL are
  /// output from interactive startup files and an unterminated trailing
  /// fragment is logout-file output; neither is parsed. At most
  /// [_maxCapturedShellEnvironmentBytes] of variables are retained. Beyond that
  /// the variables are dropped, but the PATH record is still kept
  /// independently (up to [_maxCapturedShellRecordBytes]), so an oversized
  /// environment does not cost the executable search path.
  @visibleForTesting
  static Future<LaunchShellEnvironment> parseEnvironmentStream({required Stream<List<int>> stream}) =>
      _readEnvironmentStream(stream: stream);

  static Future<LaunchShellEnvironment> _readEnvironmentStream({required Stream<List<int>> stream}) async {
    final Map<String, String> variables = <String, String>{};
    final List<int> recordBytes = <int>[];
    bool markerSeen = false;
    bool recordTruncated = false;
    bool oversized = false;
    int capturedBytes = 0;
    String? path;

    void endRecord() {
      if (recordTruncated) {
        oversized = true;
      } else {
        final String record = utf8.decode(recordBytes, allowMalformed: true);
        final int separator = record.indexOf("=");
        if (separator > 0) {
          final String key = record.substring(0, separator);
          final String value = record.substring(separator + 1);
          if (key == "PATH") {
            path = value;
          }
          capturedBytes += recordBytes.length;
          oversized = oversized || capturedBytes > _maxCapturedShellEnvironmentBytes;
          if (!oversized) {
            variables[key] = value;
          }
        }
      }
      if (oversized) {
        variables.clear();
      }
      recordBytes.clear();
      recordTruncated = false;
    }

    await for (final List<int> chunk in stream) {
      for (final int byte in chunk) {
        if (!markerSeen) {
          markerSeen = byte == 0;
        } else if (byte == 0) {
          endRecord();
        } else if (!recordTruncated) {
          if (recordBytes.length >= _maxCapturedShellRecordBytes) {
            recordTruncated = true;
          } else {
            recordBytes.add(byte);
          }
        }
      }
    }
    if (oversized) {
      return OversizedLaunchShellEnvironment(path: path);
    }
    return CompleteLaunchShellEnvironment(variables: variables);
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

  String _shellExecutable({required LoginShellPlatform platform}) {
    final String? configured = _baseEnvironment["SHELL"]?.trim();
    if (configured != null && _isExecutableFile(path: configured)) {
      return configured;
    }
    switch (platform) {
      case LoginShellPlatform.macOS:
        return "/bin/zsh";
      case LoginShellPlatform.linux:
        final String? passwdShell = _passwdShell();
        if (passwdShell != null && _isExecutableFile(path: passwdShell)) {
          return passwdShell;
        }
        return "/bin/sh";
    }
  }

  /// The shell field of the current user's `/etc/passwd` entry. Users that only
  /// exist in a directory service are not listed there; they fall through to
  /// `/bin/sh`.
  String? _passwdShell() {
    final String? user = _nonEmpty(value: _baseEnvironment["USER"]) ?? _nonEmpty(value: _baseEnvironment["LOGNAME"]);
    final String? passwd = _readPasswdFile();
    if (user == null || passwd == null) return null;
    for (final String line in const LineSplitter().convert(passwd)) {
      final List<String> fields = line.split(":");
      if (fields.length == 7 && fields.first == user) {
        return _nonEmpty(value: fields.last);
      }
    }
    return null;
  }

  static String? _nonEmpty({required String? value}) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _readSystemPasswdFile() {
    try {
      return File("/etc/passwd").readAsStringSync();
    } on Object catch (error, stackTrace) {
      logw("Failed to read /etc/passwd to find the login shell", error, stackTrace);
      return null;
    }
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
      logw("Failed to inspect a candidate login shell; trying the next fallback", error, stackTrace);
      return false;
    }
  }

  static const int _maxCapturedShellOutputBytes = 64 * 1024;
  static const int _maxCapturedShellEnvironmentBytes = 64 * 1024;
  static const int _maxCapturedShellRecordBytes = 64 * 1024;

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
      final (int exitCode, LaunchShellEnvironment environment, String stderr) = await (
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
