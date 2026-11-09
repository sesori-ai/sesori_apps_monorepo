import "dart:convert";
import "dart:io";

import "package:claude_plugin/src/api/claude_settings_api.dart";
import "package:claude_plugin/src/repositories/claude_base_url_repository.dart";
import "package:test/test.dart";

void main() {
  late Directory configDirectory;

  setUp(() async {
    configDirectory = await Directory.systemTemp.createTemp("claude-config");
    addTearDown(() => configDirectory.delete(recursive: true));
  });

  bool usesCustomBaseUrl({required Map<String, String> environment, required Object? settings}) {
    if (settings != null) {
      File("${configDirectory.path}${Platform.pathSeparator}settings.json").writeAsStringSync(
        settings is String ? settings : jsonEncode(settings),
      );
    }
    final fullEnvironment = {"CLAUDE_CONFIG_DIR": configDirectory.path, ...environment};
    return ClaudeBaseUrlRepository(
      settings: ClaudeSettingsApi(environment: fullEnvironment),
      environment: fullEnvironment,
    ).usesCustomBaseUrl();
  }

  test("reports no custom base URL when none is configured", () {
    expect(
      usesCustomBaseUrl(
        environment: const {},
        settings: {
          "env": {"ANTHROPIC_MODEL": "glm-5"},
        },
      ),
      isFalse,
    );
  });

  test("reads a gateway base URL from the environment and from user settings", () {
    expect(usesCustomBaseUrl(environment: const {"ANTHROPIC_BASE_URL": "http://127.0.0.1:8080"}, settings: null), isTrue);
    expect(
      usesCustomBaseUrl(
        environment: const {},
        settings: {
          "env": {"ANTHROPIC_BASE_URL": "https://gateway.example.com/anthropic"},
        },
      ),
      isTrue,
    );
  });

  test("does not count Anthropic's own base URL", () {
    expect(usesCustomBaseUrl(environment: const {"ANTHROPIC_BASE_URL": "https://api.anthropic.com/"}, settings: null), isFalse);
    expect(usesCustomBaseUrl(environment: const {"ANTHROPIC_BASE_URL": "HTTPS://API.Anthropic.COM"}, settings: null), isFalse);
    expect(
      usesCustomBaseUrl(
        environment: const {},
        settings: {
          "env": {"ANTHROPIC_BASE_URL": " https://api.anthropic.com "},
        },
      ),
      isFalse,
    );
  });

  test("lets user settings override the environment like the CLI does", () {
    expect(
      usesCustomBaseUrl(
        environment: const {"ANTHROPIC_BASE_URL": "http://127.0.0.1:8080"},
        settings: {
          "env": {"ANTHROPIC_BASE_URL": ""},
        },
      ),
      isFalse,
    );
    expect(
      usesCustomBaseUrl(
        environment: const {"ANTHROPIC_BASE_URL": "https://api.anthropic.com"},
        settings: {
          "env": {"ANTHROPIC_BASE_URL": "http://127.0.0.1:8080"},
        },
      ),
      isTrue,
    );
  });

  test("falls back to the environment when user settings are malformed or unreadable", () {
    expect(
      usesCustomBaseUrl(
        environment: const {"ANTHROPIC_BASE_URL": "http://127.0.0.1:8080"},
        settings: '{"env": {"ANTHROPIC_AUTH_TOKEN": "private-token"',
      ),
      isTrue,
    );
    File("${configDirectory.path}${Platform.pathSeparator}settings.json").deleteSync();
    Directory("${configDirectory.path}${Platform.pathSeparator}settings.json").createSync();
    expect(usesCustomBaseUrl(environment: const {"ANTHROPIC_BASE_URL": "http://127.0.0.1:8080"}, settings: null), isTrue);
  });
}
