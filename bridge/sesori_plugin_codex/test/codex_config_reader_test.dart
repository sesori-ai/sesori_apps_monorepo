import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:path/path.dart" as p;
import "package:test/test.dart";

void main() {
  group("CodexConfigReader", () {
    late Directory codexHome;
    late CodexConfigReader reader;

    setUp(() {
      codexHome = Directory.systemTemp.createTempSync("codex-home-config-");
      reader = CodexConfigReader(environment: {"CODEX_HOME": codexHome.path});
    });

    tearDown(() {
      try {
        codexHome.deleteSync(recursive: true);
      } catch (_) {}
    });

    void writeConfig(String contents) {
      File(p.join(codexHome.path, "config.toml")).writeAsStringSync(contents);
    }

    test("returns nulls when config.toml is missing", () {
      final defaults = reader.readDefaults();
      expect(defaults.model, isNull);
      expect(defaults.modelProvider, isNull);
    });

    test("parses top-level model and model_provider", () {
      writeConfig('model = "gpt-5.5"\nmodel_provider = "openai"\n');
      final defaults = reader.readDefaults();
      expect(defaults.model, equals("gpt-5.5"));
      expect(defaults.modelProvider, equals("openai"));
    });

    test("ignores comments and surrounding whitespace", () {
      writeConfig('# leading comment\n  model = "gpt-5.4"  # trailing\n');
      final defaults = reader.readDefaults();
      expect(defaults.model, equals("gpt-5.4"));
      expect(defaults.modelProvider, isNull);
    });

    test("stops at the first table header (profile-scoped keys ignored)", () {
      writeConfig(
        'model = "gpt-5.5"\n'
        "[profiles.work]\n"
        'model = "gpt-5.2-codex"\n',
      );
      final defaults = reader.readDefaults();
      expect(defaults.model, equals("gpt-5.5"));
    });

    test("does not match keys that merely share a prefix", () {
      writeConfig('model_reasoning_effort = "high"\n');
      final defaults = reader.readDefaults();
      expect(defaults.model, isNull);
    });

    test("detects an explicit top-level model catalog", () {
      writeConfig(
        'model_catalog_json = "/private/models.json"\n'
        "[profiles.work]\n"
        'model_catalog_json = "/ignored/profile-models.json"\n',
      );

      expect(reader.hasExplicitModelCatalog(), isTrue);
    });

    test("detects quoted top-level model catalog keys", () {
      for (final key in [
        '"model_catalog_json"',
        "'model_catalog_json'",
      ]) {
        writeConfig('$key = "/private/models.json"\n');
        expect(
          reader.hasExplicitModelCatalog(),
          isTrue,
          reason: "TOML key form $key should preserve the user's catalog",
        );
      }
    });

    test("does not treat a profile-scoped model catalog as global", () {
      writeConfig(
        "[profiles.work]\n"
        'model_catalog_json = "/profile-models.json"\n',
      );

      expect(reader.hasExplicitModelCatalog(), isFalse);
    });
  });
}
