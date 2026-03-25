import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum FeedbackType {
  bug,
  improvement,
  other;

  String get label {
    switch (this) {
      case FeedbackType.bug:
        return 'Bug';
      case FeedbackType.improvement:
        return 'Improvement';
      case FeedbackType.other:
        return 'Other';
    }
  }

  String get tag {
    switch (this) {
      case FeedbackType.bug:
        return 'Bug';
      case FeedbackType.improvement:
        return 'Improvement';
      case FeedbackType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case FeedbackType.bug:
        return Icons.bug_report_outlined;
      case FeedbackType.improvement:
        return Icons.lightbulb_outline;
      case FeedbackType.other:
        return Icons.chat_bubble_outline;
    }
  }
}

enum CaldaPlatform {
  ios,
  android,
  web,
  other;

  String get tag {
    switch (this) {
      case CaldaPlatform.ios:
        return 'iOS';
      case CaldaPlatform.android:
        return 'Android';
      case CaldaPlatform.web:
        return 'Web';
      case CaldaPlatform.other:
        return 'Other';
    }
  }

  static CaldaPlatform get current {
    if (kIsWeb) return CaldaPlatform.web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return CaldaPlatform.ios;
      case TargetPlatform.android:
        return CaldaPlatform.android;
      default:
        return CaldaPlatform.other;
    }
  }
}

enum CaldaEnvironment {
  debug,
  profile,
  release;

  String get tag {
    switch (this) {
      case CaldaEnvironment.debug:
        return 'Debug';
      case CaldaEnvironment.profile:
        return 'Profile';
      case CaldaEnvironment.release:
        return 'Release';
    }
  }

  static CaldaEnvironment get current {
    if (kDebugMode) return CaldaEnvironment.debug;
    if (kProfileMode) return CaldaEnvironment.profile;
    return CaldaEnvironment.release;
  }
}

class FeedbackReport {
  final FeedbackType type;
  final String title;
  final String description;
  final Uint8List? screenshot;
  final String? version;
  final CaldaPlatform platform;
  final CaldaEnvironment environment;

  FeedbackReport({
    required this.type,
    required this.title,
    required this.description,
    this.screenshot,
    this.version,
    CaldaPlatform? platform,
    CaldaEnvironment? environment,
  })  : platform = platform ?? CaldaPlatform.current,
        environment = environment ?? CaldaEnvironment.current;
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
  final String projectId;
  final String apiUrl;
  final String apiKey;
  final String? version;
  final CaldaPlatform? platform;
  final CaldaEnvironment? environment;
  final Color buttonColor;
  final CaldaButtonStyle buttonStyle;
  final String buttonLabel;
  final bool captureScreenshot;
  final CaldaButtonPosition buttonPosition;
  final bool buttonMovable;
  final bool showButton;

  const CaldaFeedbackConfig({
    required this.projectId,
    required this.apiUrl,
    required this.apiKey,
    this.version,
    this.platform,
    this.environment,
    this.buttonColor = const Color(0xFFFF3D00),
    this.buttonStyle = CaldaButtonStyle.pill,
    this.buttonLabel = 'REPORT A BUG',
    this.captureScreenshot = true,
    this.buttonPosition = CaldaButtonPosition.bottomRight,
    this.buttonMovable = false,
    this.showButton = true,
  });
}
