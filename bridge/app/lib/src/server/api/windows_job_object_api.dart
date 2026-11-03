import "dart:async";
import "dart:collection" show SplayTreeMap;
import "dart:ffi";
import "dart:io" as io;
import "dart:math" show Random;
import "dart:typed_data";

import "package:ffi/ffi.dart" show calloc, using;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:win32/win32.dart";

/// Ends bridge-started processes when the bridge process exits, crash
/// included.
///
/// Windows only; callers gate on the host platform. Owns one job object with
/// kill-on-close, created on first use. Its handle is not inheritable, so no
/// child can keep the job alive, and the bridge never closes it: the OS
/// closes it when the bridge exits, which ends every process in the job.
/// Descendants of a process in the job join it too.
class WindowsJobObjectApi() {
  late final HANDLE? _job = _createJob();
  final Random _random = Random.secure();

  /// Starts a process that is in the bridge's job object before it runs, so
  /// nothing it starts, `cmd.exe`'s child included, can run outside the job.
  ///
  /// Mirrors `io.Process.start` on Windows (command line, environment, stdio
  /// pipes, creation flags), so the child sees the same thing either way.
  /// Throws an [io.OSError] naming the failed call and its Win32 error, after
  /// releasing everything it created; nothing is left running.
  io.Process startBoundToBridgeLifetime({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
    required bool includeParentEnvironment,
  }) {
    final job = _job;
    if (job == null) {
      throw const io.OSError("The bridge's job object could not be created");
    }
    // Windows names are case-insensitive, so an explicit entry replaces the
    // parent's whatever its case (io.Process.start would pass both), and
    // CreateProcess wants the block sorted by name.
    final environmentBlock = SplayTreeMap<String, String>.of({
      if (includeParentEnvironment)
        for (final MapEntry(:key, :value) in io.Platform.environment.entries) key.toUpperCase(): "$key=$value",
      for (final MapEntry(:key, :value) in (environment ?? const <String, String>{}).entries)
        key.toUpperCase(): "$key=$value",
    });
    final pipes = <({HANDLE server, HANDLE child})>[];
    final ({HANDLE process, int pid}) started;
    try {
      pipes
        ..add(_createPipe(childReads: true))
        ..add(_createPipe(childReads: false))
        ..add(_createPipe(childReads: false));
      started = _createProcess(
        job: job,
        commandLine: _commandLine(executable: executable, arguments: arguments, runInShell: runInShell),
        environment: environmentBlock.values.toList(),
        workingDirectory: workingDirectory,
        stdio: [for (final pipe in pipes) pipe.child],
      );
    } on Object {
      for (final pipe in pipes) {
        CloseHandle(pipe.server);
      }
      rethrow;
    } finally {
      // A started child inherited its own copies; ours only keep the pipes open.
      for (final pipe in pipes) {
        CloseHandle(pipe.child);
      }
    }
    return _JobProcess(
      handle: started.process,
      pid: started.pid,
      stdinPipe: pipes[0].server,
      stdoutPipe: pipes[1].server,
      stderrPipe: pipes[2].server,
    );
  }

  /// Binds an already running [pid] to the bridge's lifetime; the fallback
  /// when [startBoundToBridgeLifetime] fails. Anything the process started
  /// before the bind stays outside the job. A failure logs and leaves the
  /// process unbound, exactly as it was before.
  void bindToBridgeLifetime({required int pid}) {
    final job = _job;
    if (job == null) return;
    final Win32Result(value: process, error: openError) = OpenProcess(
      PROCESS_SET_QUOTA | PROCESS_TERMINATE,
      false,
      pid,
    );
    if (!process.isValid) {
      Log.w("Could not open process $pid to end it with the bridge (Win32 error $openError)");
      return;
    }
    final Win32Result(value: assigned, error: assignError) = AssignProcessToJobObject(job, process);
    CloseHandle(process);
    if (!assigned) {
      Log.w("Could not bind process $pid to the bridge's job object (Win32 error $assignError)");
    }
  }

  // Same command line `io.Process.start` builds (Dart 3.13 process_patch.dart),
  // so the child parses the same arguments.
  String _commandLine({required String executable, required List<String> arguments, required bool runInShell}) {
    final path = runInShell ? "cmd.exe" : executable;
    final pathArguments = runInShell ? ["/c", executable, ...arguments] : arguments;
    final quotedPath = path.contains(" ") && !path.contains('"') ? '"$path"' : path;
    return [quotedPath, ...pathArguments.map(_escapeArgument)].join(" ");
  }

  // Dart's `_windowsArgumentEscape`: quote when the argument has a space, tab
  // or quote; double the backslashes before a quote or the closing quote.
  String _escapeArgument(String argument) {
    if (argument.isEmpty) return '""';
    if (!argument.contains(RegExp('[ \t"]'))) return argument;
    final escaped = argument
        .replaceAllMapped(RegExp(r'(\\*)"'), (match) => '${match[1]}${match[1]}\\"')
        .replaceAllMapped(RegExp(r"(\\+)$"), (match) => "${match[1]}${match[1]}");
    return '"$escaped"';
  }

  // Same pipes `io.Process.start` creates: overlapped, byte mode, one
  // instance. The bridge keeps the server end; the child inherits the other.
  ({HANDLE server, HANDLE child}) _createPipe({required bool childReads}) {
    return using((arena) {
      final name = "\\\\.\\pipe\\sesori-${io.pid}-${_random.nextInt(1 << 32)}-${_random.nextInt(1 << 32)}".toPcwstr(
        allocator: arena,
      );
      final server = CreateNamedPipe(
        name,
        (childReads ? PIPE_ACCESS_OUTBOUND : PIPE_ACCESS_INBOUND) |
            FILE_FLAG_OVERLAPPED |
            FILE_FLAG_FIRST_PIPE_INSTANCE,
        PIPE_TYPE_BYTE | PIPE_WAIT | PIPE_REJECT_REMOTE_CLIENTS,
        1,
        1024,
        1024,
        0,
        null,
      );
      if (!server.isValid) throw io.OSError("CreateNamedPipe", GetLastError());
      final inheritable = arena<SECURITY_ATTRIBUTES>();
      inheritable.ref
        ..nLength = sizeOf<SECURITY_ATTRIBUTES>()
        ..bInheritHandle = true;
      final Win32Result(value: child, error: openError) = CreateFile(
        name,
        childReads ? GENERIC_READ : GENERIC_WRITE,
        FILE_SHARE_NONE,
        inheritable,
        OPEN_EXISTING,
        FILE_FLAG_OVERLAPPED,
        null,
      );
      if (!child.isValid) {
        CloseHandle(server);
        throw io.OSError("CreateFile", openError);
      }
      return (server: server, child: child);
    });
  }

  ({HANDLE process, int pid}) _createProcess({
    required HANDLE job,
    required String commandLine,
    required List<String> environment,
    required String? workingDirectory,
    required List<HANDLE> stdio,
  }) {
    return using((arena) {
      final size = arena<IntPtr>();
      // Sizing call; it fails with ERROR_INSUFFICIENT_BUFFER by design.
      InitializeProcThreadAttributeList(null, 2, size);
      final attributes = LPPROC_THREAD_ATTRIBUTE_LIST(arena<Uint8>(size.value));
      final Win32Result(value: initialized, error: initError) = InitializeProcThreadAttributeList(attributes, 2, size);
      if (!initialized) throw io.OSError("InitializeProcThreadAttributeList", initError);
      try {
        // Only the three stdio ends are inherited, as io.Process.start does.
        final inherited = arena<Pointer>(stdio.length);
        for (final (index, handle) in stdio.indexed) {
          inherited[index] = handle;
        }
        _updateAttribute(
          attributes: attributes,
          attribute: _procThreadAttributeHandleList,
          value: inherited,
          size: stdio.length * sizeOf<Pointer>(),
        );
        // The process starts inside the job; there is no window before a bind.
        _updateAttribute(
          attributes: attributes,
          attribute: _procThreadAttributeJobList,
          value: arena<Pointer>()..value = job,
          size: sizeOf<Pointer>(),
        );
        final startup = arena<STARTUPINFOEX>();
        startup.ref
          ..StartupInfo.cb = sizeOf<STARTUPINFOEX>()
          ..StartupInfo.dwFlags = STARTF_USESTDHANDLES
          ..StartupInfo.hStdInput = stdio[0]
          ..StartupInfo.hStdOutput = stdio[1]
          ..StartupInfo.hStdError = stdio[2]
          ..lpAttributeList = attributes;
        final information = arena<PROCESS_INFORMATION>();
        final Win32Result(value: created, error: createError) = CreateProcess(
          null,
          commandLine.toPwstr(allocator: arena),
          null,
          null,
          true,
          EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT | CREATE_NO_WINDOW,
          "${environment.join("\u0000")}\u0000".toPcwstr(allocator: arena),
          workingDirectory?.toPcwstr(allocator: arena),
          startup.cast(),
          information,
        );
        if (!created) throw io.OSError("CreateProcess", createError);
        CloseHandle(information.ref.hThread);
        return (process: information.ref.hProcess, pid: information.ref.dwProcessId);
      } finally {
        DeleteProcThreadAttributeList(attributes);
      }
    });
  }

  void _updateAttribute({
    required LPPROC_THREAD_ATTRIBUTE_LIST attributes,
    required int attribute,
    required Pointer value,
    required int size,
  }) {
    final Win32Result(value: updated, error: updateError) = UpdateProcThreadAttribute(
      attributes,
      0,
      attribute,
      value,
      size,
      null,
      null,
    );
    if (!updated) throw io.OSError("UpdateProcThreadAttribute", updateError);
  }

  HANDLE? _createJob() {
    // Null security attributes make the handle non-inheritable.
    final Win32Result(value: job, error: createError) = CreateJobObject(null, null);
    if (!job.isValid) {
      Log.w("Could not create the job object that ends backend runtimes with the bridge (Win32 error $createError)");
      return null;
    }
    final limits = calloc<_JobObjectExtendedLimitInformation>();
    try {
      // Without SILENT_BREAKAWAY_OK every descendant joins the job.
      // BREAKAWAY_OK only lets a process that asks for CREATE_BREAKAWAY_FROM_JOB
      // leave, instead of failing to start.
      limits.ref.basicLimitInformation.limitFlags = _jobObjectLimitKillOnJobClose | _jobObjectLimitBreakawayOk;
      final Win32Result(value: configured, error: configureError) = SetInformationJobObject(
        job,
        JobObjectExtendedLimitInformation,
        limits,
        sizeOf<_JobObjectExtendedLimitInformation>(),
      );
      if (!configured) {
        CloseHandle(job);
        Log.w("Could not set kill-on-close on the bridge's job object (Win32 error $configureError)");
        return null;
      }
      return job;
    } finally {
      calloc.free(limits);
    }
  }
}

/// A process started inside the job, with the stdio `io.Process.start` gives.
///
/// No Dart thread blocks: the Windows thread pool reports pipe completions
/// and the exit through [NativeCallable.listener]s.
final class _JobProcess({
  required final HANDLE _handle,
  @override required final int pid,
  required final HANDLE _stdinPipe,
  required final HANDLE _stdoutPipe,
  required final HANDLE _stderrPipe,
}) implements io.Process {
  final Completer<int> _exitCode = Completer<int>();
  final Pointer<Pointer> _exitWait = calloc<Pointer>();
  late final NativeCallable<_WaitCallbackNative> _exited = NativeCallable.listener(_onExited);
  late final _PipeWriter _stdinWriter = _PipeWriter(pipe: _stdinPipe);

  @override
  late final io.IOSink stdin = io.IOSink(_stdinWriter);

  @override
  late final Stream<List<int>> stdout = _PipeReader(pipe: _stdoutPipe).stream;

  @override
  late final Stream<List<int>> stderr = _PipeReader(pipe: _stderrPipe).stream;

  this {
    final registered = _registerWaitForSingleObject(
      _exitWait,
      _handle,
      _exited.nativeFunction,
      nullptr,
      INFINITE,
      _wtExecuteOnlyOnce,
    );
    if (registered == FALSE) {
      final registerError = GetLastError();
      TerminateProcess(_handle, _terminatedExitCode);
      [_handle, _stdinPipe, _stdoutPipe, _stderrPipe].forEach(CloseHandle);
      _exited.close();
      calloc.free(_exitWait);
      throw io.OSError("RegisterWaitForSingleObject", registerError);
    }
  }

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  bool kill([io.ProcessSignal signal = io.ProcessSignal.sigterm]) {
    // The handle closes when the exit is reported.
    if (_exitCode.isCompleted) return false;
    return TerminateProcess(_handle, _terminatedExitCode).value;
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, native WAITORTIMERCALLBACK signature
  void _onExited(Pointer _, int _) {
    _unregisterWait(_exitWait.value);
    final code = calloc<Uint32>();
    final Win32Result(value: read, error: readError) = GetExitCodeProcess(_handle, code);
    if (!read) {
      Log.w("Could not read the exit code of process $pid (Win32 error $readError)");
    }
    // Read as signed, like io.Process: TerminateProcess(-1) reports -1.
    final exitCode = read ? code.value.toSigned(32) : -1;
    calloc
      ..free(code)
      ..free(_exitWait);
    CloseHandle(_handle);
    _exited.close();
    // io.Process closes stdin when the process exits, in case the caller did not.
    _stdinWriter.closeWhenIdle();
    _exitCode.complete(exitCode);
  }
}

/// Streams one pipe from the child, one overlapped read at a time, from the
/// first listen until the child side closes. After a cancel it keeps draining,
/// so the child never blocks on a full pipe.
final class _PipeReader({required final HANDLE _pipe}) {
  static const _bufferSize = 64 * 1024;
  late final Pointer<Uint8> _buffer = calloc<Uint8>(_bufferSize);
  late final Pointer<OVERLAPPED> _overlapped = calloc<OVERLAPPED>();
  late final NativeCallable<_IoCompletionNative> _completion = NativeCallable.listener(_onRead);
  late final StreamController<List<int>> _controller = StreamController<List<int>>(onListen: _start);

  Stream<List<int>> get stream => _controller.stream;

  void _start() {
    if (_bindIoCompletionCallback(_pipe, _completion.nativeFunction, 0) == FALSE) {
      _end(error: GetLastError());
      return;
    }
    _read();
  }

  void _read() {
    // Success and pending both deliver a completion to _onRead.
    final Win32Result(value: read, error: readError) = ReadFile(_pipe, _buffer, _bufferSize, null, _overlapped);
    if (!read && readError != ERROR_IO_PENDING) _end(error: readError);
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, native LPOVERLAPPED_COMPLETION_ROUTINE signature
  void _onRead(int error, int bytes, Pointer<OVERLAPPED> _) {
    if (error != ERROR_SUCCESS || bytes == 0) {
      _end(error: error);
      return;
    }
    _controller.add(Uint8List.fromList(_buffer.asTypedList(bytes)));
    _read();
  }

  // Only called with no read in flight, so no completion can follow.
  void _end({required int error}) {
    if (error != ERROR_SUCCESS && error != ERROR_BROKEN_PIPE && error != ERROR_HANDLE_EOF) {
      Log.w("Reading a process's output pipe failed (Win32 error $error)");
    }
    CloseHandle(_pipe);
    _completion.close();
    calloc
      ..free(_buffer)
      ..free(_overlapped);
    unawaited(_controller.close());
  }
}

/// Writes the child's stdin with sequential overlapped writes. A failed write
/// surfaces as an [io.OSError] on the owning `IOSink.done`, as with
/// `io.Process`.
final class _PipeWriter({required final HANDLE _pipe}) implements StreamConsumer<List<int>> {
  final Pointer<OVERLAPPED> _overlapped = calloc<OVERLAPPED>();
  late final NativeCallable<_IoCompletionNative> _completion = NativeCallable.listener(_onWritten);
  late final int _bindError = _bindIoCompletionCallback(_pipe, _completion.nativeFunction, 0) == FALSE
      ? GetLastError()
      : ERROR_SUCCESS;
  Completer<void>? _pending;
  bool _releaseWhenIdle = false;
  bool _released = false;

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final bytes in stream) {
      if (bytes.isNotEmpty) await _write(bytes);
    }
  }

  @override
  Future<void> close() async => closeWhenIdle();

  /// Releases the pipe now, or once the write in flight settles. The listener
  /// callback keeps the isolate alive until then.
  void closeWhenIdle() {
    _releaseWhenIdle = true;
    if (_pending == null) _release();
  }

  Future<void> _write(List<int> bytes) async {
    if (_releaseWhenIdle) throw const io.OSError("The process's stdin is closed", ERROR_BROKEN_PIPE);
    if (_bindError != ERROR_SUCCESS) throw io.OSError("BindIoCompletionCallback", _bindError);
    final buffer = calloc<Uint8>(bytes.length);
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    final pending = Completer<void>();
    _pending = pending;
    try {
      final Win32Result(value: written, error: writeError) = WriteFile(_pipe, buffer, bytes.length, null, _overlapped);
      if (!written && writeError != ERROR_IO_PENDING) throw io.OSError("WriteFile", writeError);
      await pending.future;
    } on Object {
      // IOSink never closes a consumer whose addStream failed.
      _releaseWhenIdle = true;
      rethrow;
    } finally {
      _pending = null;
      calloc.free(buffer);
      if (_releaseWhenIdle) _release();
    }
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, native LPOVERLAPPED_COMPLETION_ROUTINE signature
  void _onWritten(int error, int bytes, Pointer<OVERLAPPED> _) {
    final pending = _pending;
    if (pending == null) return;
    if (error == ERROR_SUCCESS) {
      pending.complete();
    } else {
      pending.completeError(io.OSError("WriteFile", error));
    }
  }

  // Only called with no write in flight, so no completion can follow.
  void _release() {
    if (_released) return;
    _released = true;
    CloseHandle(_pipe);
    _completion.close();
    calloc.free(_overlapped);
  }
}

// win32 6.4.0 ships neither the job limit flags nor the limit structs, the
// two process attributes, the wait flag or the three thread-pool calls below;
// these mirror winnt.h, winbase.h and processthreadsapi.h.
const int _jobObjectLimitBreakawayOk = 0x00000800;
const int _jobObjectLimitKillOnJobClose = 0x00002000;
const int _procThreadAttributeHandleList = 0x00020002;
const int _procThreadAttributeJobList = 0x0002000D;
const int _wtExecuteOnlyOnce = 0x00000008;
// io.Process.kill calls TerminateProcess(handle, -1).
const int _terminatedExitCode = 0xFFFFFFFF;

typedef _IoCompletionNative = Void Function(Uint32 error, Uint32 bytes, Pointer<OVERLAPPED> overlapped);
typedef _WaitCallbackNative = Void Function(Pointer context, Uint8 timedOut);

final DynamicLibrary _kernel32 = DynamicLibrary.open("kernel32.dll");

final int Function(Pointer, Pointer<NativeFunction<_IoCompletionNative>>, int) _bindIoCompletionCallback = _kernel32
    .lookupFunction<
      Int32 Function(Pointer, Pointer<NativeFunction<_IoCompletionNative>>, Uint32),
      int Function(Pointer, Pointer<NativeFunction<_IoCompletionNative>>, int)
    >("BindIoCompletionCallback");

final int Function(Pointer<Pointer>, Pointer, Pointer<NativeFunction<_WaitCallbackNative>>, Pointer, int, int)
_registerWaitForSingleObject = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Pointer>, Pointer, Pointer<NativeFunction<_WaitCallbackNative>>, Pointer, Uint32, Uint32),
      int Function(Pointer<Pointer>, Pointer, Pointer<NativeFunction<_WaitCallbackNative>>, Pointer, int, int)
    >("RegisterWaitForSingleObject");

final int Function(Pointer) _unregisterWait = _kernel32.lookupFunction<Int32 Function(Pointer), int Function(Pointer)>(
  "UnregisterWait",
);

final class _JobObjectBasicLimitInformation() extends Struct {
  @Int64()
  external int perProcessUserTimeLimit;
  @Int64()
  external int perJobUserTimeLimit;
  @Uint32()
  external int limitFlags;
  @Size()
  external int minimumWorkingSetSize;
  @Size()
  external int maximumWorkingSetSize;
  @Uint32()
  external int activeProcessLimit;
  @UintPtr()
  external int affinity;
  @Uint32()
  external int priorityClass;
  @Uint32()
  external int schedulingClass;
}

final class _IoCounters() extends Struct {
  @Uint64()
  external int readOperationCount;
  @Uint64()
  external int writeOperationCount;
  @Uint64()
  external int otherOperationCount;
  @Uint64()
  external int readTransferCount;
  @Uint64()
  external int writeTransferCount;
  @Uint64()
  external int otherTransferCount;
}

final class _JobObjectExtendedLimitInformation() extends Struct {
  external _JobObjectBasicLimitInformation basicLimitInformation;
  external _IoCounters ioInfo;
  @Size()
  external int processMemoryLimit;
  @Size()
  external int jobMemoryLimit;
  @Size()
  external int peakProcessMemoryUsed;
  @Size()
  external int peakJobMemoryUsed;
}
