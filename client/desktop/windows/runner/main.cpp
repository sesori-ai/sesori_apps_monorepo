#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr char kHiddenLaunchArgument[] = "--hidden";
constexpr char kVelopackHookPrefix[] = "--veloapp-";
constexpr char kVelopackUninstallHook[] = "--veloapp-uninstall";

// Velopack's Setup and Update.exe run the app as `<hook> <version>` and wait for
// it to exit, killing it after a timeout. Sesori has no install or update work,
// so a hook never starts Flutter. Uninstall removes the login value written by
// io_launch_at_login.dart; keep the key and value name in sync with it.
bool IsVelopackHook(const std::vector<std::string>& arguments) {
  return !arguments.empty() && arguments[0].rfind(kVelopackHookPrefix, 0) == 0;
}

int RunVelopackHook(const std::string& hook) {
  if (hook != kVelopackUninstallHook) {
    return EXIT_SUCCESS;
  }
  const LSTATUS status = ::RegDeleteKeyValueW(
      HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\CurrentVersion\\Run", L"Sesori");
  // A nonzero exit is recorded in Velopack's uninstall log.
  return status == ERROR_SUCCESS || status == ERROR_FILE_NOT_FOUND ? EXIT_SUCCESS : EXIT_FAILURE;
}

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
  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  if (IsVelopackHook(command_line_arguments)) {
    return RunVelopackHook(command_line_arguments[0]);
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
