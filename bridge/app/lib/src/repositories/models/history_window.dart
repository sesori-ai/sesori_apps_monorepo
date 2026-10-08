/// Which stored messages a history read returns, oldest first.
sealed class const HistoryWindow();

/// The whole transcript: what an app that predates pagination asks for.
final class const HistoryWindowAll() extends HistoryWindow;

/// The newest [limit] messages ordered below [before], or below nothing when
/// [before] is null: one page.
final class const HistoryWindowNewest({required final int limit, required final int? before}) extends HistoryWindow;

/// Every message from [throughSeq] up to, but not including, [before]: the
/// load-through to a prompt the app has not loaded. [throughSeq] is lower than
/// [before].
final class const HistoryWindowThrough({required final int throughSeq, required final int before})
    extends HistoryWindow;
