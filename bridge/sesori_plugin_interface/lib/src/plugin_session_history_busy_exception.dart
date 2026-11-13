import "plugin_operation_exception.dart";

/// The backend cannot replay this session's history while a turn on it is
/// running, and nothing has failed: the bridge serves the history it already
/// holds and reads the backend again once the turn ends. The status code
/// stays unset, so an instance that escapes still maps to a 502.
class const PluginSessionHistoryBusyException({required super.operation, required String super.message})
    extends PluginOperationException;
