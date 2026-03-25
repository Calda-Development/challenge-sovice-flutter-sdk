import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'feedback_model.dart';
import 'feedback_service.dart';

// ---------------------------------------------------------------------------
// Design tokens (from Figma)
// ---------------------------------------------------------------------------

const _kFont = 'PPNeueMontreal';

const _kForeground = Color(0xFF18181B);
const _kMuted = Color(0xFF71717A);
const _kBorder = Color(0xFFE4E4E7);
const _kHeaderBg = Color(0xFFF9FAFB);
const _kToggleActiveBg = Color(0xFF09090B);
const _kToggleActiveFg = Color(0xFFF4F4F5);
const _kCardBorder = Color(0x08000000); // rgba(1,1,1,0.03)

// ---------------------------------------------------------------------------
// Sheet widget
// ---------------------------------------------------------------------------

class FeedbackSheet extends StatefulWidget {
  final CaldaFeedbackConfig config;
  final Uint8List? screenshot;
  final Future<void> Function() onClose;

  const FeedbackSheet({
    super.key,
    required this.config,
    required this.onClose,
    this.screenshot,
  });

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  FeedbackType _type = FeedbackType.bug;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _includeScreenshot = true;
  bool _isSubmitting = false;
  bool _isSuccess = false;
  String? _error;
  Uint8List? _screenshot;

  @override
  void initState() {
    super.initState();
    _screenshot = widget.screenshot;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter an issue title.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final report = FeedbackReport(
        type: _type,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        screenshot: _includeScreenshot ? _screenshot : null,
        environment: widget.config.environment ?? CaldaEnvironment.current,
        version: widget.config.version,
        platform: widget.config.platform ?? CaldaPlatform.current,
      );

      await FeedbackService.submit(report, widget.config);

      if (mounted) {
        setState(() {
          _isSuccess = true;
          _isSubmitting = false;
        });
        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) await widget.onClose();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to submit. Please try again.';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(
            top: BorderSide(color: _kCardBorder),
            left: BorderSide(color: _kCardBorder),
            right: BorderSide(color: _kCardBorder),
          ),
        ),
        child: SafeArea(
          top: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _isSuccess ? _buildSuccess() : _buildForm(context),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: widget.config.buttonColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              color: widget.config.buttonColor,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Feedback received!',
            style: TextStyle(
              fontFamily: _kFont,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: _kForeground,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Thank you for letting us know.',
            style: TextStyle(
              fontFamily: _kFont,
              fontSize: 14,
              color: _kMuted,
              height: 1.43,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Column(
      key: const ValueKey('form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDragHandle(),
        _buildHeader(context),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLabel('What type of issue?'),
                const SizedBox(height: 12),
                _TypeSelector(
                  selected: _type,
                  onChanged: (t) => setState(() => _type = t),
                ),
                const SizedBox(height: 20),
                _buildLabel('Issue'),
                const SizedBox(height: 8),
                _buildTextField(
                  _titleController,
                  'What is the issue?',
                  maxLines: 1,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),
                _buildLabel("What's wrong?"),
                const SizedBox(height: 8),
                _buildTextField(
                  _descController,
                  'Describe your problem as accurately as possible...',
                  maxLines: 4,
                  minLines: 4,
                  textInputAction: TextInputAction.newline,
                ),
                if (_screenshot != null) ...[
                  const SizedBox(height: 20),
                  _ScreenshotToggle(
                    screenshot: _screenshot!,
                    include: _includeScreenshot,
                    onToggle: (v) => setState(() => _includeScreenshot = v),
                    accentColor: widget.config.buttonColor,
                    onAnnotated: (bytes) =>
                        setState(() => _screenshot = bytes),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      fontFamily: _kFont,
                      color: widget.config.buttonColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(28, 12, 28, 20 + bottomInset),
          child: _buildFooterButtons(),
        ),
      ],
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 0),
        width: 32,
        height: 3,
        decoration: BoxDecoration(
          color: _kBorder,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'Send Feedback',
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: _kForeground,
                    letterSpacing: -0.4,
                    height: 1,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => widget.onClose(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                icon: const Icon(
                  Icons.close_rounded,
                  color: _kMuted,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Describe what you expected and what happened instead.',
            style: TextStyle(
              fontFamily: _kFont,
              fontSize: 14,
              color: _kMuted,
              height: 1.43,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: _kFont,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _kForeground,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    int? minLines,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: _kBorder),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: _kForeground, width: 1.5),
    );

    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: minLines,
      textInputAction: textInputAction,
      style: const TextStyle(fontFamily: _kFont, fontSize: 14, color: _kForeground),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: _kFont, color: _kMuted, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: focusedBorder,
        isDense: true,
      ),
    );
  }

  Widget _buildFooterButtons() {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.config.buttonColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              widget.config.buttonColor.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'SEND',
                style: TextStyle(
                  fontFamily: _kFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Type selector
// ---------------------------------------------------------------------------

class _TypeSelector extends StatelessWidget {
  final FeedbackType selected;
  final ValueChanged<FeedbackType> onChanged;

  const _TypeSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: FeedbackType.values.map((type) {
        final isSelected = type == selected;
        return Padding(
          padding: EdgeInsets.only(
            right: type != FeedbackType.values.last ? 8 : 0,
          ),
          child: GestureDetector(
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOut,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? _kToggleActiveBg : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _kToggleActiveBg : _kBorder,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  fontFamily: _kFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? _kToggleActiveFg : _kForeground,
                ),
                child: Text(type.label),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Screenshot toggle + thumbnail
// ---------------------------------------------------------------------------

class _ScreenshotToggle extends StatelessWidget {
  final Uint8List screenshot;
  final bool include;
  final ValueChanged<bool> onToggle;
  final Color accentColor;
  final ValueChanged<Uint8List> onAnnotated;

  const _ScreenshotToggle({
    required this.screenshot,
    required this.include,
    required this.onToggle,
    required this.accentColor,
    required this.onAnnotated,
  });

  void _showFullscreen(BuildContext context) {
    final overlayState = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: _ScreenshotFullscreenViewer(
          screenshot: screenshot,
          onClose: () => entry.remove(),
          onSave: (bytes) {
            entry.remove();
            onAnnotated(bytes);
          },
        ),
      ),
    );
    overlayState.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Attach Screenshot',
              style: TextStyle(
                fontFamily: _kFont,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _kForeground,
              ),
            ),
            const Spacer(),
            Transform.scale(
              scale: 0.82,
              alignment: Alignment.centerRight,
              child: Switch.adaptive(
                value: include,
                onChanged: onToggle,
                activeThumbColor: Colors.white,
                activeTrackColor: accentColor,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: _kBorder,
              ),
            ),
          ],
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState:
              include ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GestureDetector(
              onTap: () => _showFullscreen(context),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.memory(
                        screenshot,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _kForeground.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Drawing data
// ---------------------------------------------------------------------------

class _DrawingStroke {
  final Color color;
  final double strokeWidth;
  final List<Offset> points;

  _DrawingStroke({required this.color, required this.strokeWidth})
      : points = [];
}

class _DrawingPainter extends CustomPainter {
  final List<_DrawingStroke> strokes;
  final _DrawingStroke? currentStroke;

  _DrawingPainter({required this.strokes, this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in [
      ...strokes,
      if (currentStroke != null) currentStroke!,
    ]) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter old) => true;
}

// ---------------------------------------------------------------------------
// Fullscreen viewer + drawing editor
// ---------------------------------------------------------------------------

class _ScreenshotFullscreenViewer extends StatefulWidget {
  final Uint8List screenshot;
  final VoidCallback onClose;
  final ValueChanged<Uint8List> onSave;

  const _ScreenshotFullscreenViewer({
    required this.screenshot,
    required this.onClose,
    required this.onSave,
  });

  @override
  State<_ScreenshotFullscreenViewer> createState() =>
      _ScreenshotFullscreenViewerState();
}

class _ScreenshotFullscreenViewerState
    extends State<_ScreenshotFullscreenViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  final List<_DrawingStroke> _strokes = [];
  _DrawingStroke? _currentStroke;
  Color _penColor = const Color(0xFFEF4444);
  double _penWidth = 4.0;
  Size? _imageSize;
  bool _isSaving = false;

  static const _penColors = [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFFFACC15),
    Color(0xFF22C55E),
    Color(0xFF000000),
    Color(0xFFFFFFFF),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    final codec = await ui.instantiateImageCodec(widget.screenshot);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() => _imageSize = Size(
            frame.image.width.toDouble(),
            frame.image.height.toDouble(),
          ));
      frame.image.dispose();
    }
  }

  Rect _imageDisplayRect(Size container) {
    if (_imageSize == null) {
      return Rect.fromLTWH(0, 0, container.width, container.height);
    }
    final fitted = applyBoxFit(BoxFit.contain, _imageSize!, container);
    final dx = (container.width - fitted.destination.width) / 2;
    final dy = (container.height - fitted.destination.height) / 2;
    return Rect.fromLTWH(
        dx, dy, fitted.destination.width, fitted.destination.height);
  }

  void _onPanStart(DragStartDetails d, Rect imageRect) {
    if (!imageRect.contains(d.localPosition)) return;
    setState(() {
      _currentStroke =
          _DrawingStroke(color: _penColor, strokeWidth: _penWidth)
            ..points.add(d.localPosition);
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_currentStroke == null) return;
    setState(() => _currentStroke!.points.add(d.localPosition));
  }

  void _onPanEnd(DragEndDetails d) {
    if (_currentStroke == null) return;
    setState(() {
      if (_currentStroke!.points.length >= 2) _strokes.add(_currentStroke!);
      _currentStroke = null;
    });
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

  Future<void> _save(Size containerSize) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final bytes = _strokes.isEmpty
        ? widget.screenshot
        : await _compositeDrawing(containerSize);

    if (mounted) {
      await _controller.reverse();
      widget.onSave(bytes);
    }
  }

  Future<Uint8List> _compositeDrawing(Size containerSize) async {
    final codec = await ui.instantiateImageCodec(widget.screenshot);
    final frame = await codec.getNextFrame();
    final original = frame.image;
    final imgW = original.width.toDouble();
    final imgH = original.height.toDouble();

    final imageRect = _imageDisplayRect(containerSize);
    final scaleX = imgW / imageRect.width;
    final scaleY = imgH / imageRect.height;
    final avgScale = (scaleX + scaleY) / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, imgW, imgH));
    canvas.drawImage(original, Offset.zero, Paint());

    for (final stroke in _strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth * avgScale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      bool first = true;
      for (final p in stroke.points) {
        final ip = Offset(
          (p.dx - imageRect.left) * scaleX,
          (p.dy - imageRect.top) * scaleY,
        );
        if (first) {
          path.moveTo(ip.dx, ip.dy);
          first = false;
        } else {
          path.lineTo(ip.dx, ip.dy);
        }
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final composited = await picture.toImage(imgW.round(), imgH.round());
    final byteData =
        await composited.toByteData(format: ui.ImageByteFormat.png);
    original.dispose();
    composited.dispose();
    return byteData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => ColoredBox(
        color: Colors.black.withValues(alpha: _fade.value),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final containerSize =
                Size(constraints.maxWidth, constraints.maxHeight);
            final imageRect = _imageDisplayRect(containerSize);

            return Stack(
              fit: StackFit.expand,
              children: [
                FadeTransition(
                  opacity: _fade,
                  child: Image.memory(
                    widget.screenshot,
                    fit: BoxFit.contain,
                  ),
                ),
                GestureDetector(
                  onPanStart: (d) => _onPanStart(d, imageRect),
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    painter: _DrawingPainter(
                      strokes: _strokes,
                      currentStroke: _currentStroke,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  top: topPadding + 4,
                  left: 4,
                  right: 4,
                  child: _buildTopBar(containerSize),
                ),
                Positioned(
                  bottom: bottomPadding + 16,
                  left: 16,
                  right: 16,
                  child: _buildToolbar(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(Size containerSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _TopBarButton(icon: Icons.close_rounded, onPressed: _close),
        _TopBarButton(
          icon: Icons.check_rounded,
          onPressed: _isSaving ? null : () => _save(containerSize),
          isLoading: _isSaving,
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    final colorDots = [
      for (int i = 0; i < _penColors.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        _ColorDot(
          color: _penColors[i],
          selected: _penColor == _penColors[i],
          onTap: () => setState(() => _penColor = _penColors[i]),
        ),
      ],
    ];

    final strokeAndActions = [
      _StrokeWidthButton(
        dotSize: 3.0,
        selected: _penWidth == 3.0,
        onTap: () => setState(() => _penWidth = 3.0),
      ),
      const SizedBox(width: 6),
      _StrokeWidthButton(
        dotSize: 8.0,
        selected: _penWidth == 8.0,
        onTap: () => setState(() => _penWidth = 8.0),
      ),
      _ToolbarDivider(),
      IconButton(
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
        onPressed:
            _strokes.isEmpty ? null : () => setState(() => _strokes.removeLast()),
        icon: Icon(
          Icons.undo_rounded,
          color: _strokes.isEmpty ? Colors.white30 : Colors.white,
          size: 22,
        ),
      ),
      const SizedBox(width: 2),
      IconButton(
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
        onPressed:
            _strokes.isEmpty ? null : () => setState(() => _strokes.clear()),
        icon: Icon(
          Icons.delete_outline_rounded,
          color: _strokes.isEmpty ? Colors.white30 : Colors.white,
          size: 22,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final singleRow = constraints.maxWidth >= 385;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
          ),
          child: singleRow
              ? Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: colorDots,
                      ),
                    ),
                    _ToolbarDivider(),
                    ...strokeAndActions,
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: colorDots,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: strokeAndActions,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Small toolbar widgets
// ---------------------------------------------------------------------------

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _TopBarButton({
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? Colors.white : Colors.white38,
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 8)]
              : null,
        ),
      ),
    );
  }
}

class _StrokeWidthButton extends StatelessWidget {
  final double dotSize;
  final bool selected;
  final VoidCallback onTap;

  const _StrokeWidthButton({
    required this.dotSize,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: selected ? Colors.white : Colors.white38,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: dotSize,
          height: dotSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
