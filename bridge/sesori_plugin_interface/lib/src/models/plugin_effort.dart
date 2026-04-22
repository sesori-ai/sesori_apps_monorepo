enum PluginEffort {
  low("low"),
  medium("medium"),
  max("max");

  const PluginEffort(this.safeName);

  final String safeName;

  /// Parses a raw string into a [PluginEffort], or returns `null`
  /// if the value doesn't match any known effort.
  static PluginEffort? tryParse(String? value) => switch (value) {
    "low" => low,
    "medium" => medium,
    "max" => max,
    _ => null,
  };
}
