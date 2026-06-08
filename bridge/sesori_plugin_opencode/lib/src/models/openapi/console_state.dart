// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T09:42:34.322261Z


class ConsoleState {
  const ConsoleState({
    required this.consoleManagedProviders,
    this.activeOrgName,
    required this.switchableOrgCount,
  });

  factory ConsoleState.fromJson(Map<String, dynamic> json) {
    return ConsoleState(
      consoleManagedProviders: (json["consoleManagedProviders"] as List<dynamic>).cast<String>(),
      activeOrgName: json["activeOrgName"] as String?,
      switchableOrgCount: json["switchableOrgCount"] as int,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "consoleManagedProviders": consoleManagedProviders,
      "activeOrgName": ?activeOrgName,
      "switchableOrgCount": switchableOrgCount,
    };
  }

  final List<String> consoleManagedProviders;
  final String? activeOrgName;
  final int switchableOrgCount;
}
