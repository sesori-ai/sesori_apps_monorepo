// GENERATED FILE - DO NOT EDIT BY HAND


class PromptSource {
  const PromptSource({
    required this.start,
    required this.end,
    required this.text,
  });

  factory PromptSource.fromJson(Map<String, dynamic> json) {
    return PromptSource(
      start: json["start"] as double,
      end: json["end"] as double,
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
