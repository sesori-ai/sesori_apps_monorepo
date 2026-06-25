import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

CommandInfo _command({
  required String name,
  String? description,
  List<String>? hints,
}) {
  return CommandInfo(
    name: name,
    template: null,
    hints: hints,
    description: description,
    agent: null,
    model: null,
    provider: null,
    source: CommandSource.command,
    subtask: null,
  );
}

void main() {
  const builder = CommandPickerEntryBuilder();

  group("CommandPickerEntryBuilder.build", () {
    test("sorts commands by name", () {
      final entries = builder.build(
        commands: [
          _command(name: "zeta"),
          _command(name: "alpha"),
          _command(name: "mid"),
        ],
      );
      expect(entries.map((e) => e.command.name), ["alpha", "mid", "zeta"]);
    });

    test("keeps the original command on each entry", () {
      final command = _command(name: "deploy", description: "Ship it");
      final entries = builder.build(commands: [command]);
      expect(entries.single.command, command);
    });

    test("trims the description and nulls it out when blank or absent", () {
      final entries = builder.build(
        commands: [
          _command(name: "a", description: "  padded  "),
          _command(name: "b", description: "   "),
          _command(name: "c"),
        ],
      );
      expect(entries[0].displayDescription, "padded");
      expect(entries[1].displayDescription, isNull);
      expect(entries[2].displayDescription, isNull);
    });

    test("joins non-blank hints and nulls out when there are none", () {
      final entries = builder.build(
        commands: [
          _command(name: "a", hints: ["first", "  ", "second"]),
          _command(name: "b", hints: ["   "]),
          _command(name: "c"),
        ],
      );
      expect(entries[0].displayHints, "first  •  second");
      expect(entries[1].displayHints, isNull);
      expect(entries[2].displayHints, isNull);
    });

    test("caps display strings so huge descriptions never reach text layout", () {
      final entries = builder.build(
        commands: [
          _command(name: "a", description: "x" * 5000, hints: ["y" * 5000]),
        ],
      );
      expect(entries.single.displayDescription, hasLength(1000));
      expect(entries.single.displayHints, hasLength(1000));
    });

    test("builds a lowercase search haystack from name, description, and hints", () {
      final entries = builder.build(
        commands: [
          _command(name: "Deploy", description: "Ships the App", hints: ["Target ENV"]),
        ],
      );
      final searchText = entries.single.searchText;
      expect(searchText, contains("deploy"));
      expect(searchText, contains("ships the app"));
      expect(searchText, contains("target env"));
      expect(searchText, equals(searchText.toLowerCase()));
    });

    test("search haystack keeps the full description even when display is capped", () {
      final longTail = "${"x" * 2000} needle";
      final entries = builder.build(
        commands: [_command(name: "a", description: longTail)],
      );
      expect(entries.single.searchText, contains("needle"));
    });

    test("returns an empty list for no commands", () {
      expect(builder.build(commands: const []), isEmpty);
    });
  });
}
