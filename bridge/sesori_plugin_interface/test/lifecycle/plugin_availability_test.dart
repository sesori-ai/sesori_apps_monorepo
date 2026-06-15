import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("PluginAvailability", () {
    test("PluginAvailable is const and equal by type", () {
      expect(const PluginAvailable(), equals(const PluginAvailable()));
      expect(const PluginAvailable().hashCode, equals(const PluginAvailable().hashCode));
      expect(const PluginAvailable().toString(), equals("PluginAvailable"));
    });

    test("PluginUnavailable carries its message and value equality", () {
      final first = PluginUnavailable(message: "install opencode");
      final second = PluginUnavailable(message: "install opencode");
      final different = PluginUnavailable(message: "different message");

      expect(first, equals(second));
      expect(first.hashCode, equals(second.hashCode));
      expect(first, isNot(equals(different)));
      expect(first.toString(), equals("PluginUnavailable(message: install opencode)"));
    });

    test("PluginUnavailable rejects an empty message", () {
      expect(
        () => PluginUnavailable(message: ""),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
