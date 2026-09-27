/// Caps a session transcript's reading column, which is deliberately wider than
/// the composer's: long assistant prose reads better in a longer measure. The
/// new-session pages use it too, so a first message waiting to send already
/// sits where the session page will hold it.
///
/// Bounded above by the timestamp peek. A drag slides the row content 108 px
/// left and brings a 108 px gutter in from the right, so the whole reveal
/// stays inside the window only while the column is at most
/// `paneWidth - 216`. On the 1240 px window the desktop is designed around
/// that ceiling is 1024, leaving 960 with 64 px of headroom. Widening past
/// the ceiling is not guarded and does not break: the peek degrades to the
/// phone's behaviour, where content slides under the window edge during the
/// drag, and a settled reveal is never clipped at any width.
const double desktopTranscriptWidth = 960;
