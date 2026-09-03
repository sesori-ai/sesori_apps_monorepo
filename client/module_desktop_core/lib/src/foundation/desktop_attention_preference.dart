/// Desktop-owned preference for SSE-derived native attention alerts.
enum DesktopAttentionPreference({required final bool isEnabled}) {
  enabled(isEnabled: true),
  disabled(isEnabled: false),
}
