import "founder_call_config.dart";

/// Whether the CEO call is offered on this device right now.
sealed class const FounderCallAvailability();

/// The master switch is off, or the remote rule has not loaded yet.
final class const FounderCallHidden() extends FounderCallAvailability;

/// The call can be booked at [bookingUrl] from Settings.
final class const FounderCallAvailable({
  required final Uri bookingUrl,
  required final FounderCallCopy copy,
}) extends FounderCallAvailability;
