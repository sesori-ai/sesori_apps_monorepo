import "dart:ffi";
import "dart:io" show pid;

import "package:ffi/ffi.dart";
import "package:window_manager/window_manager.dart";

// Must match kWindowClassName in windows/runner/win32_window.cpp.
const String _runnerWindowClass = "FLUTTER_RUNNER_WIN32_WINDOW";

typedef _FindWindowEx = int Function(int, int, Pointer<Utf16>, Pointer<Utf16>);
typedef _GetWindowThreadProcessId = int Function(int, Pointer<Uint32>);

/// This process's runner window on Windows, visible or not.
///
/// nativeapi finds a Windows window only once it is active, but the runner
/// shows its window after the first frame, so the window is set up while it
/// is still hidden. Several Flutter apps share the runner's window class, so
/// the process decides which one is Sesori's.
Window? findWindowsRunnerWindow() {
  final DynamicLibrary user32 = DynamicLibrary.open("user32.dll");
  final _FindWindowEx findWindowEx = user32
      .lookupFunction<IntPtr Function(IntPtr, IntPtr, Pointer<Utf16>, Pointer<Utf16>), _FindWindowEx>("FindWindowExW");
  final _GetWindowThreadProcessId getWindowThreadProcessId = user32
      .lookupFunction<Uint32 Function(IntPtr, Pointer<Uint32>), _GetWindowThreadProcessId>("GetWindowThreadProcessId");
  return using((arena) {
    final Pointer<Utf16> windowClass = _runnerWindowClass.toNativeUtf16(allocator: arena);
    final Pointer<Uint32> processId = arena<Uint32>();
    for (
      int handle = findWindowEx(0, 0, windowClass, nullptr);
      handle != 0;
      handle = findWindowEx(0, handle, windowClass, nullptr)
    ) {
      getWindowThreadProcessId(handle, processId);
      if (processId.value == pid) {
        return Window.createWithNativeWindow(Pointer<Void>.fromAddress(handle));
      }
    }
    return null;
  });
}
