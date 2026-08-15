enum PregoInspectionTokenKind({required final String label}) {
  semanticColor(label: "Semantic color"),
  primitiveColor(label: "Primitive color"),
  typography(label: "Typography"),
  spacing(label: "Spacing"),
  spacingPrimitive(label: "Spacing primitive"),
  radius(label: "Radius"),
  width(label: "Width");
}

final class const PregoInspectionToken<T>({
  required final PregoInspectionTokenKind kind,
  required final String name,
  required final String reference,
  required final T value,
});
