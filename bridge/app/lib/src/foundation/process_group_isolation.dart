import "dart:ffi";
import "dart:io";

import "package:meta/meta.dart";

/// Calls the POSIX `setpgid` primitive.
@visibleForTesting
typedef PosixProcessGroupSetter = int Function({
  required int processId,
  required int processGroupId,
});

/// Reads the calling thread's POSIX errno value.
@visibleForTesting
typedef PosixErrorCodeReader = int Function();

/// Raised when a supervised bridge cannot become its own POSIX process-group
/// leader before it starts backend processes.
final class const ProcessGroupIsolationException({required final int errorCode}) implements Exception {
  @override
  String toString() => "ProcessGroupIsolationException: setpgid(0, 0) failed with errno $errorCode";
}

/// Establishes the supervised bridge as a POSIX process-group leader.
///
/// The supervised CLI invokes this before sleep prevention or any other
/// long-lived child starts. Those children inherit the group, allowing the
/// desktop owner to terminate the complete live group rather than relying on a
/// racy process-table snapshot. Windows uses `taskkill /T` at the desktop
/// boundary and therefore requires no helper-side setup. Standalone bridge runs
/// never invoke this primitive.
class ProcessGroupIsolation.forTesting({
  required final bool _isWindows,
  required final PosixProcessGroupSetter _setProcessGroup,
  required final PosixErrorCodeReader _readErrorCode,
}) {
  new()
    : this.forTesting(
        isWindows: Platform.isWindows,
        setProcessGroup: _setProcessGroupDefault,
        readErrorCode: _readErrorCodeDefault,
      );

  @visibleForTesting
  this;

  void isolateCurrentProcess() {
    if (_isWindows) {
      return;
    }
    final int result = _setProcessGroup(processId: 0, processGroupId: 0);
    if (result != 0) {
      throw ProcessGroupIsolationException(errorCode: _readErrorCode());
    }
  }

  static int _setProcessGroupDefault({required int processId, required int processGroupId}) =>
      _nativeSetProcessGroup(processId, processGroupId);

  static int _readErrorCodeDefault() => _nativeErrorAddress().value;

  // FFI signatures must mirror the positional native C ABI.
  static final int Function(int, int) _nativeSetProcessGroup = DynamicLibrary.process()
      .lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>("setpgid");

  static Pointer<Int32> Function() get _nativeErrorAddress {
    final String symbol = Platform.isMacOS ? "__error" : "__errno_location";
    return DynamicLibrary.process().lookupFunction<Pointer<Int32> Function(), Pointer<Int32> Function()>(symbol);
  }
}
