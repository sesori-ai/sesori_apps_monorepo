import "package:meta/meta.dart";

@immutable
final class const PluginSessionVariant({required this.id}) {
  final String id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginSessionVariant &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
