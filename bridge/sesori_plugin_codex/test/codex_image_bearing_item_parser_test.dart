import "package:codex_plugin/src/api/models/codex_image_bearing_item_dto.dart";
import "package:codex_plugin/src/api/parsers/codex_image_bearing_item_parser.dart";
import "package:test/test.dart";

void main() {
  group("CodexImageBearingItemParser", () {
    const parser = CodexImageBearingItemParser();

    test("decodes image generation statuses and fields", () {
      final completed = parser.parse(
        item: {
          "type": "imageGeneration",
          "id": "image-1",
          "status": "completed",
          "revisedPrompt": "draw a landscape",
          "result": "encoded-image",
          "savedPath": "/private/output.png",
        },
      );
      final unknown = parser.parse(
        item: {
          "type": "imageGeneration",
          "id": "image-2",
          "status": "future_status",
          "revisedPrompt": null,
          "result": "",
        },
      );

      expect(completed, isA<CodexImageGenerationItemDto>());
      final image = completed! as CodexImageGenerationItemDto;
      expect(image.status, CodexImageGenerationStatus.completed);
      expect(image.revisedPrompt, "draw a landscape");
      expect(image.result, "encoded-image");
      expect(image.savedPath, "/private/output.png");
      expect((unknown! as CodexImageGenerationItemDto).status, CodexImageGenerationStatus.unknown);
    });

    test("decodes MCP text and image content without retaining unknown payloads", () {
      final item = parser.parse(
        item: {
          "type": "mcpToolCall",
          "id": "mcp-1",
          "server": "playwright",
          "tool": "screenshot",
          "status": "failed",
          "result": {
            "content": [
              {"type": "text", "text": "before"},
              {"type": "image", "data": "encoded-image", "mimeType": "image/png"},
              {"type": "future_content", "secret": "ignored"},
              {"type": "text", "text": "after"},
            ],
          },
          "error": {"message": "tool failed"},
        },
      );

      final mcp = item! as CodexMcpToolCallItemDto;
      expect(mcp.status, CodexToolCallStatus.failed);
      expect(mcp.content, hasLength(4));
      expect(mcp.content[1], isA<CodexMcpImageContentDto>());
      final image = mcp.content[1] as CodexMcpImageContentDto;
      expect(image.data, "encoded-image");
      expect(image.mimeType, "image/png");
      expect(mcp.content[2], isA<CodexUnknownImageBearingContentDto>());
      expect((mcp.content.first as CodexMcpTextContentDto).text, "before");
      expect((mcp.content.last as CodexMcpTextContentDto).text, "after");
      expect(mcp.error, "tool failed");
    });

    test("decodes dynamic text, image, and audio with tolerant tool status", () {
      final item = parser.parse(
        item: {
          "type": "dynamicToolCall",
          "id": "dynamic-1",
          "tool": 42,
          "arguments": {"query": "status"},
          "status": "future_status",
          "contentItems": [
            {"type": "inputText", "text": "first"},
            {"type": "inputImage", "imageUrl": "data:image/png;base64,AA=="},
            {"type": "inputAudio", "audioUrl": "data:audio/wav;base64,AA=="},
            {"type": "inputText", "text": "second"},
          ],
        },
      );

      final dynamic = item! as CodexDynamicToolCallItemDto;
      expect(dynamic.tool, "tool");
      expect(dynamic.status, CodexToolCallStatus.unknown);
      expect(dynamic.content[1], isA<CodexDynamicImageContentDto>());
      expect(dynamic.content[2], isA<CodexDynamicAudioContentDto>());
      expect((dynamic.content.first as CodexDynamicTextContentDto).text, "first");
      expect((dynamic.content.last as CodexDynamicTextContentDto).text, "second");
    });

    test("keeps unknown items closed and drops malformed known items", () {
      expect(
        parser.parse(item: {"type": "future_item", "secret": "ignored"}),
        isA<CodexUnknownImageBearingItemDto>(),
      );
      expect(
        parser.parse(
          item: {
            "type": "imageGeneration",
            "id": "image-1",
            "status": "completed",
            "revisedPrompt": null,
          },
        ),
        isNull,
      );
    });
  });
}
