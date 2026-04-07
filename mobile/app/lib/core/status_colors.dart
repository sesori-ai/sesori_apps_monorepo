import "package:flutter/material.dart";

/// Semantic status colors shared across session and PR status indicators.
///
/// GitHub-inspired palette chosen for strong light/dark contrast. Kept in a
/// single location so the amber "attention needed" / green "active" /
/// purple "merged" signals stay visually consistent across the app.
const kStatusGreen = Color(0xFF3FB950);
const kStatusAmber = Color(0xFFD29922);
const kStatusPurple = Color(0xFFA371F7);
