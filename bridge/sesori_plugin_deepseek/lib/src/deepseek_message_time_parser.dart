import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class const DeepSeekMessageTimeParser() {
  static const String _metadataKey = "sesori.ai/deepseek";
  static const int _maxSafeInteger = 9007199254740991;

  PluginMessageTime? parse<T>(Map<String, T> params) {
    final metadata = params["_meta"];
    if (metadata is! Map) return null;
    final envelope = metadata[_metadataKey];
    if (envelope is! Map) return null;
    final created = envelope["messageCreatedAt"];
    if (created is! int || created < 0 || created > _maxSafeInteger) return null;
    return PluginMessageTime(created: created, completed: null);
  }
}
