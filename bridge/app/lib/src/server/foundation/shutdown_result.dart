// Moved to sesori_plugin_interface (ShutdownResult is now SignalResult);
// this shim keeps existing imports working until the migration's final
// cleanup PR removes it.
export "package:sesori_plugin_interface/sesori_plugin_interface.dart" show ShutdownResult, ShutdownSignal, SignalResult;
