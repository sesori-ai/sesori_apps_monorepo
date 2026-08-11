/// The severity Pi assigns to an extension notification.
enum PiNotificationType {
  info("info"),
  warning("warning"),
  error("error");

  const PiNotificationType(this.wireValue);

  final String wireValue;

  static PiNotificationType? tryParse({required String? value}) {
    for (final type in values) {
      if (type.wireValue == value) return type;
    }
    return null;
  }
}
