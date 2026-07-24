import "package:flutter/material.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:path/path.dart" as p;
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/constants.dart";
import "../../core/extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";
import "new_folder_dialog.dart";

/// Shows the Add Project modal bottom sheet.
///
/// Presented directly rather than through `showPregoBottomSheet` because the
/// header is not fixed: its title, path subtitle, and back button all follow
/// the folder the browser is showing.
///
/// The [cubit] is passed explicitly so the dialog can call `discoverProject` /
/// `createDirectory` without relying on the widget tree's BlocProvider (which
/// lives in the parent screen).
// ignore: no_slop_linter/prefer_required_named_parameters, shared helper signature used by tests
Future<void> showAddProjectDialog(BuildContext context, ProjectListCubit cubit) {
  // Capture before presenting: inside the route the top inset reads as 0.
  final topInset = MediaQuery.paddingOf(context).top;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // PregoBottomSheet paints the rounded surface; keep the route transparent.
    backgroundColor: Colors.transparent,
    // The sheet caps itself just below the status bar.
    useSafeArea: false,
    builder: (_) => AddProjectDialog(cubit: cubit, topInset: topInset),
  );
}

/// Browses the bridge host's folders and turns one of them into a project.
///
/// The sheet is a single view with two actions over the listing:
/// - **Add as new project** — registers the folder currently being browsed;
/// - **Create new folder** — makes an empty folder here and steps into it, so
///   the user can then add *it*.
@visibleForTesting
class AddProjectDialog extends StatefulWidget {
  final ProjectListCubit cubit;

  /// The status-bar inset captured from the presenting context — the modal
  /// route strips it from the sheet's own MediaQuery.
  final double topInset;

  const AddProjectDialog({required this.cubit, required this.topInset, super.key});

  @override
  State<AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends State<AddProjectDialog> {
  /// The messenger this sheet presents its own messages on — see
  /// [_showSnackBar]. Keyed because it is built below this state, so
  /// `ScaffoldMessenger.of` from here would find the screen's instead.
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey();

  /// The folder the bridge started us in, used to present that full host path
  /// as the header title. It is a starting location, not a navigation boundary.
  String? _startingPath;

  /// The folder being listed. Empty until the first fetch resolves the start.
  String _currentPath = "";

  List<FilesystemSuggestion> _entries = [];
  bool _loading = false;
  bool _hasError = false;
  bool _permissionDenied = false;

  /// Which action is waiting on the bridge, if any. Both actions write to the
  /// same folder, so one at a time — and the button that is working is the one
  /// that shows it.
  _AddProjectAction? _inFlight;

  bool get _isAtStartingPath => _currentPath.isNotEmpty && _currentPath == _startingPath;

  bool get _canNavigateUp =>
      _currentPath.isNotEmpty && widget.cubit.parentHostPath(path: _currentPath) != null;

  @override
  void initState() {
    super.initState();
    _fetchEntries();
  }

  // ---------------------------------------------------------------------------
  // Browsing
  // ---------------------------------------------------------------------------

  Future<void> _fetchEntries() async {
    setState(() {
      _loading = true;
      _hasError = false;
      _permissionDenied = false;
    });

    final requestedPath = _currentPath;
    final outcome = await widget.cubit.fetchFilesystemSuggestions(
      prefix: requestedPath.isEmpty ? null : requestedPath,
    );

    // Stepping in and back out again leaves two listings in flight. Only the
    // one for the folder still being browsed may land: the other would fill the
    // current header with another folder's rows, and tapping one would then
    // navigate somewhere the user is not.
    if (!mounted || requestedPath != _currentPath) return;
    setState(() {
      _loading = false;
      switch (outcome) {
        case FilesystemSuggestionsSuccess(:final suggestions):
          final resolvedPath = suggestions.path;
          // The first fetch has no prefix, so the bridge names the folder it
          // chose. Keep it for presentation while allowing navigation above it.
          if (_currentPath.isEmpty && resolvedPath != null && resolvedPath.isNotEmpty) {
            _currentPath = resolvedPath;
            _startingPath = resolvedPath;
          }
          _entries = suggestions.data;
          _hasError = false;
          _permissionDenied = false;
        case FilesystemSuggestionsPermissionDenied():
          _entries = [];
          _hasError = true;
          _permissionDenied = true;
        case FilesystemSuggestionsError():
          _entries = [];
          _hasError = true;
          _permissionDenied = false;
      }
    });
  }

  void _navigateInto({required String path}) {
    setState(() => _currentPath = path);
    _fetchEntries();
  }

  void _navigateUp() {
    final parent = widget.cubit.parentHostPath(path: _currentPath);
    if (parent == null) return;
    setState(() => _currentPath = parent);
    _fetchEntries();
  }

  // ---------------------------------------------------------------------------
  // Header labelling
  // ---------------------------------------------------------------------------

  /// The bar's title: the bridge-returned host path at the starting folder, or
  /// the current folder name after navigating away from it.
  String _title({required AppLocalizations loc}) {
    if (_currentPath.isEmpty) return loc.addProject;
    if (_isAtStartingPath) return _currentPath;
    return _hostBasename(_currentPath);
  }

  /// The bar's second line is the full host path after navigating away from the
  /// starting folder. Null there, where the title already shows that path.
  String? _subtitle() {
    if (_isAtStartingPath || _currentPath.isEmpty) return null;
    return _currentPath;
  }

  /// The last segment of a host path. The path comes from the bridge's host,
  /// not the phone's, so both separator styles have to parse — the
  /// platform-local basename would return a Windows path unchanged.
  static String _hostBasename(String path) => p.posix.basename(path.replaceAll(r"\", "/"));

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _dismissDialog() {
    context.pop();
  }

  Future<void> _onAdd({OpenProjectGitAction gitAction = OpenProjectGitAction.promptIfNeeded}) async {
    if (_currentPath.isEmpty) return;
    setState(() => _inFlight = _AddProjectAction.add);

    final outcome = await widget.cubit.discoverProject(
      path: _currentPath,
      gitAction: gitAction,
    );

    if (!mounted) return;
    setState(() => _inFlight = null);

    final loc = context.loc;
    switch (outcome) {
      case OpenProjectOutcome.success:
        // This one outlives the sheet, so it goes to the screen underneath
        // rather than the sheet's own messenger — captured before the pop.
        final messenger = ScaffoldMessenger.of(context);
        _dismissDialog();
        messenger.showSnackBar(
          SnackBar(content: Text(loc.projectDiscovered), duration: kSnackBarDuration),
        );
      case OpenProjectOutcome.gitChoiceRequired:
        final choice = await _showGitChoiceDialog();
        if (!mounted || choice == null) return;
        await _onAdd(gitAction: choice);
      case OpenProjectOutcome.gitSetupIncomplete:
        await _showGitSetupIncompleteDialog();
        if (!mounted) return;
        _dismissDialog();
      case OpenProjectOutcome.permissionDenied:
        _showSnackBar(loc.addProjectPermissionDenied);
      case OpenProjectOutcome.otherError:
        _showSnackBar(loc.projectDiscoverFailed);
    }
  }

  /// Creates a folder here and steps into it. Only the directory is made —
  /// whether it becomes a project is the user's next decision, taken with the
  /// "Add as new project" button now pointing at it.
  Future<void> _onCreateFolder() async {
    final name = await showNewFolderDialog(context: context);
    if (!mounted || name == null) return;

    setState(() => _inFlight = _AddProjectAction.createFolder);
    final outcome = await widget.cubit.createDirectory(parentPath: _currentPath, name: name);
    if (!mounted) return;
    setState(() => _inFlight = null);

    final loc = context.loc;
    switch (outcome) {
      case CreateDirectorySuccess(:final directory):
        _navigateInto(path: directory.path);
      case CreateDirectoryAlreadyExists():
        _showSnackBar(loc.newFolderExists);
      case CreateDirectoryPermissionDenied():
        _showSnackBar(loc.addProjectPermissionDenied);
      case CreateDirectoryUnsupported():
        _showSnackBar(loc.newFolderUnsupported);
      case CreateDirectoryError():
        _showSnackBar(loc.newFolderFailed);
    }
  }

  Future<OpenProjectGitAction?> _showGitChoiceDialog() {
    final loc = context.loc;
    return showDialog<OpenProjectGitAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.addProjectEnableGitTitle),
        content: Text(loc.addProjectEnableGitBody),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(OpenProjectGitAction.openWithoutGit),
            child: Text(loc.addProjectContinueWithoutGit),
          ),
          FilledButton(
            onPressed: () => dialogContext.pop(OpenProjectGitAction.initializeGit),
            child: Text(loc.addProjectEnableGit),
          ),
        ],
      ),
    );
  }

  Future<void> _showGitSetupIncompleteDialog() {
    final loc = context.loc;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(loc.addProjectGitSetupIncompleteTitle),
          content: Text(loc.addProjectGitSetupIncompleteBody),
          actions: [
            FilledButton(
              onPressed: () => dialogContext.pop(),
              child: Text(loc.addProjectGitSetupIncompleteAcknowledge),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows [message] over the sheet, on the messenger the sheet hosts itself.
  ///
  /// The screen's messenger presents inside the screen's scaffold, which this
  /// modal route covers — a message raised while the sheet is open would be
  /// painted underneath it and never seen. Messages that outlive the sheet
  /// still belong to the screen: see [_onAdd]'s success case.
  void _showSnackBar(String message) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), duration: kSnackBarDuration),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    // The listing scrolls inside the body, so the body needs a bounded height.
    // Take the whole sheet: the browser keeps one height while folders of
    // different lengths come and go, instead of the sheet resizing under the
    // user's thumb as they navigate.
    final bodyHeight = MediaQuery.heightOf(context) - widget.topInset - PregoBottomSheet.contentTopInset;

    return PregoBottomSheet(
      title: _title(loc: loc),
      subtitle: _subtitle(),
      // The header is a nav bar for the folder being browsed, not a headline
      // for the sheet — so the leading-aligned title/path variant.
      alignment: PregoSheetTitleAlignment.start,
      topInset: widget.topInset,
      onBack: _canNavigateUp ? _navigateUp : null,
      onClose: _dismissDialog,
      // Full-bleed body; the banner, rows, and action menu pad themselves.
      contentPadding: EdgeInsetsDirectional.zero,
      // The action menu clears the home indicator itself, so its background
      // reaches the bottom edge instead of stopping above it.
      handleBottomSafeArea: false,
      child: SizedBox(
        height: bodyHeight,
        // The sheet hosts its own messenger, so the messages it raises present
        // over it instead of behind the modal route: see [_showSnackBar]. The
        // scaffold is what that messenger presents into — transparent, so the
        // sheet keeps painting its own surface, and not keyboard-aware, since
        // nothing here is typed into (naming happens in its own sheet).
        child: ScaffoldMessenger(
          key: _messengerKey,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: false,
            // Transparent Material so the rows' ink paints on top of the sheet
            // surface instead of behind it on the modal's transparent Material.
            body: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  const _FilesystemAccessBanner(),
                  Expanded(
                    // The listing runs to the bottom edge and the actions float
                    // over it, so folders scroll behind them and dissolve into
                    // the menu's fade rather than stopping at a hard edge.
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _buildListing(
                            loc: loc,
                            bottomInset: _ActionMenu.reservedExtent(context: context),
                          ),
                        ),
                        PositionedDirectional(
                          start: 0,
                          end: 0,
                          bottom: 0,
                          child: _ActionMenu(
                            onAdd: _inFlight != null || _currentPath.isEmpty ? null : _onAdd,
                            onCreateFolder: _inFlight != null || _currentPath.isEmpty ? null : _onCreateFolder,
                            inFlight: _inFlight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// [bottomInset] is the space the floating action menu covers: scrolling
  /// content pads past it so the last folder clears the buttons, and the states
  /// that centre their content centre in what is left above them.
  Widget _buildListing({required AppLocalizations loc, required double bottomInset}) {
    if (_loading) {
      return _FolderListSkeleton(semanticLabel: loc.addProject);
    }
    if (_hasError) {
      return Padding(
        padding: EdgeInsetsDirectional.only(bottom: bottomInset),
        child: _BrowseError(
          permissionDenied: _permissionDenied,
          onRetry: _fetchEntries,
        ),
      );
    }
    if (_entries.isEmpty) {
      return Padding(
        padding: EdgeInsetsDirectional.only(bottom: bottomInset),
        child: Center(
          child: Text(
            loc.emptyDirectory,
            style: context.prego.textTheme.textSm.regular.copyWith(
              color: context.prego.colors.textSecondary,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsetsDirectional.only(bottom: bottomInset),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _FolderTile(
          entry: entry,
          onTap: () => _navigateInto(path: entry.path),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Folder rows
// ---------------------------------------------------------------------------

/// One folder in the browser: its name, a tag when it already holds a git
/// repository, and a chevron into it.
class _FolderTile extends StatelessWidget {
  final FilesystemSuggestion entry;
  final VoidCallback onTap;

  const _FolderTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: prego.colors.borderTertiary)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PregoSpacing.xl,
                vertical: PregoSpacing.lg,
              ),
              child: Row(
                children: [
                  // The name block claims the row and lays its parts out from
                  // the start, leaving the slack between the tag and the
                  // chevron rather than after the chevron.
                  Expanded(
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            TablerSolid.folder,
                            size: _folderIconSize,
                            color: prego.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: PregoSpacing.sm),
                        // Yields to the tag, so a long folder name ellipsizes
                        // instead of pushing the tag off the row.
                        Flexible(
                          child: Text(
                            entry.name,
                            style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.isGitRepo) ...[
                          const SizedBox(width: PregoSpacing.lg),
                          // The bridge reports only that a repository is
                          // present, so the label stays "Git" even though the
                          // glyph is GitHub's.
                          PregoTag(icon: TablerSolid.brand_github, label: loc.gitRepoBadge),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: PregoSpacing.md),
                  ExcludeSemantics(
                    child: Icon(
                      TablerLight.chevron_right,
                      size: _chevronSize,
                      color: prego.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The listing's loading state: the row geometry with the names replaced by
/// bars, so nothing jumps when the folders land.
class _FolderListSkeleton extends StatelessWidget {
  const _FolderListSkeleton({required this.semanticLabel});

  final String semanticLabel;

  /// Name-bar widths cycled across rows so the placeholder does not read as a
  /// stripe pattern.
  static const List<double> _nameWidths = [96, 140, 112, 168, 88, 124];

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return PregoShimmer(
      semanticLabel: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final width in _nameWidths)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PregoSpacing.xl,
                vertical: PregoSpacing.lg,
              ),
              child: Row(
                children: [
                  // The chrome the row would show anyway is drawn, not faked:
                  // only the name is still loading.
                  Icon(TablerSolid.folder, size: _folderIconSize, color: prego.colors.textDisabled),
                  const SizedBox(width: PregoSpacing.sm),
                  SizedBox(
                    height: _nameLineHeight,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: PregoSkeletonBar(height: 20, width: width),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The listing's failure state — the folder could not be read, either because
/// the host denied access or because the bridge could not list it.
class _BrowseError extends StatelessWidget {
  const _BrowseError({required this.permissionDenied, required this.onRetry});

  final bool permissionDenied;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.x4l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: PregoSpacing.lg,
          children: [
            Icon(
              permissionDenied ? TablerRegular.lock : TablerRegular.alert_circle,
              size: _errorIconSize,
              color: prego.colors.fgErrorPrimary,
            ),
            Text(
              permissionDenied ? loc.fetchDirectoryPermissionDenied : loc.fetchDirectoryFailed,
              textAlign: TextAlign.center,
              style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.fgErrorPrimary),
            ),
            PregoButtonsSolid(
              label: loc.fetchDirectoryRetry,
              leadingIcon: TablerRegular.refresh,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.md,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action menu
// ---------------------------------------------------------------------------

/// The sheet's two actions, floating over the listing at the bottom edge.
///
/// There is no strip: the sheet's own background fades up behind the buttons so
/// folders dissolve as they scroll past — the same treatment the chat composer
/// uses (`PromptInput`), and the mirror of the scroll-edge fade the sheet header
/// paints at the top.
class _ActionMenu extends StatelessWidget {
  const _ActionMenu({
    required this.onAdd,
    required this.onCreateFolder,
    required this.inFlight,
  });

  /// Null while an action is in flight or before the browser knows its folder.
  final VoidCallback? onAdd;

  /// Null while an action is in flight or before the browser knows its folder.
  final VoidCallback? onCreateFolder;

  /// Which action is waiting on the bridge, so that button — and only that one
  /// — spins.
  final _AddProjectAction? inFlight;

  /// Clear space above the buttons, where the fade starts.
  static const double _fadeExtent = PregoSpacing.x5l;

  /// Height of the labelled [PregoButtonsSolid] at [PregoButtonsSolidSize.xl],
  /// per that size's own definition: a 24px `text-md` line between 16px of
  /// padding. It is the taller of the two buttons — the icon-only one is 52 —
  /// so it sets the row's height. Stated rather than measured so the listing can
  /// reserve the menu's height without a layout round-trip; at a text scale
  /// large enough to grow the button past it, the fade absorbs the difference.
  static const double _buttonExtent = 56;

  /// How much of the listing's bottom the menu covers, for the scroll inset
  /// that keeps the last folder clear of the buttons.
  static double reservedExtent({required BuildContext context}) =>
      _fadeExtent + _buttonExtent + PregoSpacing.x3l + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final surface = prego.colors.bgSurface1;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      // One fade across the whole menu, settling only at the screen's bottom
      // edge — the chat composer's scrim, mirrored. Same-hue (surface -> alpha
      // 0) rather than Colors.transparent, so the listing never dissolves
      // through a muddy tint.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [surface.withValues(alpha: 0), surface],
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          top: _fadeExtent,
          start: PregoSpacing.xl,
          end: PregoSpacing.xl,
          bottom: PregoSpacing.x3l + bottomSafe,
        ),
        child: Row(
          spacing: PregoSpacing.xl,
          children: [
            // Icon-only, so the label it drops travels in its semantics.
            Semantics(
              label: loc.createNewFolder,
              child: PregoButtonsSolid.iconOnly(
                leadingIcon: TablerRegular.folder_plus,
                hierarchy: PregoButtonsSolidHierarchy.secondary,
                size: PregoButtonsSolidSize.xl,
                isLoading: inFlight == _AddProjectAction.createFolder,
                onPressed: onCreateFolder,
              ),
            ),
            Expanded(
              child: PregoButtonsSolid(
                label: loc.addAsNewProject,
                leadingIcon: TablerRegular.plus,
                hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                size: PregoButtonsSolidSize.xl,
                fullWidth: true,
                isLoading: inFlight == _AddProjectAction.add,
                onPressed: onAdd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline warning shown at the top of the Add Project sheet when the bridge
/// reported degraded host filesystem access (e.g. macOS Full Disk Access not
/// granted to the terminal running the bridge). It is scoped to this sheet —
/// where the user is browsing directories — rather than shown app-wide, since
/// it is only actionable here.
class _FilesystemAccessBanner extends StatelessWidget {
  const _FilesystemAccessBanner();

  @override
  Widget build(BuildContext context) {
    final connectionService = GetIt.instance<ConnectionService>();
    return StreamBuilder<ConnectionStatus>(
      stream: connectionService.status,
      initialData: connectionService.currentStatus,
      builder: (context, snapshot) {
        final status = snapshot.data;
        // COMPATIBILITY 2026-06-27 (v1.2.0): Old bridges omit filesystem-access state. Remove the null fallback when HealthResponse makes it non-null.
        final degraded = status is ConnectionConnected && (status.health.filesystemAccessDegraded ?? false);
        if (!degraded) return const SizedBox.shrink();

        final loc = context.loc;
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            PregoSpacing.xl,
            0,
            PregoSpacing.xl,
            PregoSpacing.md,
          ),
          // Purely informational: the connection is healthy, but the bridge's
          // host process lacks permission to read some directories. The user
          // resolves this on their Mac, so there is no in-app action here.
          child: PregoInlineAlertsNotifications(
            type: PregoInlineAlertsNotificationsType.warning,
            title: loc.filesystemAccessDegradedTitle,
            supportingText: loc.filesystemAccessDegradedBody,
            icon: TablerRegular.folder_x,
          ),
        );
      },
    );
  }
}

/// The sheet's two bridge-bound actions, so the one that is running can be told
/// apart from the one that is merely blocked while it runs.
enum _AddProjectAction { add, createFolder }

const double _folderIconSize = 16;
const double _chevronSize = 16;
const double _errorIconSize = 48;

/// The line box a folder name renders into (16/24 text), so the skeleton holds
/// the row's shape without re-deriving it from text it does not draw.
const double _nameLineHeight = 24;
