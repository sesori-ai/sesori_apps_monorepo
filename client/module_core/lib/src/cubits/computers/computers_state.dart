/// Where the Computers page's last rename stands. The list itself is the
/// computer switcher's; this tracks only the action.
sealed class const ComputersState();

/// No rename is running, and the last one, if any, succeeded.
final class const ComputersIdle() extends ComputersState;

/// The server is renaming [bridgeId].
final class const ComputersRenaming({required final String bridgeId}) extends ComputersState;

/// The server refused or never confirmed the rename of [bridgeId]; its name is
/// unchanged.
final class const ComputersRenameFailed({required final String bridgeId}) extends ComputersState;
