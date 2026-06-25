/// Single source of truth for the Sesori Bridge install instructions shown in
/// the "connect your computer" onboarding.
///
/// Edit [_host] (or the individual commands) here if the installer hosting
/// changes. The branded `sesori.com` URLs front the canonical scripts that
/// currently live at
/// `raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/main/`.
class BridgeInstall {
  const BridgeInstall._();

  /// Branded host that serves the install scripts. Change in one place to
  /// repoint every onboarding command.
  static const String _host = "https://sesori.com";

  /// macOS / Linux one-line installer.
  static const String macLinuxCommand = "curl -fsSL $_host/install.sh | bash";

  /// Windows (PowerShell) one-line installer.
  static const String windowsCommand = "irm $_host/install.ps1 | iex";

  /// Command that starts the bridge once it is installed.
  static const String runCommand = "sesori-bridge";
}
