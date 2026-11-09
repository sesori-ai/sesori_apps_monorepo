import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const file = PluginPromptPart.filePath(mime: "text/plain", path: "/tmp/a.txt", filename: "a.txt");

  test("joins each run of adjacent texts a blank line apart and drops blank texts", () {
    final joined = joinAdjacentPromptTextParts(
      parts: const [
        PluginPromptPart.text(text: "look at this"),
        PluginPromptPart.text(text: "  "),
        PluginPromptPart.text(text: "[Attached file: a.txt]"),
        file,
        PluginPromptPart.text(text: "after"),
        PluginPromptPart.text(text: "more"),
      ],
    );

    expect(joined, const [
      PluginPromptPart.text(text: "look at this\n\n[Attached file: a.txt]"),
      file,
      PluginPromptPart.text(text: "after\n\nmore"),
    ]);
  });

  test("keeps a lone text part as it is, even when blank", () {
    expect(
      joinAdjacentPromptTextParts(
        parts: const [
          PluginPromptPart.text(text: " "),
          file,
        ],
      ),
      const [
        PluginPromptPart.text(text: " "),
        file,
      ],
    );
  });
}
