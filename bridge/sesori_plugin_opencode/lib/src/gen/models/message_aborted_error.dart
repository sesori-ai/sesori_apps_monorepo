// GENERATED FILE - DO NOT EDIT BY HAND


class MessageAbortedError {
  const MessageAbortedError({
    required this.name,
    required this.data,
  });

  factory MessageAbortedError.fromJson(Map<String, dynamic> json) {
    return MessageAbortedError(
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
