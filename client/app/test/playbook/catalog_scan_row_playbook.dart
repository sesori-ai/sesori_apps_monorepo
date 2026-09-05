import "dart:async";
import "dart:math" as math;

import "package:flutter/widgets.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";
import "package:widgetbook/widgetbook.dart";

void main() {
  runApp(const CatalogScanRowPlaybook());
}

const _playbookHeader = "Sesori mobile component playbook";
const _nativeInitialRoute =
    "/?path=mobile/deep-scan-row/in-action-%C2%B7-pull-to-scan&preview&theme={name:Prego%20dark}";

final _lightTheme = _buildPregoTheme(designSystem: PregoDesignSystem.light);
final _darkTheme = _buildPregoTheme(designSystem: PregoDesignSystem.dark);

material.ThemeData _buildPregoTheme({required PregoDesignSystem designSystem}) => material.ThemeData(
  colorScheme: designSystem.colors.toFlutterColorScheme(),
  textTheme: designSystem.textTheme.asFlutterTextTheme(),
  fontFamily: PregoTextTheme.fontFamily,
  fontFamilyFallback: PregoTextTheme.fontFamilyFallback,
  extensions: [designSystem],
);

/// A dev-only Widgetbook that renders the shared production scan row.
///
/// It stays in `test/playbook` because the shared design catalog intentionally
/// depends only on PREGO. This fixture consumes the public `sesori_app_ui`
/// surface plus core scan state without recreating the widget.
class const CatalogScanRowPlaybook({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      // A native simulator has no URL fragment to select a use case, so open
      // directly into the real interaction. Web URLs override this route and
      // retain the full matrix, state picker, addons, and knobs.
      initialRoute: _nativeInitialRoute,
      appBuilder: _buildLocalizedPregoApp,
      addons: [
        _buildPregoThemeAddon(),
        ViewportAddon(const [Viewports.none, IosViewports.iPhone13, AndroidViewports.samsungGalaxyS20]),
        AlignmentAddon(),
      ],
      directories: [
        WidgetbookFolder(
          name: "Mobile",
          isInitiallyExpanded: true,
          children: [buildCatalogScanRowComponent()],
        ),
      ],
      header: const Text(_playbookHeader),
      headerPadding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
    );
  }
}

// ignore: no_slop_linter/prefer_required_named_parameters, Widgetbook AppBuilder signature
Widget _buildLocalizedPregoApp(BuildContext _, Widget child) {
  return material.MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: material.Material(color: _lightTheme.scaffoldBackgroundColor, child: child),
  );
}

ThemeAddon<material.ThemeData> _buildPregoThemeAddon() => ThemeAddon<material.ThemeData>(
  themes: [
    WidgetbookTheme(name: "Prego light", data: _lightTheme),
    WidgetbookTheme(name: "Prego dark", data: _darkTheme),
  ],
  themeBuilder: (context, theme, child) => material.Theme(
    data: theme,
    child: ColoredBox(color: theme.scaffoldBackgroundColor, child: child),
  ),
);

WidgetbookComponent buildCatalogScanRowComponent() => WidgetbookComponent(
  name: "Deep scan row",
  useCases: [
    WidgetbookUseCase(name: "In action · Pull to scan", builder: _buildInAction),
    WidgetbookUseCase(name: "All states and variants", builder: _buildStateMatrix),
    WidgetbookUseCase(name: "State picker", builder: _buildPlayground),
    ...catalogScanRowScenarios.map(
      (scenario) => WidgetbookUseCase(
        name: scenario.name,
        builder: (context) => _PlaybookSurface(
          child: _ScenarioFrame(scenario: scenario, reducedMotion: false),
        ),
      ),
    ),
  ],
);

Widget _buildInAction(BuildContext context) {
  final selection = context.knobs.object.dropdown(
    label: "Example mode",
    options: catalogScanDemoSelections,
    initialOption: catalogScanDemoSelections.first,
    labelBuilder: (value) => value.label,
  );
  final reducedMotion = context.knobs.boolean(label: "Reduce motion");

  return _PlaybookSurface(
    alignment: Alignment.topCenter,
    child: LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: math.min(520, constraints.maxWidth),
        height: constraints.maxHeight,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
          child: CatalogScanRowInActionExample(selection: selection),
        ),
      ),
    ),
  );
}

Widget _buildStateMatrix(BuildContext context) {
  final reducedMotion = context.knobs.boolean(label: "Reduce motion");
  return _PlaybookSurface(
    alignment: Alignment.topCenter,
    child: LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final availableWidth = math.max(0.0, constraints.maxWidth - 48);
        final columnCount = availableWidth >= 920 ? 2 : 1;
        final cardWidth = math.min(520.0, (availableWidth - (columnCount - 1) * gap) / columnCount);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final scenario in catalogScanRowScenarios)
                SizedBox(
                  width: cardWidth,
                  child: _ScenarioFrame(scenario: scenario, reducedMotion: reducedMotion),
                ),
            ],
          ),
        );
      },
    ),
  );
}

Widget _buildPlayground(BuildContext context) {
  final scenario = context.knobs.object.dropdown(
    label: "State / variant",
    options: catalogScanRowScenarios,
    initialOption: catalogScanRowScenarios[1],
    labelBuilder: (value) => value.name,
  );
  final reducedMotion = context.knobs.boolean(label: "Reduce motion");

  return _PlaybookSurface(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: _ScenarioFrame(scenario: scenario, reducedMotion: reducedMotion),
    ),
  );
}

enum CatalogScanRowAction() {
  none,
  cancel,
  dismiss,
}

class const CatalogScanRowScenario({
  required final String id,
  required final String name,
  required final String description,
  required final CatalogRescanState scan,
  required final CatalogScanRowAction action,
});

/// Meaningful rendering branches of [CatalogScanRow].
///
/// Counts are curated to exercise clause omission and delta-versus-total copy;
/// fields that have no visual effect are not expanded into a Cartesian matrix.
const catalogScanRowScenarios = <CatalogScanRowScenario>[
  CatalogScanRowScenario(
    id: "idle",
    name: "Idle / Collapsed",
    description: "No scan to report. The production row occupies zero height.",
    scan: CatalogRescanState.idle(),
    action: CatalogScanRowAction.none,
  ),
  CatalogScanRowScenario(
    id: "starting",
    name: "Starting / Awaiting progress",
    description: "The request was dispatched, but no harness has reported yet.",
    scan: CatalogRescanState.starting(pluginIds: {"codex", "opencode"}),
    action: CatalogScanRowAction.cancel,
  ),
  CatalogScanRowScenario(
    id: "running-zero",
    name: "Running / Zero sessions",
    description: "Codex is active but has not reported a session yet.",
    scan: CatalogRescanState.running(
      activePluginName: "Codex",
      sessionsSeen: 0,
      pluginIds: {"codex", "opencode"},
    ),
    action: CatalogScanRowAction.cancel,
  ),
  CatalogScanRowScenario(
    id: "running-singular",
    name: "Running / One session",
    description: "The singular live-count branch is visible while Codex scans.",
    scan: CatalogRescanState.running(
      activePluginName: "Codex",
      sessionsSeen: 1,
      pluginIds: {"codex", "opencode"},
    ),
    action: CatalogScanRowAction.cancel,
  ),
  CatalogScanRowScenario(
    id: "running-large-count",
    name: "Running / Large count",
    description: "A long-running scan with a representative three-digit count.",
    scan: CatalogRescanState.running(
      activePluginName: "Claude Code",
      sessionsSeen: 148,
      pluginIds: {"claude-code", "codex", "opencode"},
    ),
    action: CatalogScanRowAction.cancel,
  ),
  CatalogScanRowScenario(
    id: "success-delta-singular",
    name: "Success delta / One session + project",
    description: "Both localized delta clauses use their singular branch.",
    scan: CatalogRescanState.succeeded(
      harnessCount: 2,
      counts: CatalogRescanCounts.delta(newProjects: 1, newSessions: 1),
    ),
    action: CatalogScanRowAction.dismiss,
  ),
  CatalogScanRowScenario(
    id: "success-delta-sessions",
    name: "Success delta / Sessions only",
    description: "New sessions landed in projects that were already known.",
    scan: CatalogRescanState.succeeded(
      harnessCount: 2,
      counts: CatalogRescanCounts.delta(newProjects: 0, newSessions: 3),
    ),
    action: CatalogScanRowAction.dismiss,
  ),
  CatalogScanRowScenario(
    id: "success-delta-projects",
    name: "Success delta / Projects only",
    description: "New projects landed without any new session to count.",
    scan: CatalogRescanState.succeeded(
      harnessCount: 2,
      counts: CatalogRescanCounts.delta(newProjects: 2, newSessions: 0),
    ),
    action: CatalogScanRowAction.dismiss,
  ),
  CatalogScanRowScenario(
    id: "success-delta-both",
    name: "Success delta / Sessions + projects",
    description: "Both new-session and new-project clauses are visible.",
    scan: CatalogRescanState.succeeded(
      harnessCount: 2,
      counts: CatalogRescanCounts.delta(newProjects: 2, newSessions: 5),
    ),
    action: CatalogScanRowAction.dismiss,
  ),
  CatalogScanRowScenario(
    id: "success-delta-empty",
    name: "Success delta / Nothing new",
    description: "The scan completed and reported a real zero delta.",
    scan: CatalogRescanState.succeeded(
      harnessCount: 2,
      counts: CatalogRescanCounts.delta(newProjects: 0, newSessions: 0),
    ),
    action: CatalogScanRowAction.dismiss,
  ),
  CatalogScanRowScenario(
    id: "success-totals-singular",
    name: "Success totals / One session + project",
    description: "Both localized total-count clauses use their singular branch.",
    scan: CatalogRescanState.succeeded(
      harnessCount: 2,
      counts: CatalogRescanCounts.totals(projects: 1, sessions: 1),
    ),
    action: CatalogScanRowAction.dismiss,
  ),
  CatalogScanRowScenario(
    id: "success-totals-sessions",
    name: "Success totals / Sessions only",
    description: "The bridge omitted deltas, so published sessions are reported as totals.",
    scan: CatalogRescanState.succeeded(
      harnessCount: 2,
      counts: CatalogRescanCounts.totals(projects: 0, sessions: 148),
    ),
    action: CatalogScanRowAction.dismiss,
  ),
  CatalogScanRowScenario(
    id: "success-totals-projects",
    name: "Success totals / Projects only",
    description: "Only the published-project total is non-zero.",
    scan: CatalogRescanState.succeeded(
      harnessCount: 2,
      counts: CatalogRescanCounts.totals(projects: 12, sessions: 0),
    ),
    action: CatalogScanRowAction.dismiss,
  ),
  CatalogScanRowScenario(
    id: "success-totals-both",
    name: "Success totals / Sessions + projects",
    description: "Published totals are shown without implying that they are new.",
    scan: CatalogRescanState.succeeded(
      harnessCount: 2,
      counts: CatalogRescanCounts.totals(projects: 12, sessions: 148),
    ),
    action: CatalogScanRowAction.dismiss,
  ),
  CatalogScanRowScenario(
    id: "success-totals-empty",
    name: "Success totals / Empty catalog",
    description: "The totals branch reported neither sessions nor projects.",
    scan: CatalogRescanState.succeeded(
      harnessCount: 2,
      counts: CatalogRescanCounts.totals(projects: 0, sessions: 0),
    ),
    action: CatalogScanRowAction.dismiss,
  ),
  CatalogScanRowScenario(
    id: "partly-failed",
    name: "Partial failure",
    description: "Some harnesses completed and one could not be scanned.",
    scan: CatalogRescanState.partlyFailed(succeededCount: 2, failedCount: 1),
    action: CatalogScanRowAction.dismiss,
  ),
  CatalogScanRowScenario(
    id: "failed",
    name: "All failed",
    description: "Every harness failed; the bounded copy points to the bridge log.",
    scan: CatalogRescanState.failed(harnessCount: 2),
    action: CatalogScanRowAction.dismiss,
  ),
  CatalogScanRowScenario(
    id: "unsupported",
    name: "Unsupported bridge",
    description: "The connected bridge predates catalog rescanning.",
    scan: CatalogRescanState.unsupported(),
    action: CatalogScanRowAction.dismiss,
  ),
  CatalogScanRowScenario(
    id: "no-harness",
    name: "No harness ready",
    description: "No connected harness can be scanned from this surface.",
    scan: CatalogRescanState.noHarness(),
    action: CatalogScanRowAction.dismiss,
  ),
];

/// What the action example should do.
///
/// The gesture branch owns a changing scan, while a static preview carries one
/// curated scenario. Keeping those as separate variants means the Widgetbook
/// knob cannot accidentally request both behaviours at once.
sealed class const CatalogScanDemoSelection() {
  String get label;
}

final class const CatalogScanGestureDemo() extends CatalogScanDemoSelection {
  @override
  String get label => "Gesture demo · automatic success";
}

final class const CatalogScanStaticPreview({required final CatalogScanRowScenario scenario})
    extends CatalogScanDemoSelection {
  @override
  String get label => "Preview · ${scenario.name}";
}

final catalogScanDemoSelections = <CatalogScanDemoSelection>[
  const CatalogScanGestureDemo(),
  for (final scenario in catalogScanRowScenarios) CatalogScanStaticPreview(scenario: scenario),
];

final _exampleProjects = [
  (
    project: _exampleProject(
      id: "landing",
      name: "Landing",
      path: "/Users/developer/Documents/Landing",
      age: const Duration(hours: 4),
    ),
    activeSessions: 0,
    unseen: false,
  ),
  (
    project: _exampleProject(
      id: "sesori-mobile",
      name: "sesori_apps_monorepo",
      path: "/Users/developer/Documents/sesori_apps_monorepo",
      age: const Duration(days: 1),
    ),
    activeSessions: 1,
    unseen: false,
  ),
  (
    project: _exampleProject(
      id: "silvia",
      name: "SilviaMonorepo",
      path: "/Users/developer/Documents/SilviaMonorepo",
      age: const Duration(days: 7),
      unseen: true,
    ),
    activeSessions: 0,
    unseen: true,
  ),
  (
    project: _exampleProject(
      id: "bridge",
      name: "Bridge",
      path: "/Users/developer/Projects/sesori/bridge",
      age: const Duration(days: 8),
    ),
    activeSessions: 0,
    unseen: false,
  ),
  (
    project: _exampleProject(
      id: "design-catalog",
      name: "Design catalog",
      path: "/Users/developer/Projects/sesori/design_catalog",
      age: const Duration(days: 12),
    ),
    activeSessions: 0,
    unseen: false,
  ),
  (
    project: _exampleProject(
      id: "desktop",
      name: "Desktop",
      path: "/Users/developer/Projects/sesori/desktop",
      age: const Duration(days: 16),
    ),
    activeSessions: 0,
    unseen: false,
  ),
];

ProjectSummary _exampleProject({
  required String id,
  required String name,
  required String path,
  required Duration age,
  bool unseen = false,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return ProjectSummary(
    id: id,
    name: name,
    path: path,
    time: ProjectTime(
      created: now - const Duration(days: 120).inMilliseconds,
      updated: now - age.inMilliseconds,
    ),
    hasUnseenChanges: unseen,
  );
}

/// A production-faithful Projects surface around [CatalogScanRow].
///
/// This intentionally uses the same Prego navigation scaffold, project tiles,
/// refresh control, and scan-row placement as the real screen. Pull normally
/// to refresh the projects; keep pulling after the caption appears to cross the
/// real deep-refresh threshold and start the timed scan sequence. Widgetbook's
/// Example mode knob freezes the row in any curated state without adding a
/// forced-state API to production code.
class const CatalogScanRowInActionExample({
  super.key,
  required final CatalogScanDemoSelection selection,
}) extends StatefulWidget {
  @override
  State<CatalogScanRowInActionExample> createState() => _CatalogScanRowInActionExampleState();
}

class _CatalogScanRowInActionExampleState() extends State<CatalogScanRowInActionExample> {
  final _timers = <Timer>[];
  late CatalogRescanState _scan = _scanFor(widget.selection);

  @override
  void didUpdateWidget(CatalogScanRowInActionExample oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection == widget.selection) return;
    _cancelTimers();
    _scan = _scanFor(widget.selection);
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection;
    return PregoGlassScaffold(
      key: const Key("catalog-scan-in-action-screen"),
      title: "Projects",
      titleMode: PregoTopNavigationTitleMode.backLeading,
      leadingTitleEmphasis: PregoNavLeadingTitleEmphasis.prominent,
      automaticallyImplyLeading: false,
      subtitle: const PregoNavSubtitle(
        text: "MacBook-Pro",
        icon: TablerRegular.device_laptop,
        status: PregoNavStatus.online,
      ),
      actions: [
        PregoButtonsIconGlass(
          icon: VESPRSolid.gear,
          semanticLabel: "Settings",
          onPressed: () {},
        ),
      ],
      floatingActionButton: PregoButtonsIconGlass(
        icon: TablerRegular.folder_plus,
        size: PregoButtonsIconGlassSize.xl,
        iconSize: 22,
        semanticLabel: "Add project",
        onPressed: () {},
      ),
      onRefresh: _refreshProjects,
      deepRefresh: switch (selection) {
        CatalogScanGestureDemo() => CatalogScanRow.deepRefresh(context: context, onStart: _startScan),
        CatalogScanStaticPreview() => null,
      },
      slivers: [
        SliverToBoxAdapter(
          child: CatalogScanRow(scan: _scan, onCancel: _cancelScan, onDismiss: _dismissScan),
        ),
        SliverList.list(
          children: [
            for (final example in _exampleProjects)
              ExcludeSemantics(
                child: IgnorePointer(
                  child: ProjectTile(
                    project: example.project,
                    activeSessions: example.activeSessions,
                    unseen: example.unseen,
                    onOpen: ({required context, required project, required displayName}) {},
                  ),
                ),
              ),
          ],
        ),
        SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 96)),
      ],
    );
  }

  Future<void> _refreshProjects() => Future<void>.delayed(const Duration(milliseconds: 650));

  void _startScan() {
    if (widget.selection is! CatalogScanGestureDemo) return;
    _cancelTimers();
    setState(() {
      _scan = const CatalogRescanState.starting(pluginIds: {"claude-code", "codex", "opencode"});
    });
    _schedule(
      const Duration(milliseconds: 650),
      const CatalogRescanState.running(
        activePluginName: "Codex",
        sessionsSeen: 0,
        pluginIds: {"claude-code", "codex", "opencode"},
      ),
    );
    _schedule(
      const Duration(milliseconds: 1400),
      const CatalogRescanState.running(
        activePluginName: "Codex",
        sessionsSeen: 3,
        pluginIds: {"claude-code", "codex", "opencode"},
      ),
    );
    _schedule(
      const Duration(milliseconds: 2200),
      const CatalogRescanState.running(
        activePluginName: "OpenCode",
        sessionsSeen: 8,
        pluginIds: {"claude-code", "codex", "opencode"},
      ),
    );
    _schedule(
      const Duration(milliseconds: 3100),
      const CatalogRescanState.succeeded(
        harnessCount: 3,
        counts: CatalogRescanCounts.delta(newProjects: 2, newSessions: 5),
      ),
    );
  }

  void _schedule(Duration delay, CatalogRescanState scan) {
    _timers.add(
      Timer(delay, () {
        if (!mounted || widget.selection is! CatalogScanGestureDemo) return;
        setState(() => _scan = scan);
      }),
    );
  }

  void _cancelScan() {
    if (widget.selection is! CatalogScanGestureDemo) return;
    _cancelTimers();
    setState(() => _scan = const CatalogRescanState.idle());
  }

  void _dismissScan() {
    if (widget.selection is! CatalogScanGestureDemo) return;
    setState(() => _scan = const CatalogRescanState.idle());
  }

  void _cancelTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }
}

CatalogRescanState _scanFor(CatalogScanDemoSelection selection) => switch (selection) {
  CatalogScanGestureDemo() => const CatalogRescanState.idle(),
  CatalogScanStaticPreview(:final scenario) => scenario.scan,
};

class const _ScenarioFrame({
  required final CatalogScanRowScenario scenario,
  required final bool reducedMotion,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: prego.colors.bgSurface1,
        border: Border.all(color: prego.colors.borderSecondary),
        borderRadius: BorderRadius.circular(PregoRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(scenario.name, style: prego.textTheme.textSm.bold),
            const SizedBox(height: 4),
            Text(
              scenario.description,
              style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
            ),
            const SizedBox(height: 8),
            MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
              child: _InteractiveScenario(scenario: scenario),
            ),
            if (scenario.action == CatalogScanRowAction.none)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
                child: Text(
                  "Collapsed production state · 0 px",
                  style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class const _InteractiveScenario({required final CatalogScanRowScenario scenario}) extends StatefulWidget {
  @override
  State<_InteractiveScenario> createState() => _InteractiveScenarioState();
}

class _InteractiveScenarioState() extends State<_InteractiveScenario> {
  CatalogScanRowAction _lastAction = CatalogScanRowAction.none;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CatalogScanRow(
          scan: widget.scenario.scan,
          onCancel: () => _record(CatalogScanRowAction.cancel),
          onDismiss: () => _record(CatalogScanRowAction.dismiss),
        ),
        if (_lastAction != CatalogScanRowAction.none)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 0),
            child: Text(
              "${_lastAction.name} callback received",
              style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textTertiary),
            ),
          ),
      ],
    );
  }

  void _record(CatalogScanRowAction action) {
    setState(() => _lastAction = action);
  }
}

class const _PlaybookSurface({
  required final Widget child,
  final Alignment alignment = Alignment.center,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.prego.colors.bgSurface2,
    child: Align(alignment: alignment, child: child),
  );
}
