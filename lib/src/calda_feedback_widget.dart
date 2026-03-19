import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'feedback_model.dart';
import 'feedback_sheet.dart';

const _kFont = 'PPNeueMontreal';

class CaldaFeedback {
  CaldaFeedback._();

  static _CaldaFeedbackController? _controller;

  /// Initialise the Calda feedback system. Call this once in `main()` before
  /// `runApp`, or as early as possible after the widget tree is built.
  static void initialize(CaldaFeedbackConfig config) {
    WidgetsFlutterBinding.ensureInitialized();
    _controller = _CaldaFeedbackController(config: config);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller!._inject();
    });
  }

  /// Programmatically open the feedback sheet without tapping the button.
  /// Useful when [CaldaFeedbackConfig.showButton] is `false` or when you want
  /// to trigger feedback from your own UI element.
  static Future<void> open() async {
    final c = _controller;
    if (c == null || c._sheetEntry != null) return;
    await c._openSheetInternal(restoreButton: false);
  }
}

// ---------------------------------------------------------------------------

class _CaldaFeedbackController {
  final CaldaFeedbackConfig config;
  OverlayState? _overlay;
  OverlayEntry? _buttonEntry;
  OverlayEntry? _sheetEntry;
  Offset? _savedButtonOffset;

  _CaldaFeedbackController({required this.config});

  void _inject() {
    _overlay = _findOverlay();
    if (_overlay == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _inject());
      return;
    }
    if (config.showButton) _insertButton();
  }

  OverlayState? _findOverlay() {
    OverlayState? result;
    void visit(Element element) {
      if (result != null) return;
      if (element is StatefulElement && element.state is OverlayState) {
        result = element.state as OverlayState;
        return;
      }
      element.visitChildren(visit);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    return result;
  }

  void _insertButton() {
    _buttonEntry?.remove();
    _buttonEntry = OverlayEntry(
      builder: (_) => _FloatingFeedbackButton(
        config: config,
        initialOffset: _savedButtonOffset,
        onTap: _onButtonTap,
        onOffsetChanged: (offset) => _savedButtonOffset = offset,
      ),
    );
    _overlay!.insert(_buttonEntry!);
  }

  Future<void> _onButtonTap() async {
    if (_sheetEntry != null) return;
    _buttonEntry?.remove();
    _buttonEntry = null;
    await _openSheetInternal(restoreButton: true);
  }

  Future<void> _openSheetInternal({required bool restoreButton}) async {
    final screenshot =
        config.captureScreenshot ? await _captureScreen() : null;

    _sheetEntry = OverlayEntry(
      builder: (_) => _FeedbackOverlayWidget(
        config: config,
        screenshot: screenshot,
        onClose: () {
          _sheetEntry?.remove();
          _sheetEntry = null;
          if (restoreButton && config.showButton) _insertButton();
        },
      ),
    );
    _overlay?.insert(_sheetEntry!);
  }

  Future<Uint8List?> _captureScreen() async {
    try {
      final pixelRatio =
          ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 2.0;

      // Find a full-screen RenderRepaintBoundary instead of using the root
      // layer directly — the root TransformLayer.toImage double-applies
      // devicePixelRatio when a pixelRatio argument is also supplied.
      RenderRepaintBoundary? boundary;
      final renderView = WidgetsBinding.instance.renderViews.first;
      final viewSize = renderView.size;
      void find(RenderObject obj) {
        if (boundary != null) return;
        if (obj is RenderRepaintBoundary &&
            obj.size.width.round() == viewSize.width.round() &&
            obj.size.height.round() == viewSize.height.round()) {
          boundary = obj;
          return;
        }
        obj.visitChildren(find);
      }
      renderView.visitChildren(find);

      if (boundary == null) return null;

      final image = await boundary!.toImage(pixelRatio: pixelRatio);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Floating button
// ---------------------------------------------------------------------------

class _FloatingFeedbackButton extends StatefulWidget {
  final CaldaFeedbackConfig config;
  final Offset? initialOffset;
  final Future<void> Function() onTap;
  final ValueChanged<Offset> onOffsetChanged;

  const _FloatingFeedbackButton({
    required this.config,
    required this.onTap,
    required this.onOffsetChanged,
    this.initialOffset,
  });

  @override
  State<_FloatingFeedbackButton> createState() =>
      _FloatingFeedbackButtonState();
}

class _FloatingFeedbackButtonState extends State<_FloatingFeedbackButton>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;
  late final AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  static const _kFabSize = 56.0;
  static const _kPillWidth = 172.0;
  static const _kPillHeight = 44.0;
  static const _kEdgePad = 24.0;
  static const _kSnapPad = 16.0;
  static const _kDragThreshold = 6.0;

  Offset? _userOffset;
  Offset? _panStartLocal;
  bool _isDragging = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _userOffset = widget.initialOffset;
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _snapController.addListener(() => setState(() {}));
    _snapController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _userOffset = _snapAnimation!.value;
          _snapAnimation = null;
        });
        widget.onOffsetChanged(_userOffset!);
      }
    });
  }

  bool get _isFab =>
      widget.config.buttonStyle == CaldaButtonStyle.fab;

  double get _btnWidth => _isFab ? _kFabSize : _kPillWidth;
  double get _btnHeight => _isFab ? _kFabSize : _kPillHeight;

  @override
  void dispose() {
    _scaleController.dispose();
    _snapController.dispose();
    super.dispose();
  }

  Offset _defaultOffset(Size screen, EdgeInsets safe) {
    final w = _btnWidth;
    final h = _btnHeight;
    const p = _kEdgePad;
    switch (widget.config.buttonPosition) {
      case CaldaButtonPosition.bottomRight:
        return Offset(screen.width - w - p, screen.height - h - p - safe.bottom);
      case CaldaButtonPosition.bottomLeft:
        return Offset(p, screen.height - h - p - safe.bottom);
      case CaldaButtonPosition.bottomCenter:
        return Offset((screen.width - w) / 2, screen.height - h - p - safe.bottom);
      case CaldaButtonPosition.topRight:
        return Offset(screen.width - w - p, safe.top + p);
      case CaldaButtonPosition.topLeft:
        return Offset(p, safe.top + p);
    }
  }

  void _snapToEdge(Size screen) {
    final from = _userOffset!;
    final snapLeft = from.dx + _btnWidth / 2 < screen.width / 2;
    final to = Offset(
      snapLeft ? _kSnapPad : screen.width - _btnWidth - _kSnapPad,
      from.dy.clamp(_kSnapPad, screen.height - _btnHeight - _kSnapPad),
    );
    _snapAnimation = Tween<Offset>(begin: from, end: to).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutBack),
    );
    _snapController.forward(from: 0);
  }

  Future<void> _handleTap() async {
    if (_isCapturing) return;
    _isCapturing = true;
    await _scaleController.forward();
    await _scaleController.reverse();
    await widget.onTap();
  }

  Widget _buildFab() {
    return Container(
      width: _kFabSize,
      height: _kFabSize,
      decoration: BoxDecoration(
        color: widget.config.buttonColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.config.buttonColor.withValues(alpha: 0.40),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Image.asset(
        'assets/calda_logo_white.png',
        package: 'calda_feedback',
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildPill() {
    return Container(
      height: _kPillHeight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: widget.config.buttonColor,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(
            color: widget.config.buttonColor.withValues(alpha: 0.40),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            widget.config.buttonLabel,
            style: const TextStyle(
              fontFamily: _kFont,
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final safe = MediaQuery.of(context).padding;
    final pos = (_snapAnimation != null && _snapController.isAnimating)
        ? _snapAnimation!.value
        : (_userOffset ?? _defaultOffset(screen, safe));
    final movable = widget.config.buttonMovable;

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onTap: movable ? null : _handleTap,
        onPanStart: movable
            ? (d) {
                _panStartLocal = d.localPosition;
                _isDragging = false;
              }
            : null,
        onPanUpdate: movable
            ? (d) {
                final travel =
                    d.localPosition - (_panStartLocal ?? Offset.zero);
                if (travel.distance > _kDragThreshold) _isDragging = true;
                if (_isDragging) {
                  final cur = _userOffset ?? _defaultOffset(screen, safe);
                  final next = Offset(
                    (cur.dx + d.delta.dx)
                        .clamp(0.0, screen.width - _btnWidth),
                    (cur.dy + d.delta.dy)
                        .clamp(0.0, screen.height - _btnHeight),
                  );
                  setState(() => _userOffset = next);
                  widget.onOffsetChanged(next);
                }
              }
            : null,
        onPanEnd: movable
            ? (d) {
                if (_isDragging) {
                  _snapToEdge(screen);
                } else {
                  _handleTap();
                }
                _isDragging = false;
                _panStartLocal = null;
              }
            : null,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: _isFab ? _buildFab() : _buildPill(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feedback sheet overlay
// ---------------------------------------------------------------------------

class _FeedbackOverlayWidget extends StatefulWidget {
  final CaldaFeedbackConfig config;
  final Uint8List? screenshot;
  final VoidCallback onClose;

  const _FeedbackOverlayWidget({
    required this.config,
    required this.screenshot,
    required this.onClose,
  });

  @override
  State<_FeedbackOverlayWidget> createState() => _FeedbackOverlayWidgetState();
}

class _FeedbackOverlayWidgetState extends State<_FeedbackOverlayWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _controller.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: _close,
              child: Container(
                color: Colors.black.withValues(
                  alpha: 0.45 * _fadeAnimation.value,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: _slideAnimation,
                child: FeedbackSheet(
                  config: widget.config,
                  screenshot: widget.screenshot,
                  onClose: _close,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
