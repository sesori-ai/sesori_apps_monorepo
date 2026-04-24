import "package:meta/meta.dart";

@immutable
final class PluginSessionVariant {
  final String id;

  const PluginSessionVariant({required this.id});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginSessionVariant &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
