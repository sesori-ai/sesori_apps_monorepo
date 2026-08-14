import "package:flutter/widgets.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";
import "package:widgetbook/widgetbook.dart";

import "catalog_scenario.dart";
import "catalog_scenarios.dart";

WidgetbookComponent buildPregoSolidButtonComponent() => WidgetbookComponent(
  name: "Solid button",
  useCases: [
    WidgetbookUseCase(name: "Playground", builder: _buildPlayground),
    WidgetbookUseCase(name: "All curated states", builder: _buildStateMatrix),
    ...catalogScenarios.map(
      (scenario) => WidgetbookUseCase(
        name: scenario.name,
        builder: (context) => _ScenarioPreview(scenario: scenario),
      ),
    ),
  ],
);

Widget _buildPlayground(BuildContext context) {
  final label = context.knobs.string(label: "Label", initialValue: "Continue");
  final size = context.knobs.object.dropdown(
    label: "Size",
    options: PregoButtonsSolidSize.values,
    initialOption: PregoButtonsSolidSize.md,
    labelBuilder: (value) => value.name,
  );
  final hierarchy = context.knobs.object.dropdown(
    label: "Hierarchy",
    options: PregoButtonsSolidHierarchy.values,
    initialOption: PregoButtonsSolidHierarchy.primary,
    labelBuilder: (value) => value.name,
  );
  final tone = context.knobs.object.dropdown(
    label: "Tone",
    options: PregoButtonsSolidType.values,
    initialOption: PregoButtonsSolidType.regular,
    labelBuilder: (value) => value.name,
  );
  final state = context.knobs.object.dropdown(
    label: "State",
    options: CatalogButtonState.values,
    initialOption: CatalogButtonState.enabled,
    labelBuilder: (value) => value.name,
  );
  final iconOnly = context.knobs.boolean(label: "Icon only");
  final fullWidth = context.knobs.boolean(label: "Full width");
  final leadingIcon = context.knobs.boolean(label: "Leading icon", initialValue: true);
  final trailingIcon = context.knobs.boolean(label: "Trailing icon");
  final invalidReason = _invalidCombinationReason(hierarchy: hierarchy, tone: tone);

  return _PreviewSurface(
    child: invalidReason == null
        ? _InteractiveButtonPreview(
            label: label,
            size: size,
            hierarchy: hierarchy,
            tone: tone,
            state: state,
            iconOnly: iconOnly,
            fullWidth: fullWidth,
            leadingIcon: leadingIcon ? material.Icons.add : null,
            trailingIcon: trailingIcon ? material.Icons.arrow_forward : null,
          )
        : _InvalidCombinationNotice(message: invalidReason),
  );
}

String? _invalidCombinationReason({
  required PregoButtonsSolidHierarchy hierarchy,
  required PregoButtonsSolidType tone,
}) {
  if (hierarchy == PregoButtonsSolidHierarchy.primaryAlt && tone != PregoButtonsSolidType.regular) {
    return "Primary alt only supports the regular tone.";
  }
  if ((tone == PregoButtonsSolidType.warning || tone == PregoButtonsSolidType.success) &&
      hierarchy != PregoButtonsSolidHierarchy.primary) {
    return "Warning and success tones are only defined for the primary hierarchy.";
  }
  return null;
}

Widget _buildStateMatrix(BuildContext context) => _PreviewSurface(
  alignment: Alignment.topCenter,
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [for (final scenario in catalogScenarios) _ScenarioCard(scenario: scenario)],
    ),
  ),
);

class const _ScenarioPreview({required final CatalogScenario scenario}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _PreviewSurface(child: _ScenarioCard(scenario: scenario));
}

class const _ScenarioCard({required final CatalogScenario scenario}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Container(
      width: 312,
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: prego.colors.bgSurface1,
        border: Border.all(color: prego.colors.borderSecondary),
        borderRadius: BorderRadius.circular(PregoRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(scenario.name, style: prego.textTheme.textSm.bold),
          const SizedBox(height: 4),
          Text(scenario.description, style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary)),
          const SizedBox(height: 16),
          SizedBox(
            width: _fullWidthFor(scenario.content) ? double.infinity : null,
            child: _buildScenarioButton(scenario),
          ),
          const SizedBox(height: 16),
          Text(
            "${scenario.hierarchy.name} · ${scenario.tone.name} · ${scenario.size.name} · ${scenario.state.name}",
            style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

Widget _buildScenarioButton(CatalogScenario scenario) {
  final onPressed = scenario.state == CatalogButtonState.enabled ? () {} : null;
  final isLoading = scenario.state == CatalogButtonState.loading;

  return switch (scenario.content) {
    CatalogButtonIconOnlyContent(:final icon) => PregoButtonsSolid.iconOnly(
      leadingIcon: _iconFor(icon),
      hierarchy: _hierarchyFor(scenario.hierarchy),
      size: _sizeFor(scenario.size),
      onPressed: onPressed,
      isLoading: isLoading,
      type: _toneFor(scenario.tone),
    ),
    CatalogButtonLabelContent(:final fullWidth, :final leadingIcon, :final trailingIcon) => PregoButtonsSolid(
      label: "Continue",
      hierarchy: _hierarchyFor(scenario.hierarchy),
      size: _sizeFor(scenario.size),
      onPressed: onPressed,
      leadingIcon: _optionalIconFor(leadingIcon),
      trailingIcon: _optionalIconFor(trailingIcon),
      isLoading: isLoading,
      type: _toneFor(scenario.tone),
      fullWidth: fullWidth,
    ),
  };
}

bool _fullWidthFor(CatalogButtonContent content) => switch (content) {
  CatalogButtonLabelContent(:final fullWidth) => fullWidth,
  CatalogButtonIconOnlyContent() => false,
};

material.IconData? _optionalIconFor(CatalogButtonIcon? icon) => icon == null ? null : _iconFor(icon);

material.IconData _iconFor(CatalogButtonIcon icon) => switch (icon) {
  CatalogButtonIcon.add => material.Icons.add,
  CatalogButtonIcon.arrowRight => material.Icons.arrow_forward,
  CatalogButtonIcon.trash => material.Icons.delete_outline,
};

PregoButtonsSolidSize _sizeFor(CatalogButtonSize size) => switch (size) {
  .sm => .sm,
  .md => .md,
  .lg => .lg,
  .xl => .xl,
};

PregoButtonsSolidHierarchy _hierarchyFor(CatalogButtonHierarchy hierarchy) => switch (hierarchy) {
  .primary => .primary,
  .primaryAlt => .primaryAlt,
  .secondary => .secondary,
  .tertiary => .tertiary,
  .link => .link,
};

PregoButtonsSolidType _toneFor(CatalogButtonTone tone) => switch (tone) {
  .regular => .regular,
  .destructive => .destructive,
  .warning => .warning,
  .success => .success,
};

class const _InteractiveButtonPreview({
  required final String label,
  required final PregoButtonsSolidSize size,
  required final PregoButtonsSolidHierarchy hierarchy,
  required final PregoButtonsSolidType tone,
  required final CatalogButtonState state,
  required final bool iconOnly,
  required final bool fullWidth,
  required final material.IconData? leadingIcon,
  required final material.IconData? trailingIcon,
}) extends StatefulWidget {
  @override
  State<_InteractiveButtonPreview> createState() => _InteractiveButtonPreviewState();
}

class _InteractiveButtonPreviewState() extends State<_InteractiveButtonPreview> {
  int _pressCount = 0;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final onPressed = widget.state == CatalogButtonState.enabled
        ? () => setState(() {
            _pressCount += 1;
          })
        : null;
    final button = widget.iconOnly
        ? PregoButtonsSolid.iconOnly(
            leadingIcon: widget.leadingIcon ?? material.Icons.add,
            hierarchy: widget.hierarchy,
            size: widget.size,
            onPressed: onPressed,
            isLoading: widget.state == CatalogButtonState.loading,
            type: widget.tone,
          )
        : PregoButtonsSolid(
            label: widget.label,
            hierarchy: widget.hierarchy,
            size: widget.size,
            onPressed: onPressed,
            leadingIcon: widget.leadingIcon,
            trailingIcon: widget.trailingIcon,
            isLoading: widget.state == CatalogButtonState.loading,
            type: widget.tone,
            fullWidth: widget.fullWidth,
          );

    return SizedBox(
      width: widget.fullWidth && !widget.iconOnly ? 320 : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button,
          const SizedBox(height: 16),
          Text("Pressed $_pressCount times", style: prego.textTheme.textXs.medium),
        ],
      ),
    );
  }
}

class const _InvalidCombinationNotice({required final String message}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: prego.colors.bgSurface1,
        border: Border.all(color: prego.colors.borderErrorSubtle),
        borderRadius: BorderRadius.circular(PregoRadius.lg),
      ),
      child: Text(message, style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textErrorPrimary)),
    );
  }
}

class const _PreviewSurface({
  required final Widget child,
  final Alignment alignment = Alignment.center,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.prego.colors.bgSurface2,
    child: Align(alignment: alignment, child: child),
  );
}
