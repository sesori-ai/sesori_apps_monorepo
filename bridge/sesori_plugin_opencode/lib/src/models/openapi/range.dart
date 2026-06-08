// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T09:42:34.349985Z


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
