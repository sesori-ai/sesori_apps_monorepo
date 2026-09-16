#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr char kHiddenLaunchArgument[] = "--hidden";
constexpr wchar_t kRunningMutexName[] = L"Local\\com.sesori.desktop.running";

// Inno Setup observes this process-lifetime marker before install or uninstall.
// Do not close it during window or Dart shutdown; Windows releases it at exit.
HANDLE g_running_mutex = nullptr;

bool HasHiddenLaunchArgument(const std::vector<std::string>& arguments) {
  for (const std::string& argument : arguments) {
    if (argument == kHiddenLaunchArgument) {
      return true;
    }
  }
  return false;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  g_running_mutex = ::CreateMutexW(nullptr, FALSE, kRunningMutexName);
  if (g_running_mutex == nullptr) {
    wchar_t error_message[160];
    swprintf_s(error_message, _countof(error_message),
               L"Sesori could not create its installer safety marker (Windows error %lu).", ::GetLastError());
    ::MessageBoxW(nullptr, error_message, L"Sesori startup failed", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  const bool hidden_launch = HasHiddenLaunchArgument(command_line_arguments);
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, hidden_launch);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Sesori", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
