/// What the desktop updater can currently offer; never persisted or exchanged with peers.
sealed class const DesktopUpdateState();

/// The app updates itself and has nothing downloaded yet.
final class const DesktopUpdateIdle() extends DesktopUpdateState;

/// A newer version is installed, or downloaded and verified; it applies on
/// "Restart to update", and a downloaded one also on Quit.
final class const DesktopUpdateReady({required final String version}) extends DesktopUpdateState;

/// The system package manager installs updates; the app only notices them.
final class const DesktopUpdateManagedBySystem() extends DesktopUpdateState;

final class const DesktopUpdateUnavailable({required final DesktopUpdateUnavailableReason reason})
    extends DesktopUpdateState;

enum DesktopUpdateUnavailableReason() {
  developmentBuild,
}
