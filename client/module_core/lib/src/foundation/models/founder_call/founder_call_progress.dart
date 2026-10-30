/// This device's progress through the CEO call invitation.
sealed class const FounderCallProgress();

/// No fresh sign-in has happened on this device since the invitation shipped,
/// so it never opens by itself. Users who were already signed in when they
/// updated stay here. Never stored: it is what an empty store means.
final class const FounderCallUnarmed() extends FounderCallProgress;

/// A progress value the device stores.
sealed class const FounderCallStoredProgress() extends FounderCallProgress;

/// A fresh sign-in happened on this device, so the sheet may open by itself.
final class const FounderCallArmed() extends FounderCallStoredProgress;

/// The invitation is finished on this device: the computer-connected sheet has
/// shown, or the booking link was opened from any surface. Nothing opens by
/// itself again.
final class const FounderCallRetired() extends FounderCallStoredProgress;
