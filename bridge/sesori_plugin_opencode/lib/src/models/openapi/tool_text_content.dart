// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.690155Z


class ToolTextContent {
  const ToolTextContent({
    required this.type,
    required this.text,
  });

  factory ToolTextContent.fromJson(Map<String, dynamic> json) {
    return ToolTextContent(
      type: json["type"] as String,
      text: json["text"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "text": text,
    };
  }

  final String type;
  final String text;
}
