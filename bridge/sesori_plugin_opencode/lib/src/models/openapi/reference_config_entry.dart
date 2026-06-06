// GENERATED FILE - DO NOT EDIT BY HAND


abstract interface class ReferenceConfigEntry {
  const ReferenceConfigEntry();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

  factory ReferenceConfigEntry.fromJson(Map<String, dynamic> json) {
    final discriminator = json["type"];
    switch (discriminator) {
      // inline variant skipped: ReferenceConfigEntry
      // inline variant skipped: ReferenceConfigEntry
      // inline variant skipped: ReferenceConfigEntry
      default:
        throw FormatException('Unknown ReferenceConfigEntry value: $discriminator');
    }
  }
}
