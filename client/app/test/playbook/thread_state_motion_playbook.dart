import "dart:ui";

import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/testing.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

/// Direct simulator entrypoint using the production indicator and thread row.
void main() => runApp(const ThreadStateMotionPlaybook());

class const ThreadStateMotionPlaybook({super.key}) extends StatefulWidget {
  @override
  State<ThreadStateMotionPlaybook> createState() => _ThreadStateMotionPlaybookState();
}

class _ThreadStateMotionPlaybookState() extends State<ThreadStateMotionPlaybook> {
  bool _dark = true;
  bool _reducedMotion = false;
  bool _working = true;
  bool _showThreads = true;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildPregoThemeData(brightness: Brightness.light),
    darkTheme: buildPregoThemeData(brightness: Brightness.dark),
    themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: _reducedMotion),
      child: child!,
    ),
    home: Builder(builder: _buildScene),
  );

  Widget _buildScene(BuildContext context) {
    final prego = context.prego;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Thread activity", style: prego.textTheme.textLg.medium),
        backgroundColor: prego.colors.bgSurface1.withValues(alpha: 0.8),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: const SizedBox.expand(),
          ),
        ),
      ),
      body: ListView(
        key: const ValueKey("thread-motion-scroll"),
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + kToolbarHeight + 12, 16, 40),
        children: [
          _setting(
            context: context,
            label: "Dark appearance",
            value: _dark,
            onChanged: (value) => setState(() => _dark = value),
          ),
          _setting(
            context: context,
            label: "Reduce motion",
            value: _reducedMotion,
            onChanged: (value) => setState(() => _reducedMotion = value),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(
                child: _sample(context: context, title: "Idle", detail: "Unopened updates", working: false),
              ),
              Expanded(
                child: _sample(context: context, title: "Loading", detail: "Thinking / working", working: true),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text("Loading → idle", style: prego.textTheme.textMd.medium),
          const SizedBox(height: 4),
          Text("Finish a turn, then start again at any point.", style: prego.textTheme.textSm.regular),
          const SizedBox(height: 20),
          Center(
            child: PregoAiLoader(
              key: const ValueKey("replay-detail"),
              size: 80,
              animate: _working,
            ),
          ),
          const SizedBox(height: 12),
          _thread(id: "replay-thread", title: "Polish the thread experience", working: _working),
          const SizedBox(height: 16),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: PregoButtonsSolid(
                  label: "Start working",
                  size: .md,
                  hierarchy: .secondary,
                  onPressed: () => setState(() => _working = true),
                ),
              ),
              Expanded(
                child: PregoButtonsSolid(
                  label: "Finish",
                  size: .md,
                  hierarchy: .primary,
                  onPressed: () => setState(() => _working = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _setting(
            context: context,
            label: "Show thread list",
            value: _showThreads,
            onChanged: (value) => setState(() => _showThreads = value),
          ),
          Text(
            "Scroll the threads beneath the glass header; working sparkles stay synchronized.",
            style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textTertiary),
          ),
          const SizedBox(height: 12),
          if (_showThreads)
            for (var index = 0; index < 18; index++)
              _thread(
                id: "list-thread-$index",
                title: switch (index % 3) {
                  0 => "Review the latest changes",
                  1 => "Explore the next idea",
                  _ => "Refine the details",
                },
                working: index.isEven,
              ),
        ],
      ),
    );
  }

  Widget _sample({
    required BuildContext context,
    required String title,
    required String detail,
    required bool working,
  }) {
    final prego = context.prego;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: prego.colors.bgSurface2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              spacing: 8,
              children: [
                PregoAiLoader(size: 20, animate: working),
                Text(title, style: prego.textTheme.textSm.medium),
              ],
            ),
            const SizedBox(height: 4),
            Text(detail, style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary)),
            const SizedBox(height: 20),
            Center(child: PregoAiLoader(size: 80, animate: working)),
            const SizedBox(height: 12),
            Center(
              child: Text(
                "20 px · 4× detail",
                style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _setting({
    required BuildContext context,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(label, style: context.prego.textTheme.textSm.medium)),
        Semantics(
          label: label,
          child: PregoSwitch(value: value, onChanged: onChanged),
        ),
      ],
    ),
  );

  Widget _thread({required String id, required String title, required bool working}) => SessionTile(
    key: ValueKey(id),
    session: testSession(id: id, title: title, branchName: "main", pluginId: "codex"),
    isArchived: false,
    isActive: working,
    unseen: true,
    onTap: null,
    menuEntries: () => const [],
    onArchive: () {},
    onDelete: () {},
    onToggleUnread: () {},
  );
}
