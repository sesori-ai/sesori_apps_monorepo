import "dart:async";
import "dart:collection";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformOs;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../foundation/streaming_process_runner.dart";

/// Runs one command line through the user's shell, streaming its stdout and
/// stderr to files. The caller gives paths in a folder only the user can open.
///
/// POSIX runs `$SHELL -lc <command>`, falling back to `/bin/sh`: a login
/// shell gives a bridge that launchd or systemd started the user's `PATH`.
/// Windows runs `cmd.exe /d /s /c <command>`. A kill stops the shell; a
/// process it started in the background may keep running.
final class ShellCommandApi._({
  required final StreamingProcessRunner _runner,
  required final String _shell,
  required final List<String> _shellArguments,
}) {
  /// How long the streams may stay open after the shell ended or was killed:
  /// a process it started in the background can hold them.
  static const Duration _drainGrace = Duration(seconds: 5);

  /// [environment] is the bridge's; POSIX reads the login shell from `SHELL`.
  factory forPlatform({
    required PlatformOs platform,
    required StreamingProcessRunner runner,
    required Map<String, String> environment,
  }) => switch (platform) {
    PlatformOs.macos || PlatformOs.linux => ShellCommandApi._(
      runner: runner,
      shell: switch (environment["SHELL"]) {
        final shell? when shell.trim().isNotEmpty => shell,
        _ => "/bin/sh",
      },
      shellArguments: const ["-lc"],
    ),
    PlatformOs.windows => ShellCommandApi._(
      runner: runner,
      shell: "cmd.exe",
      shellArguments: const ["/d", "/s", "/c"],
    ),
  };

  /// Runs [command] in [workingDirectory] with no input, writing its output
  /// to [stdoutPath] and [stderrPath], which it creates. It kills the command
  /// after [timeout], or as soon as [stop] completes.
  Future<ShellCommandResult> run({
    required String command,
    required String workingDirectory,
    required String stdoutPath,
    required String stderrPath,
    required Duration timeout,
    required Future<void> stop,
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
          final ending = await Future.any<_Ending>([
            process.exitCode.then(_Exited.new),
            Future<_Ending>.delayed(timeout, () => const _TimedOut()),
            stop.then((_) => const _Stopped()),
          ]);
          if (ending is! _Exited) process.kill();
          final out = await stdout();
          final err = await stderr();
          return switch (ending) {
            _Exited(:final exitCode) => ShellCommandExited(exitCode: exitCode, stdout: out, stderr: err),
            _TimedOut() => ShellCommandTimedOut(timeout: timeout, stdout: out, stderr: err),
            _Stopped() => ShellCommandStopped(stdout: out, stderr: err),
          };
        },
      );
    } on ProcessException catch (error) {
      return ShellCommandCouldNotStart(error: error.message);
    }
  }

  /// Starts copying [stream] to [path] while tallying it, and returns the call
  /// that finishes the copy once the process has ended.
  ///
  /// A file that cannot be opened or written, as on a full disk, fails only
  /// the copy: the tally goes on, and the output no longer names the file.
  Future<Future<ShellStreamOutput> Function()> _capture({
    required Stream<List<int>> stream,
    required String path,
  }) async {
    RandomAccessFile? file;
    try {
      file = await File(path).open(mode: FileMode.writeOnly);
    } on FileSystemException catch (error, stackTrace) {
      Log.w("Could not save a command's output to $path", error, stackTrace);
    }
    var saved = file != null;
    var writes = Future<void>.value();
    final tally = _OutputTally();
    final text = const Utf8Decoder(allowMalformed: true).startChunkedConversion(tally);
    final ended = Completer<void>();
    final subscription = stream.listen(
      (chunk) {
        text.add(chunk);
        if (file case final open?) {
          writes = writes.then((_) async {
            if (!saved) return;
            try {
              await open.writeFrom(chunk);
            } on FileSystemException catch (error, stackTrace) {
              saved = false;
              Log.w("Could not save a command's output to $path", error, stackTrace);
            }
          });
        }
      },
      onError: (Object error, StackTrace stackTrace) => Log.w("Could not read a command's output", error, stackTrace),
      onDone: ended.complete,
    );
    return () async {
      await ended.future.timeout(_drainGrace, onTimeout: subscription.cancel);
      text.close();
      await writes;
      if (file case final open?) {
        try {
          await open.close();
        } on FileSystemException catch (error, stackTrace) {
          saved = false;
          Log.w("Could not save a command's output to $path", error, stackTrace);
        }
      }
      return ShellStreamOutput(
        path: saved ? path : null,
        wordCount: tally.words,
        lastLines: tally.lastLines,
        text: tally.keptText,
      );
    };
  }
}

sealed class const _Ending();

final class const _Exited(final int exitCode) extends _Ending;

final class const _TimedOut() extends _Ending;

final class const _Stopped() extends _Ending;

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

/// Killed because its caller stopped it, as at a bridge shutdown.
final class const ShellCommandStopped({
  required final ShellStreamOutput stdout,
  required final ShellStreamOutput stderr,
}) extends ShellCommandResult;

/// The shell did not start, for example because the folder is gone.
final class const ShellCommandCouldNotStart({required final String error}) extends ShellCommandResult;

/// One output stream, written whole to [path].
final class const ShellStreamOutput({
  /// Null when the file could not be written, as on a full disk.
  required final String? path,
  required final int wordCount,

  /// Its last lines, each cut to a few hundred characters.
  required final List<String> lastLines,

  /// The whole stream, or null when it grew too large to keep in memory.
  required final String? text,
});

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
