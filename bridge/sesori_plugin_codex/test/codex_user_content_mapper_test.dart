import "package:codex_plugin/src/repositories/mappers/codex_user_content_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const mapper = CodexUserContentMapper();

  group("mapCommandInvocation", () {
    test("names a picked skill run with no text", () {
      expect(
        mapper.mapCommandInvocation(text: r"$fixture-greeter", skillNames: const ["fixture-greeter"]),
        const PluginCommandInvocation(name: "fixture-greeter", source: PluginCommandSource.skill, arguments: null),
      );
    });

    test("keeps multi-line text after the skill as its arguments", () {
      expect(
        mapper.mapCommandInvocation(text: "\$fixture-greeter first\nsecond", skillNames: const ["fixture-greeter"]),
        const PluginCommandInvocation(
          name: "fixture-greeter",
          source: PluginCommandSource.skill,
          arguments: "first\nsecond",
        ),
      );
    });

    test("names nothing when the text only starts with a longer word", () {
      expect(
        mapper.mapCommandInvocation(text: r"$fixture-greeters hi", skillNames: const ["fixture-greeter"]),
        isNull,
      );
    });
  });
}
