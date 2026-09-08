import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("CatalogStrengthOrder.variants", () {
    test("orders known efforts strongest first and keeps unknown ones after, in given order", () {
      expect(
        CatalogStrengthOrder.variants(["low", "zeta", "medium", "off", "high", "alpha", "xhigh", "max", "ultra"]),
        ["ultra", "max", "xhigh", "high", "medium", "low", "off", "zeta", "alpha"],
      );
    });

    test("treats mid, minimal, and none as ladder entries", () {
      expect(CatalogStrengthOrder.variants(["none", "mid", "minimal", "High"]), ["High", "mid", "minimal", "none"]);
    });

    test("ranks the highest and min aliases with max and minimal", () {
      expect(CatalogStrengthOrder.variants(["min", "low", "highest", "high"]), ["highest", "high", "low", "min"]);
    });
  });

  group("CatalogStrengthOrder.models", () {
    List<String> order(List<String> ids) => CatalogStrengthOrder.models(ids, idOf: (id) => id);

    test("ranks Anthropic ids by generation, family, then version", () {
      expect(
        order(["claude-3-opus", "claude-sonnet-4-6", "claude-opus-4-5", "claude-fable-5-1", "claude-haiku-4-5"]),
        ["claude-fable-5-1", "claude-opus-4-5", "claude-sonnet-4-6", "claude-haiku-4-5", "claude-3-opus"],
      );
      expect(order(["claude-opus-4-1", "claude-opus-4-5"]), ["claude-opus-4-5", "claude-opus-4-1"]);
    });

    test("ranks bare Claude Code ids by family and ignores the context-window suffix", () {
      expect(order(["haiku", "sonnet", "opus[1m]", "fable"]), ["fable", "opus[1m]", "sonnet", "haiku"]);
    });

    test("ranks OpenAI ids by generation, tier, bare, other suffix, then version", () {
      expect(
        order([
          "gpt-5.6-sol",
          "gpt-5.5-mini",
          "gpt-6-luna",
          "gpt-5.5",
          "gpt-5.6-terra",
          "gpt-6-astra",
          "gpt-5.6-luna",
          "gpt-5.4-mini",
          "gpt-5.3-codex-spark",
          "gpt-5.5-codex",
        ]),
        [
          "gpt-6-astra",
          "gpt-6-luna",
          "gpt-5.6-sol",
          "gpt-5.6-terra",
          "gpt-5.6-luna",
          "gpt-5.5",
          "gpt-5.5-mini",
          "gpt-5.5-codex",
          "gpt-5.4-mini",
          "gpt-5.3-codex-spark",
        ],
      );
    });

    test("matches a family only as a whole word", () {
      expect(order(["custom-sonnetlike", "claude-sonnet-4-6", "opusish"]), [
        "claude-sonnet-4-6",
        "custom-sonnetlike",
        "opusish",
      ]);
    });

    test("ignores namespace prefixes and keeps unknown models last in given order", () {
      expect(
        order(["zeta/custom", "opencode-go:gpt-5", "anthropic/claude-opus-4-5", "alpha-model", "opencode-go:gpt-5.5"]),
        ["opencode-go:gpt-5.5", "opencode-go:gpt-5", "anthropic/claude-opus-4-5", "zeta/custom", "alpha-model"],
      );
    });

    test("groups ranked vendors in order of first appearance", () {
      expect(order(["sonnet-4.6", "gpt-5.4", "opus-4.5"]), ["opus-4.5", "sonnet-4.6", "gpt-5.4"]);
      expect(order(["gpt-5.4", "sonnet-4.6", "gpt-5.6-sol"]), ["gpt-5.6-sol", "gpt-5.4", "sonnet-4.6"]);
    });
  });
}
