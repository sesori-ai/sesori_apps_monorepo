/// Single source of truth for the Sesori Bridge install and update commands
/// shown in the "connect your computer" onboarding and the update sheet.
///
/// Edit [_host] (or the individual commands) here if the installer hosting
/// changes. The branded `sesori.com` URLs front the canonical scripts that
/// currently live at
/// `raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/main/`.
class const BridgeInstall._() {
  /// Branded host that serves the install scripts. Change in one place to
  /// repoint every onboarding command.
  static const String _host = "https://sesori.com";

  /// macOS / Linux one-line installer.
  static const String macLinuxCommand = "curl -fsSL $_host/install.sh | bash";

  /// Windows (PowerShell) one-line installer.
  static const String windowsCommand = "irm $_host/install.ps1 | iex";

  /// npm runner that fetches and runs the published bridge package. Shared by
  /// every platform — the `@sesori/bridge` package name is registry-hosted, not
  /// served from [_host].
  static const String npmCommand = "npx @sesori/bridge";

  /// bun runner equivalent of [npmCommand].
  static const String bunCommand = "bunx @sesori/bridge";

  /// Command that starts an already-installed bridge. Shown on the
  /// bridge-offline Projects screen, where the common recovery is to (re)start
  /// the bridge rather than reinstall it.
  static const String runCommand = "sesori-bridge";

  /// Command that moves an installed bridge to the newest release. Bridges
  /// released before 2026-06-23 lack it; the installers above replace those.
  static const String updateCommand = "sesori-bridge update";
}
