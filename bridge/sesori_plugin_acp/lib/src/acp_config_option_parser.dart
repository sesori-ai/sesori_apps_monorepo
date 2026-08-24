import "package:sesori_shared/sesori_shared.dart" show asStringKeyedMap, nonEmptyString;

abstract final class AcpConfigOptionParser() {
  static Map<String, dynamic>? find({
    required List<Map<String, dynamic>> configs,
    required String category,
    String? id,
  }) {
    Map<String, dynamic>? categoryFallback;
    for (final config in configs) {
      if (id != null && config["id"] == id) return config;
      if (config["category"] == category) {
        if (id == null) return config;
        categoryFallback ??= config;
      }
    }
    return categoryFallback;
  }

  static String? id(Map<String, dynamic>? config) => nonEmptyString(config?["id"]);

  static String? currentValue(Map<String, dynamic>? config) =>
      nonEmptyString(config?["currentValue"] ?? config?["value"]);

  static List<Map<String, dynamic>> flattenedOptions(Map<String, dynamic>? config) {
    final raw = config?["options"];
    if (raw is! List) return const [];
    final options = <Map<String, dynamic>>[];
    for (final entry in raw) {
      final option = asStringKeyedMap(entry);
      if (option == null) continue;
      final nested = option["options"];
      if (nested is List) {
        options.addAll(nested.map(asStringKeyedMap).nonNulls);
      } else {
        options.add(option);
      }
    }
    return options;
  }
}
