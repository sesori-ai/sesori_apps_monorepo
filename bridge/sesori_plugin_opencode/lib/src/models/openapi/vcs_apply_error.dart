// GENERATED FILE - DO NOT EDIT BY HAND


class VcsApplyError {
  const VcsApplyError({
    required this.name,
    required this.data,
  });

  factory VcsApplyError.fromJson(Map<String, dynamic> json) {
    return VcsApplyError(
      name: json["name"] as String,
      data: json["data"] as Map<String, dynamic>,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "data": data,
    };
  }

  final String name;
  final Map<String, dynamic> data;
}
