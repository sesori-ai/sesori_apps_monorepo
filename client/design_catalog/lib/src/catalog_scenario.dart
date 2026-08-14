/// Supported button sizes exposed by the catalog manifest.
enum CatalogButtonSize() {
  sm,
  md,
  lg,
  xl;
}

/// Supported visual hierarchy values exposed by the catalog manifest.
enum CatalogButtonHierarchy() {
  primary,
  primaryAlt,
  secondary,
  tertiary,
  link;
}

/// Supported semantic tones exposed by the catalog manifest.
enum CatalogButtonTone() {
  regular,
  destructive,
  warning,
  success;
}

/// Interaction states that can be represented without pointer automation.
enum CatalogButtonState() {
  enabled,
  disabled,
  loading;
}

/// Content layouts supported by the production button.
enum CatalogButtonPresentation() {
  label,
  iconOnly;
}

/// Icons used by curated scenarios. The catalog renderer owns their Flutter mapping.
enum CatalogButtonIcon() {
  add,
  arrowRight,
  trash;
}

/// A typed, serializable button state used by navigation, matrices, and agents.
final class const CatalogScenario({
  required final String id,
  required final String name,
  required final String description,
  required final CatalogButtonSize size,
  required final CatalogButtonHierarchy hierarchy,
  required final CatalogButtonTone tone,
  required final CatalogButtonState state,
  required final CatalogButtonPresentation presentation,
  required final bool fullWidth,
  required final CatalogButtonIcon? leadingIcon,
  required final CatalogButtonIcon? trailingIcon,
}) {
  // ignore: no_slop_linter/prefer_specific_type, JSON-compatible recursive value boundary
  Map<String, Object?> toJson() => {
    "id": id,
    "name": name,
    "description": description,
    "size": size.name,
    "hierarchy": hierarchy.name,
    "tone": tone.name,
    "state": state.name,
    "presentation": presentation.name,
    "fullWidth": fullWidth,
    "leadingIcon": leadingIcon?.name,
    "trailingIcon": trailingIcon?.name,
  };
}
