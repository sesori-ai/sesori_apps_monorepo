import "package:opencode_plugin/opencode_plugin.dart";
import "package:opencode_plugin/src/models/openapi/compaction_part.g.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const mapper = MessagePartMapper();

  test("keeps manual compaction hidden for command-level mapping", () {
    final part = mapper.mapPart(
      const CompactionPart(
        id: "part-1",
        sessionID: "session-1",
        messageID: "message-1",
        auto: false,
        overflow: null,
        tailStartId: null,
      ),
    );

    expect(part.type, equals(PluginMessagePartType.compaction));
    expect(part.text, isNull);
    expect(part.type.isVisible, isFalse);
  });

  test("keeps automatic compaction hidden", () {
    final part = mapper.mapPart(
      const CompactionPart(
        id: "part-1",
        sessionID: "session-1",
        messageID: "message-1",
        auto: true,
        overflow: true,
        tailStartId: null,
      ),
    );

    expect(part.type, equals(PluginMessagePartType.compaction));
    expect(part.text, isNull);
    expect(part.type.isVisible, isFalse);
  });
}
