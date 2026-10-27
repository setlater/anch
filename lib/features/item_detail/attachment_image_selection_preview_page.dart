import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/anch_colors.dart';
import '../../core/widgets/anch_centered_notice.dart';
import '../../core/widgets/anch_route_back.dart';
import '../privacy/screen_protection_scope.dart';
import 'attachment_import_controller.dart';
import 'attachment_image_selection.dart';

export 'attachment_image_selection.dart';

typedef AttachmentImageCropper =
    Future<XFile?> Function(
      NavigatorState navigator,
      XFile pickedFile, {
      bool retainSourceWhenCancelled,
    });

/// 多选图片的本地预览页，仅在用户点按时裁剪当前图片。
class AttachmentImageSelectionPreviewPage extends StatefulWidget {
  const AttachmentImageSelectionPreviewPage({
    super.key,
    required this.files,
    required this.cropPickedImage,
  });

  final List<XFile> files;
  final AttachmentImageCropper cropPickedImage;

  @override
  State<AttachmentImageSelectionPreviewPage> createState() =>
      _AttachmentImageSelectionPreviewPageState();
}

class _AttachmentImageSelectionPreviewPageState
    extends State<AttachmentImageSelectionPreviewPage> {
  late final PageController _pageController;
  late List<_SelectedImage> _selectedImages;
  var _currentIndex = 0;
  var _isCropping = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _selectedImages = [
      for (final file in widget.files) _SelectedImage(file: file),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final image in _selectedImages) {
      _evictPreview(image);
    }
    super.dispose();
  }

  void _evictPreview(_SelectedImage image) {
    final previewBytes = image.previewBytes;
    if (previewBytes != null) {
      MemoryImage(previewBytes).evict();
      previewBytes.fillRange(0, previewBytes.length, 0);
      return;
    }
    if (image.file.path.isNotEmpty) {
      FileImage(File(image.file.path)).evict();
    }
  }

  Future<void> _cropCurrentImage() async {
    if (_isCropping) return;
    setState(() => _isCropping = true);
    try {
      final croppedFile = await widget.cropPickedImage(
        Navigator.of(context),
        _selectedImages[_currentIndex].file,
        retainSourceWhenCancelled: true,
      );
      if (croppedFile == null) return;
      final previewBytes = Uint8List.fromList(await croppedFile.readAsBytes());
      if (!mounted) {
        previewBytes.fillRange(0, previewBytes.length, 0);
        return;
      }
      final previousImage = _selectedImages[_currentIndex];
      setState(() {
        _selectedImages[_currentIndex] = _SelectedImage(
          file: croppedFile,
          wasCropped: true,
          previewBytes: previewBytes,
        );
      });
      _evictPreview(previousImage);
    } on AttachmentImportException catch (error) {
      if (mounted) {
        AnchCenteredNotice.showError(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        AnchCenteredNotice.showError(context, '无法裁剪图片，请重试。');
      }
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  void _finish() {
    Navigator.of(context).pop([
      for (final image in _selectedImages)
        AttachmentImageSelection(
          file: image.file,
          wasCropped: image.wasCropped,
        ),
    ]);
  }

  Widget _buildImage(_SelectedImage image, {BoxFit fit = BoxFit.contain}) {
    final previewBytes = image.previewBytes;
    if (previewBytes != null) return Image.memory(previewBytes, fit: fit);
    return Image.file(
      File(image.file.path),
      fit: fit,
      errorBuilder: (_, _, _) => const Center(
        child: AnchIcon(AnchIcons.brokenImage, color: Colors.white54),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ScreenProtectionScope(child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    final colors = context.anchColors;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.black,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          title: Text(
            '${_currentIndex + 1} / ${_selectedImages.length}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          leadingWidth: 48,
          titleSpacing: 0,
          leading: AnchRouteBack(
            color: Colors.white,
            onBack: _isCropping ? null : () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _selectedImages.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) =>
                    Center(child: _buildImage(_selectedImages[index])),
              ),
            ),
            Container(
              color: Colors.black,
              child: Column(
                children: [
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _selectedImages.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final isSelected = index == _currentIndex;
                        return GestureDetector(
                          onTap: () => _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          ),
                          child: Container(
                            width: 64,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? colors.accent
                                    : colors.divider,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Opacity(
                                opacity: isSelected ? 1 : 0.58,
                                child: _buildImage(
                                  _selectedImages[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final useStackedActions =
                            constraints.maxWidth < 320 ||
                            MediaQuery.textScalerOf(context).scale(1) >= 1.5;
                        final cropButton = OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.accent,
                            side: BorderSide(color: colors.divider),
                            minimumSize: const Size(104, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isCropping ? null : _cropCurrentImage,
                          icon: const AnchIcon(
                            AnchIcons.crop,
                            size: 19,
                            color: Colors.white,
                          ),
                          label: Text(
                            _isCropping ? '处理中…' : '裁剪',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                        final finishButton = ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.accent,
                            foregroundColor: colors.accentInk,
                            disabledBackgroundColor: colors.accentSoft,
                            disabledForegroundColor: colors.textMuted,
                            minimumSize: const Size(104, 48),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isCropping ? null : _finish,
                          child: const Text(
                            '完成',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                          child: useStackedActions
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    cropButton,
                                    const SizedBox(height: 8),
                                    finishButton,
                                  ],
                                )
                              : Row(
                                  children: [
                                    cropButton,
                                    const Spacer(),
                                    finishButton,
                                  ],
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedImage {
  const _SelectedImage({
    required this.file,
    this.wasCropped = false,
    this.previewBytes,
  });

  final XFile file;
  final bool wasCropped;
  final Uint8List? previewBytes;
}
