/// Strongest-first ordering shared by every plugin catalog, so pickers read
/// the same way whichever harness serves them.
///
/// Models are ranked from their id alone, because only some backends report a
/// vendor: Anthropic ids carry a family word (`fable`, `opus`, `sonnet`,
/// `haiku`) and OpenAI ids start with `gpt`. Anything else keeps the order the
/// caller passed, after the ranked models.
abstract final class const CatalogStrengthOrder() {
  /// Effort names strongest first. Aliases share a rank; unknown names follow
  /// in the order given.
  static const List<List<String>> _effortLadder = [
    ["ultra"],
    ["max", "highest"],
    ["xhigh"],
    ["high"],
    ["medium", "mid"],
    ["low"],
    ["minimal", "min"],
    ["off", "none"],
  ];

  static const List<String> _anthropicFamilies = ["fable", "opus", "sonnet", "haiku"];
  static const List<String> _openAiTiers = ["astra", "sol", "terra", "luna"];

  /// Whole-word match, so `custom-sonnetlike` stays unranked.
  static final RegExp _anthropicFamily = RegExp(
    r"\b(?:"
    "${_anthropicFamilies.join("|")}"
    r")\b",
  );
  static final RegExp _openAiId = RegExp(r"^gpt-?(\d+(?:\.\d+)*)-?(.*)$");
  static final RegExp _number = RegExp(r"\d+");
  static final RegExp _bracketSuffix = RegExp(r"\[[^\]]*\]");

  /// [variants] strongest first: `ultra`, `max` (or `highest`), `xhigh`,
  /// `high`, `medium` (or `mid`), `low`, `minimal` (or `min`), then
  /// `off`/`none`. Unknown names keep their given order after the known ones.
  static List<String> variants(Iterable<String> variants) {
    final ranked = variants.indexed.toList()
      ..sort((a, b) {
        final byRank = _effortRank(a.$2).compareTo(_effortRank(b.$2));
        return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
      });
    return [for (final entry in ranked) entry.$2];
  }

  /// The variant a backend implies by listing it first, for a catalog that
  /// declares no default of its own. `none` is a backend spelling of "no
  /// variant" that clients never offer, so it is skipped: declaring it would
  /// leave the model with an invalid default and fall through to whichever
  /// level sorted strongest.
  static String? backendDefault(Iterable<String> variants) =>
      variants.where((variant) => variant != "none").firstOrNull;

  /// [models] strongest first. Ranked vendors group in order of first
  /// appearance; within a vendor, newest generation first, then the tier
  /// (Fable, Opus, Sonnet, Haiku; Astra, Sol, Terra, Luna, then the bare
  /// model, then other suffixes such as Mini), then the fuller version, then
  /// the given order. Unranked models follow in the given order.
  static List<T> models<T>(List<T> models, {required String Function(T model) idOf}) {
    final entries = [
      for (final (index, model) in models.indexed) (index: index, model: model, rank: _rank(id: idOf(model))),
    ];
    final vendors = <_Vendor>[];
    for (final entry in entries) {
      if (entry.rank case final rank? when !vendors.contains(rank.vendor)) vendors.add(rank.vendor);
    }
    entries.sort((a, b) {
      final aRank = a.rank;
      final bRank = b.rank;
      if (aRank == null || bRank == null) {
        if (aRank == null && bRank == null) return a.index.compareTo(b.index);
        return aRank == null ? 1 : -1;
      }
      final byVendor = vendors.indexOf(aRank.vendor).compareTo(vendors.indexOf(bRank.vendor));
      if (byVendor != 0) return byVendor;
      final byGeneration = bRank.generation.compareTo(aRank.generation);
      if (byGeneration != 0) return byGeneration;
      final byTier = aRank.tier.compareTo(bRank.tier);
      if (byTier != 0) return byTier;
      final byVersion = _compareVersions(a: bRank.version, b: aRank.version);
      return byVersion != 0 ? byVersion : a.index.compareTo(b.index);
    });
    return [for (final entry in entries) entry.model];
  }

  static int _effortRank(String variant) {
    final normalized = variant.trim().toLowerCase();
    final rank = _effortLadder.indexWhere((aliases) => aliases.contains(normalized));
    return rank < 0 ? _effortLadder.length : rank;
  }

  /// The family an OpenAI model id names through its suffix, in display case
  /// (`gpt-5.6-sol` is `Sol`, `gpt-5.6-codex-mini` is `Codex Mini`). Null for
  /// a bare id (`gpt-5.5`) or one that is not `gpt-<version>…`
  /// (`gpt-default`). Reads the id the way the strength order does, so the
  /// family and the ranking cannot disagree.
  static String? openAiFamily(String id) {
    final suffix = _openAiParts(bare: _bareId(id))?.suffix;
    if (suffix == null || suffix.isEmpty) return null;
    return [
      for (final word in suffix.split("-"))
        if (word.isNotEmpty) "${word[0].toUpperCase()}${word.substring(1)}",
    ].join(" ");
  }

  /// [id] lowercased, without a namespace prefix (`anthropic/…`,
  /// `opencode-go:…`) or a context-window suffix (`opus[1m]`).
  static String _bareId(String id) {
    final bare = id.trim().toLowerCase().replaceAll(_bracketSuffix, "");
    final namespaceEnd = bare.lastIndexOf(RegExp("[/:]"));
    return namespaceEnd >= 0 ? bare.substring(namespaceEnd + 1) : bare;
  }

  /// The version and suffix of a bare `gpt-<version>[-<suffix>]` id, or null
  /// when [bare] is not one.
  static ({List<int> version, String suffix})? _openAiParts({required String bare}) {
    final match = _openAiId.firstMatch(bare);
    if (match == null) return null;
    return (
      version: [for (final part in (match.group(1) ?? "").split(".")) int.parse(part)],
      suffix: match.group(2) ?? "",
    );
  }

  /// Ranks the model behind [id], or null when its vendor is not recognized.
  static _StrengthRank? _rank({required String id}) {
    final bare = _bareId(id);

    if (_openAiParts(bare: bare) case (:final version, :final suffix)) {
      final tier = suffix.isEmpty
          ? _openAiTiers.length
          : switch (_openAiTiers.indexOf(suffix)) {
              -1 => _openAiTiers.length + 1,
              final known => known,
            };
      return (vendor: _Vendor.openAi, generation: version.first, tier: tier, version: version);
    }
    if (_anthropicFamily.firstMatch(bare) case final match?) {
      // An eight-digit run is the `YYYYMMDD` release suffix API ids carry
      // (`claude-sonnet-4-20250514`), never a version part; including it would
      // rank that snapshot above `claude-sonnet-4-6`.
      final version = [
        for (final number in _number.allMatches(bare))
          if (number.end - number.start != 8) int.parse(bare.substring(number.start, number.end)),
      ];
      return (
        vendor: _Vendor.anthropic,
        generation: version.firstOrNull ?? 0,
        tier: _anthropicFamilies.indexOf(bare.substring(match.start, match.end)),
        version: version,
      );
    }
    return null;
  }

  static int _compareVersions({required List<int> a, required List<int> b}) {
    final parts = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < parts; i++) {
      final aPart = i < a.length ? a[i] : 0;
      final bPart = i < b.length ? b[i] : 0;
      if (aPart != bPart) return aPart.compareTo(bPart);
    }
    return 0;
  }
}

enum _Vendor() {
  anthropic,
  openAi,
}

typedef _StrengthRank = ({_Vendor vendor, int generation, int tier, List<int> version});
