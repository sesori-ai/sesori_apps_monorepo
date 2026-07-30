import "../../foundation/models/product_analytics/product_analytics_event.dart";

class QueuedSessionSubmission {
  final String text;
  final String? command;
  final AnalyticsSubmission analyticsSubmission;

  QueuedSessionSubmission.text({required this.text, required AnalyticsInputMode inputMode})
    : command = null,
      analyticsSubmission = AnalyticsTextSubmission(inputMode: inputMode);

  QueuedSessionSubmission.command({required this.text, required String command})
    : command = command,
      analyticsSubmission = const AnalyticsCommandSubmission();

  String get displayText => command != null
      ? text.trim().isEmpty
            ? "/$command"
            : "/$command ${text.trim()}"
      : text;

  bool get isCommand => command != null;
  AnalyticsInputMode get inputMode => analyticsSubmission.inputMode;
}
