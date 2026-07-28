/// The parts of a session row that have to agree with each other on where
/// things sit.
///
/// The row is built from more than one file — the footer's branch detail lives
/// beside `PrStatusRow` — and the two only read as one line while they place
/// their marks in the same slot. Anything only one file cares about stays
/// private to it.
library;

/// Every icon on the row sits in a slot of this width — the harness logo
/// leading the title, the state sparkle ending it, and the footer's detail
/// marks — so the text beside each of them lines up down the list.
const double kSessionRowIconSlotWidth = 20;

/// The glyph a footer detail draws inside its slot. Smaller than the slot,
/// which is what spaces it from its text; it needs no gap of its own.
const double kSessionRowDetailIconSize = 14;
