/// When an eligible, setup-ready plugin adapter should be activated.
enum PluginActivationPolicy() {
  /// Start only when a concrete plugin operation needs the adapter.
  onDemand,

  /// Start with the bridge so an independently running backend is monitored.
  eager,
}
