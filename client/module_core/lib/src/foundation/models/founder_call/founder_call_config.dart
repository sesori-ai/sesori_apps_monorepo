/// The remote rule for the CEO call invitation.
sealed class const FounderCallConfig();

/// The master switch is off, for example in a blocked country: no surface
/// offers the call.
final class const FounderCallDisabled() extends FounderCallConfig;

/// The call is offered at [bookingUrl]. [afterComputer] switches the sheet that
/// opens by itself the first time the phone sees a connected computer.
final class const FounderCallEnabled({
  required final Uri bookingUrl,
  required final bool afterComputer,
  required final FounderCallCopy copy,
}) extends FounderCallConfig;

/// Remote wording for the invitation, so an A/B test can compare phrasings.
/// A null field uses the built-in localized text.
final class const FounderCallCopy({
  required final String? title,
  required final String? message,
  required final String? buttonLabel,
});
