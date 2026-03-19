import 'dart:typed_data';
import 'package:flutter/material.dart';

enum FeedbackType {
  data,
  visual,
  other;

  String get label {
    switch (this) {
      case FeedbackType.data:
        return 'Data';
      case FeedbackType.visual:
        return 'Visual';
      case FeedbackType.other:
        return 'Other';
    }
  }

  String get tag {
    switch (this) {
      case FeedbackType.data:
        return 'Data';
      case FeedbackType.visual:
        return 'Visual';
      case FeedbackType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case FeedbackType.data:
        return Icons.storage_outlined;
      case FeedbackType.visual:
        return Icons.palette_outlined;
      case FeedbackType.other:
        return Icons.chat_bubble_outline;
    }
  }
}

class FeedbackReport {
  final FeedbackType type;
  final String title;
  final String description;
  final Uint8List? screenshot;

  const FeedbackReport({
    required this.type,
    required this.title,
    required this.description,
    this.screenshot,
  });
}

/// Where the floating feedback button is anchored by default.
enum CaldaButtonPosition {
  bottomRight,
  bottomLeft,
  bottomCenter,
  topRight,
  topLeft,
}

/// Visual style of the floating feedback button.
///
/// - [pill] — the default horizontal pill with an icon and a text label.
/// - [fab] — a compact circular button showing only the Calda logo.
enum CaldaButtonStyle {
  pill,
  fab,
}

/// Configuration for the Calda feedback widget.
///
/// Pass an instance to [CaldaFeedback.initialize]. All fields except
/// [projectId], [apiUrl], and [apiKey] are optional and have sensible defaults.
class CaldaFeedbackConfig {
  /// Your Calda project UUID from the projects table.
  final String projectId;

  /// Full URL of the ticket submission endpoint, e.g.
  /// `https://<ref>.supabase.co/functions/v1/submit-ticket`.
  final String apiUrl;

  /// Bearer token sent in the `Authorization` header when calling [apiUrl].
  final String apiKey;

  /// Accent color used for the floating button and interactive UI elements.
  final Color buttonColor;

  /// Visual style of the floating button.
  ///
  /// [CaldaButtonStyle.pill] shows a pill-shaped button with an icon and
  /// [buttonLabel]. [CaldaButtonStyle.fab] shows a compact circular button
  /// with the Calda logo.
  final CaldaButtonStyle buttonStyle;

  /// Label shown on the pill-style button.
  ///
  /// Only used when [buttonStyle] is [CaldaButtonStyle.pill].
  /// Defaults to `'REPORT A BUG'`.
  final String buttonLabel;

  /// Whether to automatically capture a screenshot when the user opens the
  /// feedback sheet.
  final bool captureScreenshot;

  /// Initial anchor position of the floating button.
  final CaldaButtonPosition buttonPosition;

  /// When `true` the user can drag the floating button to any position on
  /// screen. It snaps to the nearest horizontal edge when released.
  final bool buttonMovable;

  /// Set to `false` to hide the floating button entirely. In this mode you
  /// must call [CaldaFeedback.open] programmatically to show the sheet.
  final bool showButton;

  const CaldaFeedbackConfig({
    required this.projectId,
    required this.apiUrl,
    required this.apiKey,
    this.buttonColor = const Color(0xFFFF3D00),
    this.buttonStyle = CaldaButtonStyle.pill,
    this.buttonLabel = 'REPORT A BUG',
    this.captureScreenshot = true,
    this.buttonPosition = CaldaButtonPosition.bottomRight,
    this.buttonMovable = false,
    this.showButton = true,
  });
}
