import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";

/// The search field above a phone list. It reports every edit; the list owns
/// the query and narrows what it has already loaded.
class const ListSearchField({
  super.key,

  /// The list's current query. The field starts from it, so a field that
  /// remounts (after a reconnect, say) still shows the filter in force.
  required final String query,
  required final String hintText,
  required final ValueChanged<String> onChanged,
}) extends StatefulWidget {
  @override
  State<ListSearchField> createState() => _ListSearchFieldState();
}

class _ListSearchFieldState() extends State<ListSearchField> {
  late final _controller = TextEditingController(text: widget.query);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      child: TextField(
        controller: _controller,
        autocorrect: false,
        textInputAction: TextInputAction.search,
        onChanged: widget.onChanged,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(TablerRegular.search, size: PregoIconSize.md),
          suffixIcon: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _controller.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: context.loc.listSearchClear,
                    icon: const Icon(TablerRegular.x, size: PregoIconSize.md),
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged("");
                    },
                  ),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PregoRadius.x4l),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: prego.colors.bgTertiary,
        ),
      ),
    );
  }
}
