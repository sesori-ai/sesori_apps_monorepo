// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T09:42:34.347312Z


class PromptSource {
  const PromptSource({
    required this.start,
    required this.end,
    required this.text,
  });

  factory PromptSource.fromJson(Map<String, dynamic> json) {
    return PromptSource(
      start: (json["start"] as num).toDouble(),
      end: (json["end"] as num).toDouble(),
      text: json["text"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "start": start,
      "end": end,
      "text": text,
    };
  }

  final double start;
  final double end;
  final String text;
}
