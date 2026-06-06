// GENERATED FILE - DO NOT EDIT BY HAND


abstract interface class ReferenceConfigEntry {
  const ReferenceConfigEntry();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `dynamic` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `dynamic`.
  dynamic toJson();

  factory ReferenceConfigEntry.fromJson(dynamic json) {
    if (json is String) {
      return referenceConfigEntry00Inline.fromJson(json);
    }
    if (json is Map<String, dynamic> && json.containsKey("repository")) {
      return referenceConfigEntry01Inline.fromJson(json);
    }
    if (json is Map<String, dynamic> && json.containsKey("path")) {
      return referenceConfigEntry02Inline.fromJson(json);
    }
    throw FormatException('Unknown ReferenceConfigEntry value: $json');
  }
}

class referenceConfigEntry00Inline implements ReferenceConfigEntry {
  const referenceConfigEntry00Inline({required this.value});
  factory referenceConfigEntry00Inline.fromJson(String json) {
    return referenceConfigEntry00Inline(value: json);
  }
  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{ 'value': value };
  }
  final String value;
}


class referenceConfigEntry01Inline implements ReferenceConfigEntry {
  const referenceConfigEntry01Inline({
    required this.repository,
    this.branch,
  });

  factory referenceConfigEntry01Inline.fromJson(Map<String, dynamic> json) {
    return referenceConfigEntry01Inline(
      repository: json["repository"] as String,
      branch: json["branch"] as String?,
    );
  }

  @override
  dynamic toJson() {
    return <String, dynamic>{
      "repository": repository,
      "branch": branch,
    };
  }

  final String repository;
  final String? branch;
}


class referenceConfigEntry02Inline implements ReferenceConfigEntry {
  const referenceConfigEntry02Inline({
    required this.path,
  });

  factory referenceConfigEntry02Inline.fromJson(Map<String, dynamic> json) {
    return referenceConfigEntry02Inline(
      path: json["path"] as String,
    );
  }

  @override
  dynamic toJson() {
    return <String, dynamic>{
      "path": path,
    };
  }

  final String path;
}
