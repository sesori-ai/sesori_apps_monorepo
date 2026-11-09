/// Caps a session transcript's reading column, which is deliberately wider than
/// the composer's: long assistant prose reads better in a longer measure. The
/// new-session pages use it too, so a first message waiting to send already
/// sits where the session page will hold it.
///
/// Bounded by the timestamp peek. A drag slides the row content 108 px left
/// and brings a 108 px gutter in from the right, so the whole reveal stays
/// inside the window only while the column is at most `paneWidth - 216`; at
/// 960 that holds in any pane at least 1176 px wide. A narrower pane is not
/// guarded and does not break: the peek degrades to the phone's behaviour,
/// where content slides under the window edge during the drag, and a settled
/// reveal is never clipped at any width.
const double desktopTranscriptWidth = 960;

/// Caps the session composer, its pointer-picker pills and the needs-you cards
/// above them. A text field and a pill row read as stretched long before body
/// text does, so they stay at this narrower measure. The home and new-session
/// column shares it, so its composer lands on the session page's at Send.
const double desktopComposerWidth = 760;
