// GENERATED FILE - DO NOT EDIT BY HAND


class FormatterStatus {
  const FormatterStatus({
    required this.name,
    required this.extensions,
    required this.enabled,
  });

  factory FormatterStatus.fromJson(Map<String, dynamic> json) {
    return FormatterStatus(
      name: json["name"] as String,
      extensions: (json["extensions"] as List<dynamic>).cast<String>(),
      enabled: json["enabled"] as bool,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "extensions": extensions,
      "enabled": enabled,
    };
  }

  final String name;
  final List<String> extensions;
  final bool enabled;
}
