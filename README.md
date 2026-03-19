# calda_feedback

A lightweight Flutter package that adds a Gleap-style feedback widget to your app — with a single line of code. A floating button sits in the corner of your choice. Tap it to report a bug or suggestion, with an automatic annotatable screenshot attached.

## Features

- Single-line setup via `CaldaFeedback.initialize(CaldaFeedbackConfig(projectId: '...', apiUrl: '...', apiKey: '...'))`
- No widget tree changes required — works with FlutterFlow and any standard Flutter project
- Two floating button styles: pill with customisable label, or compact circular FAB with your logo
- Configurable position, color, and optional drag-to-reposition
- Hidden-button mode: call `CaldaFeedback.open()` from your own UI instead
- Auto-captures a screenshot of the current screen the moment the button is tapped
- In-app screenshot annotation: draw over the screenshot before submitting
- Feedback form with type selector (Data / Visual / Other), title, and description
- Screenshot preview with toggle to include or exclude it before sending
- PP Neue Montreal typography throughout
- Success and error states built in

## Getting started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  calda_feedback:
    path: ../calda_feedback  # local path, or your pub.dev / git reference
```

Then run:

```bash
flutter pub get
```

## Usage

Call `CaldaFeedback.initialize` once at app startup — before `runApp` or in any early `initState`. No widget wrapping needed.

```dart
import 'package:flutter/material.dart';
import 'package:calda_feedback/calda_feedback.dart';

void main() {
  CaldaFeedback.initialize(
    CaldaFeedbackConfig(
      projectId: 'YOUR_PROJECT_UUID',
      apiUrl: 'https://<ref>.supabase.co/functions/v1/submit-ticket',
      apiKey: 'YOUR_ANON_KEY',
    ),
  );
  runApp(const MyApp());
}
```

### Configuration

Pass a `CaldaFeedbackConfig` to customise the widget. All fields except `projectId`, `apiUrl`, and `apiKey` are optional.

```dart
CaldaFeedback.initialize(
  CaldaFeedbackConfig(
    projectId: 'YOUR_PROJECT_UUID',
    apiUrl: 'https://<ref>.supabase.co/functions/v1/submit-ticket',
    apiKey: 'YOUR_ANON_KEY',
    buttonColor: Colors.indigo,
    buttonStyle: CaldaButtonStyle.pill,   // or CaldaButtonStyle.fab
    buttonLabel: 'REPORT A BUG',          // pill only
    buttonPosition: CaldaButtonPosition.bottomRight,
    buttonMovable: true,
    showButton: true,
    captureScreenshot: true,
  ),
);
```

| Field               | Type                  | Default                  | Description                                                                        |
|---------------------|-----------------------|--------------------------|------------------------------------------------------------------------------------|
| `projectId`         | `String`              | **required**             | Your Calda project UUID from the projects table                                    |
| `apiUrl`            | `String`              | **required**             | Full URL of the ticket submission endpoint                                         |
| `apiKey`            | `String`              | **required**             | Bearer token sent in the `Authorization` header                                    |
| `buttonColor`       | `Color`               | `Color(0xFFFF3D00)`      | Accent color for the floating button and interactive UI elements                   |
| `buttonStyle`       | `CaldaButtonStyle`    | `pill`                   | Visual style of the floating button — see below                                    |
| `buttonLabel`       | `String`              | `'REPORT A BUG'`         | Label shown on the pill button (ignored when `buttonStyle` is `fab`)               |
| `captureScreenshot` | `bool`                | `true`                   | Whether to auto-capture a screenshot when the sheet opens                          |
| `buttonPosition`    | `CaldaButtonPosition` | `bottomRight`            | Initial anchor position of the floating button                                     |
| `buttonMovable`     | `bool`                | `false`                  | Allow the user to drag the button; it snaps to the nearest edge on release         |
| `showButton`        | `bool`                | `true`                   | Set to `false` to hide the button and use `CaldaFeedback.open()` programmatically |

### `CaldaButtonStyle` values

| Value  | Description                                                                              |
|--------|------------------------------------------------------------------------------------------|
| `pill` | Horizontal pill with a `+` icon and `buttonLabel` *(default)*                           |
| `fab`  | Compact 56 × 56 circular button displaying `assets/calda_logo_white.png` from the package |

For the `fab` style, place your white logo PNG at:

```
calda_feedback/assets/calda_logo_white.png
```

### `CaldaButtonPosition` values

| Value          | Description                        |
|----------------|------------------------------------|
| `bottomRight`  | Bottom-right corner *(default)*    |
| `bottomLeft`   | Bottom-left corner                 |
| `bottomCenter` | Bottom edge, horizontally centered |
| `topRight`     | Top-right corner                   |
| `topLeft`      | Top-left corner                    |

### Programmatic open (headless mode)

If you want to trigger the feedback sheet from your own button or menu item, disable the floating button and call `CaldaFeedback.open()`:

```dart
void main() {
  CaldaFeedback.initialize(
    CaldaFeedbackConfig(
      projectId: 'YOUR_PROJECT_UUID',
      apiUrl: 'https://<ref>.supabase.co/functions/v1/submit-ticket',
      apiKey: 'YOUR_ANON_KEY',
      showButton: false,
    ),
  );
  runApp(const MyApp());
}

// Anywhere in your widget tree:
ElevatedButton(
  onPressed: () => CaldaFeedback.open(),
  child: const Text('Send Feedback'),
),
```

`CaldaFeedback.open()` is a no-op if the sheet is already open.

### FlutterFlow

In FlutterFlow, add a **Custom Action** with the following code and set it as an initial action in your app settings:

```dart
import 'package:calda_feedback/calda_feedback.dart';

Future caldaFeedbackInit() async {
  CaldaFeedback.initialize(
    CaldaFeedbackConfig(
      projectId: 'YOUR_PROJECT_UUID',
      apiUrl: 'https://<ref>.supabase.co/functions/v1/submit-ticket',
      apiKey: 'YOUR_ANON_KEY',
    ),
  );
}
```

## Backend payload

The package sends a `multipart/form-data` POST to `apiUrl`:

```
POST <apiUrl>
Authorization: Bearer <apiKey>
Content-Type: multipart/form-data

projectId   = <your project UUID>
title       = <user-entered title>
description = <user-entered description>
tags        = "Data" | "Visual" | "Other"
file        = screenshot.png  (only when the user leaves the screenshot toggle enabled)
```

`tags` maps to the feedback type selected in the form. If the user drew annotations on the screenshot, the submitted image includes the annotations composited at full resolution.

## How it works

- `CaldaFeedback.initialize` walks the Flutter element tree after the first frame to find the `OverlayState` created by `MaterialApp`'s `Navigator`, then inserts the floating button as an `OverlayEntry`. No widget wrapping needed.
- The screenshot is captured via `RenderRepaintBoundary.toImage` before the sheet animates in, so it always shows the screen the user was viewing — not the feedback form.
- The backdrop and slide-up sheet are rendered as `OverlayEntry`s with no dependency on `Navigator.push` or `showModalBottomSheet`.
- Annotation strokes are recorded in screen-space and composited back onto the original full-resolution image using `dart:ui`'s `PictureRecorder` before submission.
