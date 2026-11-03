import "dart:ffi";

import "package:ffi/ffi.dart" show calloc;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:win32/win32.dart"
    show
        AssignProcessToJobObject,
        CloseHandle,
        CreateJobObject,
        HANDLE,
        JobObjectExtendedLimitInformation,
        OpenProcess,
        PROCESS_SET_QUOTA,
        PROCESS_TERMINATE,
        SetInformationJobObject,
        Win32Result;

/// Ends bound processes when the bridge process exits, crash included.
///
/// Windows only; callers gate on the host platform. Owns one job object with
/// kill-on-close, created on the first bind. Its handle is not inheritable, so
/// no child can keep the job alive, and the bridge never closes it: the OS
/// closes it when the bridge exits, which ends every process in the job.
/// Descendants a bound process starts later join the job too.
class WindowsJobObjectApi() {
  late final HANDLE? _job = _createJob();

  /// Binds [pid] to the bridge's lifetime. A failure logs and leaves the
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

// win32 6.4.0 ships neither the job limit flags nor the limit structs; these
// mirror winnt.h.
const int _jobObjectLimitBreakawayOk = 0x00000800;
const int _jobObjectLimitKillOnJobClose = 0x00002000;

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
