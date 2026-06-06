// GENERATED FILE - DO NOT EDIT BY HAND


class MessageOutputLengthError {
  const MessageOutputLengthError({
    required this.name,
    required this.data,
  });

  factory MessageOutputLengthError.fromJson(Map<String, dynamic> json) {
    return MessageOutputLengthError(
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
