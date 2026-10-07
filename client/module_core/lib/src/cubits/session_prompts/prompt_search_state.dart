import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

/// What the Prompts screen's search field holds and what it finds.
@immutable
sealed class const PromptSearchState({
  /// The field's text, as typed.
  required final String query,
});

/// The field holds no search, so every prompt shows.
final class const PromptSearchIdle({required super.query}) extends PromptSearchState;

/// A search under way or done.
final class const PromptSearchActive({
  required super.query,

  /// The matching prompts by message id, in the list's order, each with the
  /// words around its first match.
  required final Map<String, SessionPromptExcerpt> matches,
  required final EarlierPromptSearch earlier,
}) extends PromptSearchState;

/// How far the bridge's search of the whole history has got. The listed
/// prompts' own matches show at once whatever it says.
enum EarlierPromptSearch() {
  /// Only the listed prompts' own text is searched: the list holds only the
  /// loaded prompts, or the bridge predates search.
  listedOnly,

  /// The bridge is searching, too briefly yet to say so.
  pending,

  /// The bridge has searched long enough that the screen says it is searching.
  slow,

  /// The bridge's matches have joined.
  done,

  /// The bridge's search failed; the listed prompts' own matches remain.
  failed,
}
