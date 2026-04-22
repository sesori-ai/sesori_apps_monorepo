enum SessionEffort {
  low("low"),
  medium("medium"),
  max("max")
  ;

  const SessionEffort(this.safeName);

  final String safeName;

  /// Parses a raw string into a [SessionEffort], or returns `null`
  /// if the value doesn't match any known effort.
  static SessionEffort? tryParse(String? value) => switch (value) {
    "low" => low,
    "medium" => medium,
    "max" => max,
    _ => null,
  };
}
