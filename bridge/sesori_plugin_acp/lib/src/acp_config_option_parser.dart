import "package:sesori_shared/sesori_shared.dart" show asStringKeyedMap, nonEmptyString;

abstract final class AcpConfigOptionParser() {
  static Map<String, dynamic>? find({
    required List<Map<String, dynamic>> configs,
    required String category,
    required String? id,
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

  static String? id({required Map<String, dynamic>? config}) => nonEmptyString(value: config?["id"]);

  static String? currentValue({required Map<String, dynamic>? config}) =>
      nonEmptyString(value: config?["currentValue"] ?? config?["value"]);

  static List<Map<String, dynamic>> flattenedOptions({required Map<String, dynamic>? config}) {
    final raw = config?["options"];
    if (raw is! List) return const [];
    final options = <Map<String, dynamic>>[];
    for (final entry in raw) {
      final option = asStringKeyedMap(value: entry);
      if (option == null) continue;
      final nested = option["options"];
      if (nested is List) {
        options.addAll(nested.map((entry) => asStringKeyedMap(value: entry)).nonNulls);
      } else {
        options.add(option);
      }
    }
    return options;
  }
}
