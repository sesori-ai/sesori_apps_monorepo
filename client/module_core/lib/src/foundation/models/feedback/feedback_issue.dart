import "package:freezed_annotation/freezed_annotation.dart";

/// A problem the user can tick in private feedback. The wire values are shared
/// with the auth server's `FeedbackIssue`; renaming one breaks submissions.
@JsonEnum(valueField: "wireValue")
enum FeedbackIssue({required final String wireValue}) {
  hardToNavigate(wireValue: "hard_to_navigate"),
  connectionDrops(wireValue: "connection_drops"),
  notificationsMissing(wireValue: "notifications_missing"),
  appSlow(wireValue: "app_slow"),
}
