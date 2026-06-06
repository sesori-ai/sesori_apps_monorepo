// GENERATED FILE - DO NOT EDIT BY HAND


class Range {
  const Range({
    required this.start,
    required this.end,
  });

  factory Range.fromJson(Map<String, dynamic> json) {
    return Range(
      start: json["start"] as Map<String, dynamic>,
      end: json["end"] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "start": start,
      "end": end,
    };
  }

  final Map<String, dynamic> start;
  final Map<String, dynamic> end;
}
