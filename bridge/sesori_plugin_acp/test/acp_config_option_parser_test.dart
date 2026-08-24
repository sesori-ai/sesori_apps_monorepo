import "package:acp_plugin/acp_plugin.dart";
import "package:test/test.dart";

void main() {
  final configs = <Map<String, dynamic>>[
    {
      "id": "fallback",
      "category": "model",
      "value": "current",
      "options": [
        {"value": "flat"},
        {
          "options": [
            {"value": "nested"},
            "ignored",
          ],
        },
      ],
    },
    {"id": "exact", "category": "model", "currentValue": "selected"},
  ];

  test("finds category or exact id with category fallback", () {
    expect(AcpConfigOptionParser.find(configs: configs, category: "model"), same(configs.first));
    expect(AcpConfigOptionParser.find(configs: configs, category: "model", id: "exact"), same(configs.last));
    expect(AcpConfigOptionParser.find(configs: configs, category: "model", id: "missing"), same(configs.first));
    expect(AcpConfigOptionParser.find(configs: configs, category: "mode"), isNull);
  });

  test("parses ids, current values, and flattened options", () {
    expect(AcpConfigOptionParser.id(configs.first), "fallback");
    expect(AcpConfigOptionParser.currentValue(configs.first), "current");
    expect(AcpConfigOptionParser.currentValue(configs.last), "selected");
    expect(AcpConfigOptionParser.flattenedOptions(configs.first), [
      {"value": "flat"},
      {"value": "nested"},
    ]);
    expect(AcpConfigOptionParser.id({"id": ""}), isNull);
  });
}
