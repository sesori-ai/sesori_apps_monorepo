import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../l10n/app_localizations.dart";
import "../extensions/build_context_x.dart";

class AgentModelButtons extends StatelessWidget {
  final List<ProviderInfo> providers;
  final List<SessionVariant> availableVariants;
  final String selectedAgent;
  final String selectedProviderID;
  final String selectedModelID;
  final SessionVariant? selectedVariant;
  final VoidCallback onAgentTap;
  final VoidCallback onModelTap;
  final VoidCallback onVariantTap;

  const AgentModelButtons({
    super.key,
    required this.providers,
    required this.availableVariants,
    required this.selectedAgent,
    required this.selectedProviderID,
    required this.selectedModelID,
    required this.selectedVariant,
    required this.onAgentTap,
    required this.onModelTap,
    required this.onVariantTap,
  });

  String _resolveModelName(AppLocalizations loc) {
    for (final provider in providers) {
      if (provider.id == selectedProviderID) {
        final model = provider.models[selectedModelID];
        if (model != null) return model.name;
      }
    }
    if (selectedModelID.isNotEmpty) return selectedModelID;
    return loc.sessionDetailPickerModel;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;
    final buttonStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      minimumSize: .zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: theme.textTheme.labelSmall,
      side: BorderSide(color: theme.colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 2),
      child: Row(
        children: [
          Flexible(
            child: OutlinedButton.icon(
              onPressed: onAgentTap,
              icon: Icon(Icons.smart_toy_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
              label: Text(
                selectedAgent,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                overflow: .ellipsis,
                maxLines: 1,
              ),
              style: buttonStyle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: OutlinedButton.icon(
              onPressed: onModelTap,
              icon: Icon(Icons.memory_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
              label: Text(
                _resolveModelName(loc),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                overflow: .ellipsis,
                maxLines: 1,
              ),
              style: buttonStyle,
            ),
          ),
          if (availableVariants.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: OutlinedButton.icon(
                onPressed: onVariantTap,
                icon: Icon(Icons.speed_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                label: Text(
                  selectedVariant?.id ?? loc.sessionDetailVariantDefault,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  overflow: .ellipsis,
                  maxLines: 1,
                ),
                style: buttonStyle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
