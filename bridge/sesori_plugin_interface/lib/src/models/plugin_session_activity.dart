/// One session's current backend activity, read without starting the plugin.
sealed class const PluginSessionActivityResult();

/// The session's backend activity time.
///
/// [updatedAt] is epoch milliseconds: the same value, on the same clock, that
/// the plugin reports as `PluginSessionTime.updated` when it lists the session,
/// so activity seen on open compares directly with activity seen by an import.
final class const PluginSessionActivityAvailable({required final int updatedAt}) extends PluginSessionActivityResult;

/// The harness cannot answer cheaply, or cannot find the session without
/// scanning its whole catalog.
final class const PluginSessionActivityUnavailable() extends PluginSessionActivityResult;
