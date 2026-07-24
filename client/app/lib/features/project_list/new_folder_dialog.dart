import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/extensions/build_context_x.dart";

/// Asks for the name of a folder to create, returning it trimmed — or null if
/// the user backed out.
///
/// Naming is all this sheet does: the caller owns creating the folder and
/// reporting how that went, so the prompt closes as soon as a name is given
/// rather than sitting open behind a spinner.
Future<String?> showNewFolderDialog({required BuildContext context}) {
  return showPregoBottomSheet<String>(
    context: context,
    title: context.loc.newFolderTitle,
    builder: (_) => const NewFolderDialog(),
  );
}

@visibleForTesting
class NewFolderDialog extends StatefulWidget {
  const NewFolderDialog({super.key});

  @override
  State<NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<NewFolderDialog> {
  final TextEditingController _nameController = TextEditingController();

  /// The name is one folder, not a route: a separator would put the folder
  /// somewhere the browser is not showing. The bridge rejects these too — this
  /// just stops the round trip.
  bool get _isValid {
    final name = _nameController.text.trim();
    return name.isNotEmpty && !name.contains("/") && !name.contains(r"\") && name != "." && name != "..";
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_isValid) return;
    context.pop(_nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: PregoSpacing.xl,
        children: [
          PregoInputField(
            controller: _nameController,
            label: loc.newFolderHint,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          PregoButtonsSolid(
            label: loc.newFolderCreate,
            hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
            size: PregoButtonsSolidSize.xl,
            fullWidth: true,
            onPressed: _isValid ? _submit : null,
          ),
        ],
      ),
    );
  }
}
