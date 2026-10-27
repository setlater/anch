import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../core/widgets/anch_centered_notice.dart';
import '../privacy/screen_protection_scope.dart';

/// 本地附件图片裁剪页。
///
/// 图片可双指缩放、单指拖动；裁剪框可拖动边和角点，图片始终回弹并覆盖裁剪区域。
class AttachmentImageCropPage extends StatefulWidget {
  const AttachmentImageCropPage({super.key, required this.source});

  final XFile source;

  @visibleForTesting
  static Offset clampImageOffset({
    required Offset imageOffset,
    required Rect cropRect,
    required Size scaledImageSize,
  }) {
    final horizontalLimit = cropRect.right - scaledImageSize.width;
    final verticalLimit = cropRect.bottom - scaledImageSize.height;
    return Offset(
      imageOffset.dx
          .clamp(
            math.min(horizontalLimit, cropRect.left),
            math.max(horizontalLimit, cropRect.left),
          )
          .toDouble(),
      imageOffset.dy
          .clamp(
            math.min(verticalLimit, cropRect.top),
            math.max(verticalLimit, cropRect.top),
          )
          .toDouble(),
    );
  }

  @visibleForTesting
  static Rect initialCropRectFor({
    required Size viewport,
    required Size sourceSize,
  }) {
    final horizontalInset = math.min(24.0, viewport.width / 12);
    final verticalInset = math.min(24.0, viewport.height / 12);
    final availableWidth = viewport.width - horizontalInset * 2;
    final availableHeight = viewport.height - verticalInset * 2;
    final sourceAspectRatio = sourceSize.width / sourceSize.height;
    var cropWidth = availableWidth;
    var cropHeight = cropWidth / sourceAspectRatio;
    if (cropHeight > availableHeight) {
      cropHeight = availableHeight;
      cropWidth = cropHeight * sourceAspectRatio;
    }
    return Rect.fromCenter(
      center: viewport.center(Offset.zero),
      width: cropWidth,
      height: cropHeight,
    );
  }

  @override
  State<AttachmentImageCropPage> createState() =>
      _AttachmentImageCropPageState();
}

class _AttachmentImageCropPageState extends State<AttachmentImageCropPage> {
  ui.Image? _image;
  Object? _loadError;
  Size _viewport = Size.zero;
  Rect _cropRect = Rect.zero;
  Offset _imageOffset = Offset.zero;
  double _scale = 1;
  double _minimumScale = 1;
  double _outputScale = 1;
  Offset _startFocal = Offset.zero;
  Offset _startImageOffset = Offset.zero;
  double _startScale = 1;
  Rect _startCropRect = Rect.zero;
  _CropDragHandle _dragHandle = _CropDragHandle.image;
  bool _isExporting = false;
  double _rotationDegrees = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.source.readAsBytes();
      final imageCompleter = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, imageCompleter.complete);
      final image = await imageCompleter.future;
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _image = image);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  void _configureViewport(Size viewport) {
    if (viewport == _viewport || viewport.isEmpty || _image == null) return;
    _viewport = viewport;
    _cropRect = AttachmentImageCropPage.initialCropRectFor(
      viewport: viewport,
      sourceSize: Size(_image!.width.toDouble(), _image!.height.toDouble()),
    );
    _resetImageToCropRect();
    final sourceScale = 1 / _scale;
    final longestSourceSide = math.max(
      _cropRect.width * sourceScale,
      _cropRect.height * sourceScale,
    );
    _outputScale = longestSourceSide > 1920
        ? sourceScale * 1920 / longestSourceSide
        : sourceScale;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _viewport == viewport) setState(() {});
    });
  }

  void _resetImageToCropRect() {
    final image = _image;
    if (image == null || _cropRect.isEmpty) return;
    _minimumScale = math.max(
      _cropRect.width / image.width,
      _cropRect.height / image.height,
    );
    _scale = _minimumScale;
    _imageOffset = Offset(
      _cropRect.center.dx - image.width * _scale / 2,
      _cropRect.center.dy - image.height * _scale / 2,
    );
    _clampImageToCropRect();
  }

  void _clampImageToCropRect() {
    final image = _image;
    if (image == null || _cropRect.isEmpty) return;
    final width = image.width * _scale;
    final height = image.height * _scale;
    _imageOffset = AttachmentImageCropPage.clampImageOffset(
      imageOffset: _imageOffset,
      cropRect: _cropRect,
      scaledImageSize: Size(width, height),
    );
  }

  _CropDragHandle _hitTestHandle(Offset point) {
    const handleSize = 28.0;
    final handles = <_CropDragHandle, Offset>{
      _CropDragHandle.topLeft: _cropRect.topLeft,
      _CropDragHandle.topRight: _cropRect.topRight,
      _CropDragHandle.bottomLeft: _cropRect.bottomLeft,
      _CropDragHandle.bottomRight: _cropRect.bottomRight,
    };
    for (final entry in handles.entries) {
      if ((point - entry.value).distance <= handleSize) return entry.key;
    }
    return _CropDragHandle.image;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startFocal = details.localFocalPoint;
    _startImageOffset = _imageOffset;
    _startScale = _scale;
    _startCropRect = _cropRect;
    _dragHandle = _hitTestHandle(details.localFocalPoint);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_image == null) return;
    setState(() {
      if (_dragHandle == _CropDragHandle.image) {
        final nextScale = (_startScale * details.scale).clamp(
          _minimumScale,
          _minimumScale * 6,
        );
        final scaleRatio = nextScale / _startScale;
        _scale = nextScale;
        _imageOffset =
            details.localFocalPoint -
            (_startFocal - _startImageOffset) * scaleRatio;
      } else {
        _cropRect = _resizeCropRect(
          _startCropRect,
          details.localFocalPoint - _startFocal,
          _dragHandle,
        );
        _minimumScale = math.max(
          _cropRect.width / _image!.width,
          _cropRect.height / _image!.height,
        );
        _scale = math.max(_scale, _minimumScale);
      }
      _clampImageToCropRect();
    });
  }

  Rect _resizeCropRect(Rect start, Offset delta, _CropDragHandle handle) {
    const minSize = 96.0;
    var left = start.left;
    var top = start.top;
    var right = start.right;
    var bottom = start.bottom;
    switch (handle) {
      case _CropDragHandle.topLeft:
        left += delta.dx;
        top += delta.dy;
      case _CropDragHandle.topRight:
        right += delta.dx;
        top += delta.dy;
      case _CropDragHandle.bottomLeft:
        left += delta.dx;
        bottom += delta.dy;
      case _CropDragHandle.bottomRight:
        right += delta.dx;
        bottom += delta.dy;
      case _CropDragHandle.image:
        break;
    }
    left = left.clamp(0, right - minSize);
    top = top.clamp(0, bottom - minSize);
    right = right.clamp(left + minSize, _viewport.width);
    bottom = bottom.clamp(top + minSize, _viewport.height);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Future<void> _confirmCrop() async {
    final image = _image;
    if (image == null || _isExporting) return;
    setState(() => _isExporting = true);
    try {
      final outputScale = _outputScale;
      final outputWidth = math.max(1, (_cropRect.width * outputScale).round());
      final outputHeight = math.max(
        1,
        (_cropRect.height * outputScale).round(),
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final imageCenter = Offset(
        _imageOffset.dx + image.width * _scale / 2,
        _imageOffset.dy + image.height * _scale / 2,
      );
      canvas.scale(outputScale);
      canvas.translate(-_cropRect.left, -_cropRect.top);
      canvas.translate(imageCenter.dx, imageCenter.dy);
      canvas.rotate(_rotationDegrees * math.pi / 180);
      canvas.translate(-imageCenter.dx, -imageCenter.dy);
      canvas.translate(_imageOffset.dx, _imageOffset.dy);
      canvas.scale(_scale);
      canvas.drawImage(image, Offset.zero, Paint());
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(outputWidth, outputHeight);
      picture.dispose();
      final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
      cropped.dispose();
      if (png == null) throw StateError('无法生成裁剪图片');
      final bytes = await FlutterImageCompress.compressWithList(
        png.buffer.asUint8List(),
        format: CompressFormat.jpeg,
        quality: 95,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        XFile.fromData(
          Uint8List.fromList(bytes),
          name: widget.source.name,
          mimeType: 'image/jpeg',
        ),
      );
    } catch (_) {
      if (mounted) {
        AnchCenteredNotice.showError(context, '裁剪图片失败，请重试。');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ScreenProtectionScope(child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    final image = _image;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: false,
        leadingWidth: 48,
        titleSpacing: 0,
        leading: IconButton(
          icon: const AnchIcon(AnchIcons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '裁剪附件图片',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isExporting ? null : _confirmCrop,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white38,
            ),
            child: Text(_isExporting ? '处理中…' : '确定'),
          ),
        ],
      ),
      body: image == null
          ? Center(
              child: _loadError == null
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('无法读取图片', style: TextStyle(color: Colors.white)),
            )
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _configureViewport(constraints.biggest);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned(
                              left: _imageOffset.dx,
                              top: _imageOffset.dy,
                              width: image.width * _scale,
                              height: image.height * _scale,
                              child: Transform.rotate(
                                angle: _rotationDegrees * math.pi / 180,
                                child: RawImage(image: image, fit: BoxFit.fill),
                              ),
                            ),
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _CropOverlayPainter(_cropRect),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    color: const Color(0xff2d2c31),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
                          child: const Text(
                            '双指缩放，单指移动图片；拖动边框角点裁剪',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const AnchIcon(
                                    AnchIcons.rotate,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_rotationDegrees.round()}°',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: Colors.white,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: Colors.white,
                                        overlayColor: Colors.white12,
                                      ),
                                      child: Slider(
                                        value: _rotationDegrees,
                                        min: -180,
                                        max: 180,
                                        divisions: 360,
                                        label: '${_rotationDegrees.round()}°',
                                        onChanged: _isExporting
                                            ? null
                                            : (value) => setState(
                                                () => _rotationDegrees = value,
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              AttachmentCropRotationQuickActions(
                                rotationDegrees: _rotationDegrees,
                                isExporting: _isExporting,
                                onSelected: (angle) =>
                                    setState(() => _rotationDegrees = angle),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// 裁剪页的常用旋转角度操作。
///
/// 常规字号维持一行紧凑操作；窄窗口或大字号下改为多行，保证角度标签
/// 与最小触控高度都不被压缩。
class AttachmentCropRotationQuickActions extends StatelessWidget {
  const AttachmentCropRotationQuickActions({
    super.key,
    required this.rotationDegrees,
    required this.isExporting,
    required this.onSelected,
  });

  static const _angles = [-90.0, -45.0, 0.0, 45.0, 90.0];

  final double rotationDegrees;
  final bool isExporting;
  final ValueChanged<double> onSelected;

  Widget _buildButton(double angle, {required bool isWrapped}) {
    final isSelected = rotationDegrees.round() == angle.round();
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: isSelected ? Colors.amberAccent : Colors.white,
        disabledForegroundColor: Colors.white38,
        minimumSize: Size(isWrapped ? 64 : 0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 2),
      ),
      onPressed: isExporting ? null : () => onSelected(angle),
      child: Text(angle == 0 ? '重置' : '${angle.round()}°'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useWrap =
            constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.5;
        if (useWrap) {
          return Wrap(
            key: const Key('attachment_crop_rotation_actions_wrap'),
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final angle in _angles) _buildButton(angle, isWrapped: true),
            ],
          );
        }

        return Row(
          key: const Key('attachment_crop_rotation_actions_row'),
          children: [
            for (final angle in _angles)
              Expanded(child: _buildButton(angle, isWrapped: false)),
          ],
        );
      },
    );
  }
}

enum _CropDragHandle { image, topLeft, topRight, bottomLeft, bottomRight }

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter(this.cropRect);

  final Rect cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.58);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, cropRect.top), dimPaint);
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        cropRect.bottom,
        size.width,
        size.height - cropRect.bottom,
      ),
      dimPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, cropRect.top, cropRect.left, cropRect.height),
      dimPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        cropRect.right,
        cropRect.top,
        size.width - cropRect.right,
        cropRect.height,
      ),
      dimPaint,
    );
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(cropRect, borderPaint);
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final x = cropRect.left + cropRect.width * i / 3;
      final y = cropRect.top + cropRect.height * i / 3;
      canvas.drawLine(
        Offset(x, cropRect.top),
        Offset(x, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, y),
        Offset(cropRect.right, y),
        gridPaint,
      );
    }
    final handlePaint = Paint()..color = Colors.white;
    for (final point in [
      cropRect.topLeft,
      cropRect.topRight,
      cropRect.bottomLeft,
      cropRect.bottomRight,
    ]) {
      canvas.drawRect(
        Rect.fromCenter(center: point, width: 18, height: 18),
        handlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}
