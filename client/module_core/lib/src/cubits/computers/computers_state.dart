/// Where the Computers page's last action stands. The list itself is the
/// computer switcher's; this tracks only the action.
sealed class const ComputersState();

/// No action is running, and the last one, if any, succeeded.
final class const ComputersIdle() extends ComputersState;

/// The server is renaming [bridgeId].
final class const ComputersRenaming({required final String bridgeId}) extends ComputersState;

/// The server refused or never confirmed the rename of [bridgeId]; the list
/// keeps its last known name.
final class const ComputersRenameFailed({required final String bridgeId}) extends ComputersState;

/// The server is removing [bridgeId] from the account.
final class const ComputersRemoving({required final String bridgeId}) extends ComputersState;

/// The server refused or never confirmed the removal of [bridgeId]; it stays
/// on the account.
final class const ComputersRemoveFailed({required final String bridgeId}) extends ComputersState;
