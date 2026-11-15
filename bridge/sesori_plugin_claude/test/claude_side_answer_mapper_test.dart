import "package:claude_plugin/claude_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const mapper = ClaudeSideAnswerMapper();

  PluginSideAnswer map(Map<String, Object?> json) =>
      mapper.map(response: ClaudeSideQuestionResponseDto.fromJson(json));

  test("maps a real answer with no notice", () {
    final answer = map({"response": "  Only the parser.\n", "synthetic": false});

    expect(answer, isA<PluginSideAnswered>().having((a) => a.text, "text", "Only the parser."));
    expect((answer as PluginSideAnswered).notice, isNull);
  });

  test("carries the fallback-model notice", () {
    final answer = map({
      "response": "Only the parser.",
      "synthetic": false,
      "refusal_fallback": {"original_model": "a", "fallback_model": "b", "content": "A fallback model answered."},
    });

    expect(answer, isA<PluginSideAnswered>().having((a) => a.notice, "notice", "A fallback model answered."));
  });

  test("drops an empty fallback notice", () {
    final answer = map({
      "response": "Only the parser.",
      "synthetic": false,
      "refusal_fallback": {"content": " "},
    });

    expect(answer, isA<PluginSideAnswered>().having((a) => a.notice, "notice", isNull));
  });

  for (final (name, json) in [
    ("a synthetic stand-in", {"response": "(The model tried to call Read instead of answering.)", "synthetic": true}),
    ("a null response", {"response": null, "synthetic": false}),
    ("a blank response", {"response": "  ", "synthetic": false}),
  ]) {
    test("refuses $name as no answer", () {
      expect(
        map(json),
        isA<PluginSideRefused>().having((r) => r.reason, "reason", PluginSideRefusal.noAnswer),
      );
    });
  }

  test("asks for a Claude Code update when the CLI lacks the handler", () {
    expect(
      mapper.unsupported(),
      isA<PluginSideRefused>().having((r) => r.reason, "reason", PluginSideRefusal.harnessUpdateRequired),
    );
  });
}
