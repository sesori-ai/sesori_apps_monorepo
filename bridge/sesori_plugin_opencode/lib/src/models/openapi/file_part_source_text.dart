// GENERATED FILE - DO NOT EDIT BY HAND


class FilePartSourceText {
  const FilePartSourceText({
    required this.value,
    required this.start,
    required this.end,
  });

  factory FilePartSourceText.fromJson(Map<String, dynamic> json) {
    return FilePartSourceText(
      value: json["value"] as String,
      start: json["start"] as double,
      end: json["end"] as double,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "value": value,
      "start": start,
      "end": end,
    };
  }

  final String value;
  final double start;
  final double end;
}
