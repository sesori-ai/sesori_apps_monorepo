import "dart:async";
import "dart:collection";
import "dart:convert";
import "dart:io" show FileSystemException, ProcessException, RandomAccessFile;

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../api/filesystem_api.dart";
import "../api/shell_command_api.dart";
import "models/scheduled_command_result.dart";

/// Runs the shell commands wake-ups and tasks carry, writing each run's
/// output as `stdout.txt` and `stderr.txt`, which only the user can open, in
/// the folder it is given.
class ScheduledCommandRepository({required final ShellCommandApi _shell, required final FilesystemApi _files}) {
  /// How long the streams may stay open after the shell ended or was killed:
  /// a process it started in the background can hold them.
  static const Duration _drainGrace = Duration(seconds: 5);

  /// Runs [command] in [workingDirectory] with its output in [folder], which
  /// only the user can open. Kills it after [timeout], or once [stop]
  /// completes.
  Future<ScheduledCommandResult> run({
    required String folder,
    required String command,
    required String workingDirectory,
    required Duration timeout,
    required Future<void> stop,
  }) async {
    final ({ShellCommandEnding ending, ({_StreamCapture stdout, _StreamCapture stderr}) output}) run;
    try {
      run = await _shell.run(
        command: command,
        workingDirectory: workingDirectory,
        timeout: timeout,
        stop: stop,
        capture: ({required stdout, required stderr}) => (
          stdout: _StreamCapture(stream: stdout, files: _files, path: p.join(folder, "stdout.txt")),
          stderr: _StreamCapture(stream: stderr, files: _files, path: p.join(folder, "stderr.txt")),
        ),
      );
    } on ProcessException catch (error) {
      return ScheduledCommandCouldNotStart(error: error.message);
    }
    final (stdout, stderr) = await (
      run.output.stdout.finish(grace: _drainGrace),
      run.output.stderr.finish(grace: _drainGrace),
    ).wait;
    return switch (run.ending) {
      ShellCommandExited(:final exitCode) => ScheduledCommandExited(exitCode: exitCode, stdout: stdout, stderr: stderr),
      ShellCommandTimedOut() => ScheduledCommandTimedOut(timeout: timeout, stdout: stdout, stderr: stderr),
      ShellCommandStopped() => ScheduledCommandStopped(stdout: stdout, stderr: stderr),
    };
  }
}

/// Copies one output stream to [_path] while tallying it. The stream pauses
/// while a write is pending, so a command that outruns the disk waits for it
/// instead of piling chunks up in memory.
///
/// A file that cannot be opened or written, as on a full disk, fails only the
/// copy: the tally goes on, and the output no longer names the file.
final class _StreamCapture({
  required Stream<List<int>> stream,
  required final FilesystemApi _files,
  required final String _path,
}) {
  final _OutputTally _tally = _OutputTally();
  late final Sink<List<int>> _text = const Utf8Decoder(allowMalformed: true).startChunkedConversion(_tally);
  final Completer<void> _ended = Completer<void>();
  late final Future<RandomAccessFile?> _file;
  late final StreamSubscription<List<int>> _subscription;
  Future<void> _lastWrite = Future<void>.value();
  bool _saved = true;

  this {
    _file = _open();
    _subscription = stream.listen(
      (chunk) {
        _text.add(chunk);
        _lastWrite = _write(chunk: chunk);
        _subscription.pause(_lastWrite);
      },
      onError: (Object error, StackTrace stackTrace) => Log.w("Could not read a command's output", error, stackTrace),
      onDone: _ended.complete,
    );
  }

  /// Waits up to [grace] for the stream to end, then closes the file.
  Future<CommandStreamOutput> finish({required Duration grace}) async {
    await _ended.future.timeout(grace, onTimeout: _subscription.cancel);
    _text.close();
    await _lastWrite;
    if (await _file case final file?) {
      try {
        await file.close();
      } on FileSystemException catch (error, stackTrace) {
        _failed(error: error, stackTrace: stackTrace);
      }
    }
    return CommandStreamOutput(
      path: _saved ? _path : null,
      wordCount: _tally.words,
      lastLines: _tally.lastLines,
      text: _tally.keptText,
    );
  }

  Future<RandomAccessFile?> _open() async {
    try {
      return await _files.openOwnerOnlyFileForWriting(path: _path);
    } on FileSystemException catch (error, stackTrace) {
      _failed(error: error, stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> _write({required List<int> chunk}) async {
    final file = await _file;
    if (file == null || !_saved) return;
    try {
      await file.writeFrom(chunk);
    } on FileSystemException catch (error, stackTrace) {
      _failed(error: error, stackTrace: stackTrace);
    }
  }

  void _failed({required FileSystemException error, required StackTrace stackTrace}) {
    _saved = false;
    Log.w("Could not save a command's output to $_path", error, stackTrace);
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
