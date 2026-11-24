import "dart:async";
import "dart:collection";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformOs;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../foundation/streaming_process_runner.dart";
import "filesystem_api.dart";

/// Runs one command line through the user's shell, streaming its stdout and
/// stderr to files the current user alone can read.
///
/// POSIX runs `$SHELL -lc <command>`, falling back to `/bin/sh`: a login
/// shell gives a bridge that launchd or systemd started the user's `PATH`.
/// Windows runs `cmd.exe /d /s /c <command>`. A kill stops the shell; a
/// process it started in the background may keep running.
sealed class ShellCommandApi {
  /// [environment] is the bridge's; POSIX reads the login shell from `SHELL`.
  factory forPlatform({
    required PlatformOs platform,
    required StreamingProcessRunner runner,
    required FilesystemApi filesystem,
    required Map<String, String> environment,
  }) => switch (platform) {
    PlatformOs.macos || PlatformOs.linux => _ShellCommandApi(
      runner: runner,
      filesystem: filesystem,
      shell: switch (environment["SHELL"]) {
        final shell? when shell.trim().isNotEmpty => shell,
        _ => "/bin/sh",
      },
      shellArguments: const ["-lc"],
    ),
    PlatformOs.windows => _ShellCommandApi(
      runner: runner,
      filesystem: filesystem,
      shell: "cmd.exe",
      shellArguments: const ["/d", "/s", "/c"],
    ),
  };

  /// Runs [command] in [workingDirectory] with no input, writing its output
  /// to [stdoutPath] and [stderrPath], and kills it after [timeout].
  Future<ShellCommandResult> run({
    required String command,
    required String workingDirectory,
    required String stdoutPath,
    required String stderrPath,
    required Duration timeout,
  });
}

/// How a command run ended.
sealed class const ShellCommandResult();

final class const ShellCommandExited({
  required final int exitCode,
  required final ShellStreamOutput stdout,
  required final ShellStreamOutput stderr,
}) extends ShellCommandResult;

/// Killed at its timeout; the streams hold what it wrote until then.
final class const ShellCommandTimedOut({
  required final Duration timeout,
  required final ShellStreamOutput stdout,
  required final ShellStreamOutput stderr,
}) extends ShellCommandResult;

/// The shell did not start, for example because the folder is gone.
final class const ShellCommandCouldNotStart({required final String error}) extends ShellCommandResult;

/// One output stream, written whole to [path].
final class const ShellStreamOutput({
  required final String path,
  required final int wordCount,

  /// Its last lines, each cut to a few hundred characters.
  required final List<String> lastLines,

  /// The whole stream, or null when it grew too large to keep in memory.
  required final String? text,
});

final class _ShellCommandApi({
  required final StreamingProcessRunner _runner,
  required final FilesystemApi _filesystem,
  required final String _shell,
  required final List<String> _shellArguments,
}) implements ShellCommandApi {
  /// How long the streams may stay open after the shell ended or was killed:
  /// a process it started in the background can hold them.
  static const Duration _drainGrace = Duration(seconds: 5);

  @override
  Future<ShellCommandResult> run({
    required String command,
    required String workingDirectory,
    required String stdoutPath,
    required String stderrPath,
    required Duration timeout,
  }) async {
    try {
      return await _runner.run(
        executable: _shell,
        arguments: [..._shellArguments, command],
        workingDirectory: workingDirectory,
        environment: null,
        // A backstop only: the operation ends by itself soon after [timeout].
        timeout: timeout + const Duration(minutes: 1),
        operation: ({required process}) async {
          final stdout = await _capture(stream: process.stdout, path: stdoutPath);
          final stderr = await _capture(stream: process.stderr, path: stderrPath);
          await process.closeStdin();
          final exitCode = await process.exitCode
              .then<int?>((code) => code)
              .timeout(
                timeout,
                onTimeout: () {
                  process.kill();
                  return null;
                },
              );
          final out = await stdout();
          final err = await stderr();
          return switch (exitCode) {
            final code? => ShellCommandExited(exitCode: code, stdout: out, stderr: err),
            null => ShellCommandTimedOut(timeout: timeout, stdout: out, stderr: err),
          };
        },
      );
    } on ProcessException catch (error) {
      return ShellCommandCouldNotStart(error: error.message);
    }
  }

  /// Starts copying [stream] to [path] while tallying it, and returns the call
  /// that finishes the copy once the process has ended.
  Future<Future<ShellStreamOutput> Function()> _capture({
    required Stream<List<int>> stream,
    required String path,
  }) async {
    await _filesystem.writeOwnerOnlyFile(path: path, bytes: const []);
    final file = File(path).openWrite();
    final tally = _OutputTally();
    final text = const Utf8Decoder(allowMalformed: true).startChunkedConversion(tally);
    final ended = Completer<void>();
    final subscription = stream.listen(
      (chunk) {
        file.add(chunk);
        text.add(chunk);
      },
      onError: (Object error, StackTrace stackTrace) => Log.w("Could not read a command's output", error, stackTrace),
      onDone: ended.complete,
    );
    return () async {
      await ended.future.timeout(_drainGrace, onTimeout: subscription.cancel);
      text.close();
      await file.close();
      return ShellStreamOutput(path: path, wordCount: tally.words, lastLines: tally.lastLines, text: tally.keptText);
    };
  }
}

/// Counts the words of decoded output and keeps its last lines, and all of it
/// while it stays small.
final class _OutputTally() implements Sink<String> {
  static const int _keptLimit = 16 * 1024;
  static const int _tailLines = 20;
  static const int _maxLineLength = 400;

  final StringBuffer _kept = StringBuffer();
  bool _overflowed = false;
  final ListQueue<String> _tail = ListQueue();
  final StringBuffer _line = StringBuffer();
  bool _lineCut = false;
  bool _inWord = false;
  int words = 0;

  String? get keptText => _overflowed ? null : _kept.toString();

  List<String> get lastLines => List.unmodifiable(_tail);

  @override
  void add(String data) {
    if (!_overflowed) {
      if (_kept.length + data.length > _keptLimit) {
        _overflowed = true;
        _kept.clear();
      } else {
        _kept.write(data);
      }
    }
    for (final unit in data.codeUnits) {
      // Space, tab, line feed, vertical tab, form feed and carriage return.
      final isSpace = unit == 0x20 || (unit >= 0x09 && unit <= 0x0D);
      if (!isSpace && !_inWord) words++;
      _inWord = !isSpace;
      if (unit == 0x0A) {
        _endLine();
      } else if (_line.length < _maxLineLength) {
        _line.writeCharCode(unit);
      } else {
        _lineCut = true;
      }
    }
  }

  @override
  void close() {
    if (_line.isNotEmpty || _lineCut) _endLine();
  }

  void _endLine() {
    var line = _line.toString();
    if (line.endsWith("\r")) line = line.substring(0, line.length - 1);
    _tail.addLast(_lineCut ? "$line…" : line);
    if (_tail.length > _tailLines) _tail.removeFirst();
    _line.clear();
    _lineCut = false;
  }
}
