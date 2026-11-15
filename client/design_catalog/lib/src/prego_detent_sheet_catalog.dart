import "dart:async";

import "package:flutter/widgets.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";
import "package:widgetbook/widgetbook.dart";

import "detent_sheet_scenario.dart";

WidgetbookComponent buildPregoDetentSheetComponent() => WidgetbookComponent(
  name: "Detent sheet",
  useCases: [
    WidgetbookUseCase(name: detentSheetUseCaseName, builder: (context) => const DetentSheetPreview()),
  ],
);

/// A synthetic page that streams a line every second, so the recording and the
/// catalog show the page behind the sheet staying live.
class const DetentSheetPreview({super.key}) extends StatefulWidget {
  @override
  State<DetentSheetPreview> createState() => _DetentSheetPreviewState();
}

class _DetentSheetPreviewState() extends State<DetentSheetPreview> {
  late final Timer _ticker;
  int _lines = 12;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _lines++));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  void _open() {
    showPregoDetentSheet<void>(
      context: context,
      builder: (context, scrollController) => _SideChat(scrollController: scrollController),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return material.Scaffold(
      backgroundColor: prego.colors.bgSurface1,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: PregoButtonsSolid(
                label: "Ask a side question",
                size: PregoButtonsSolidSize.md,
                hierarchy: PregoButtonsSolidHierarchy.primary,
                onPressed: _open,
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _lines,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    "Main session line ${index + 1}: the agent keeps working while the sheet is open.",
                    style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class const _SideChat({required final ScrollController scrollController}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Column(
      children: [
        PregoTopNavigationSheets(
          title: "Side question",
          showGrabber: false,
          // ignore: no_slop_linter/avoid_navigator_of, the catalog has no router; pops the sheet's route
          onClose: () => material.Navigator.of(context).pop(),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: 16,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                index.isEven
                    ? "Question ${index ~/ 2 + 1}: what does this step change?"
                    : "Answer ${index ~/ 2 + 1}: a short synthetic reply that wraps onto a second line.",
                style: prego.textTheme.textMd.regular.copyWith(
                  color: index.isEven ? prego.colors.textPrimary : prego.colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: material.TextField(
            decoration: material.InputDecoration(hintText: "Ask a side question", isDense: true),
          ),
        ),
      ],
    );
  }
}
