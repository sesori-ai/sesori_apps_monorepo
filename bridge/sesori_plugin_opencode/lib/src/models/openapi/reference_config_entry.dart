// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.244254Z

import 'package:meta/meta.dart';

@immutable
abstract interface class ReferenceConfigEntry {
  const ReferenceConfigEntry();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory ReferenceConfigEntry.fromJson(Object json) {
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

@immutable
class referenceConfigEntry00Inline implements ReferenceConfigEntry {
  const referenceConfigEntry00Inline({required this.value});
  factory referenceConfigEntry00Inline.fromJson(String json) {
    return referenceConfigEntry00Inline(value: json);
  }
  @override
  Object? toJson() => value;
  final String value;
}


@immutable
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
  Object? toJson() {
    return <String, dynamic>{
      "repository": repository,
      "branch": ?branch,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is referenceConfigEntry01Inline &&
          other.repository == repository &&
          other.branch == branch);

  @override
  int get hashCode => Object.hash(repository, branch);

  final String repository;
  final String? branch;
}


@immutable
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
  Object? toJson() {
    return <String, dynamic>{
      "path": path,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is referenceConfigEntry02Inline &&
          other.path == path);

  @override
  int get hashCode => path.hashCode;

  final String path;
}
