/// The severity Pi assigns to an extension notification.
enum PiNotificationType(final String wireValue) {
  info("info"),
  warning("warning"),
  error("error");

  static PiNotificationType? tryParse({required String? value}) {
    for (final type in values) {
      if (type.wireValue == value) return type;
    }
    return null;
  }
}
