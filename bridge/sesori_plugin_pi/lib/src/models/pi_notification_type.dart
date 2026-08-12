/// The severity Pi assigns to an extension notification.
enum PiNotificationType(this.wireValue) {
  info("info"),
  warning("warning"),
  error("error");

  final String wireValue;

  static PiNotificationType? tryParse({required String? value}) {
    for (final type in values) {
      if (type.wireValue == value) return type;
    }
    return null;
  }
}
