import "package:freezed_annotation/freezed_annotation.dart";

/// Validated opaque lookup key for one account-scoped voice glossary.
@immutable
final class const ProjectGlossaryKey._({required final String value}) {
  static final RegExp _pattern = RegExp(r"^prj_v1_[A-Za-z0-9_-]{43}$");

  static ProjectGlossaryKey? tryParse({required String value}) {
    return _pattern.hasMatch(value) ? ProjectGlossaryKey._(value: value) : null;
  }

  factory parse({required String value}) {
    final key = tryParse(value: value);
    if (key == null) {
      throw const FormatException("Invalid project glossary key");
    }
    return key;
  }

  @override
  bool operator ==(Object other) => other is ProjectGlossaryKey && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

class const ProjectGlossaryKeyJsonConverter() implements JsonConverter<ProjectGlossaryKey, String> {
  @override
  ProjectGlossaryKey fromJson(String json) => ProjectGlossaryKey.parse(value: json);

  @override
  String toJson(ProjectGlossaryKey object) => object.value;
}
