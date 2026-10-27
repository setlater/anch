import 'dart:typed_data';
import 'dart:math' as math;

import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../../core/attachment/attachment_model.dart';
import '../../core/attachment/attachment_payload_reader.dart';
import '../../core/attachment/sensitive_image_cache.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_spacing.dart';
import '../privacy/screen_protection_scope.dart';
import 'image_preview_payload_loader.dart';

typedef ImagePayloadReader = Future<Uint8List> Function(AttachmentModel);
typedef ImageGallerySaver = Future<void> Function(Uint8List);
typedef ImagePreviewPayloadLoad =
    Future<ImagePreviewPayload> Function(
      AttachmentModel attachment, {
      required bool forceOriginal,
      void Function()? onPreparingPreview,
      bool Function()? shouldStorePreview,
    });

class DecryptedImagePreviewPage extends StatefulWidget {
  final List<AttachmentModel> attachments;
  final int initialIndex;
  final ImagePayloadReader? readPayloadInBackground;
  final ImagePreviewPayloadLoad? loadPreviewPayload;
  final ImageGallerySaver? saveImageToGallery;

  const DecryptedImagePreviewPage({
    super.key,
    required this.attachments,
    required this.initialIndex,
    this.readPayloadInBackground,
    this.loadPreviewPayload,
    this.saveImageToGallery,
  });

  @override
  State<DecryptedImagePreviewPage> createState() =>
      DecryptedImagePreviewPageState();
}

class DecryptedImagePreviewPageState extends State<DecryptedImagePreviewPage>
    with WidgetsBindingObserver {
  static const int _maximumPreviewDecodeWidth = 2048;
  static const double _previewDecodeScale = 2;
  static const double _thumbnailExtent = 82;
  static const double _thumbnailPadding = 16;
  late ExtendedPageController _pageController;
  final _thumbnailController = ScrollController();
  late int _currentIndex;
  int? _previousIndex;
  Animation<double>? _routeAnimation;
  var _hasStartedInitialLoad = false;
  var _loadGeneration = 0;
  var _dismissAfterForeground = false;
  var _dismissScheduled = false;

  // 清晰预览只保留当前页与刚查看过的一张，避免来回查看时重新读取，
  // 同时严格限制敏感明文在内存中的数量。
  final _decryptedCache = SensitiveImageCache(maximumEntries: 2);

  final Set<int> _errorIndices = {};
  final Set<int> _loadingIndices = {};
  final Set<int> _previewIndices = {};
  final Map<int, Future<void> Function()> _previewInvalidators = {};
  final Set<int> _preparingPreviewIndices = {};
  // 仅在本次预览会话中保存用户对某张图选择原图的意图，不保存原图字节。
  final Set<int> _originalRequestedIndices = {};
  bool _isSavingToGallery = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _pageController = ExtendedPageController(initialPage: widget.initialIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRouteAnimation = ModalRoute.of(context)?.animation;
    if (identical(nextRouteAnimation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _routeAnimation = nextRouteAnimation;
    if (nextRouteAnimation == null ||
        nextRouteAnimation.status == AnimationStatus.completed) {
      _startInitialLoad();
      return;
    }
    nextRouteAnimation.addStatusListener(_onRouteAnimationStatus);
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _startInitialLoad();
  }

  void _startInitialLoad() {
    if (_hasStartedInitialLoad) return;
    _hasStartedInitialLoad = true;
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _loadAndDecrypt(_currentIndex);
  }

  Future<void> _loadAndDecrypt(
    int index, {
    bool loadingAlreadyMarked = false,
  }) async {
    if (index < 0 || index >= widget.attachments.length) return;
    if (_decryptedCache.contains(index) ||
        _errorIndices.contains(index) ||
        (!loadingAlreadyMarked && _loadingIndices.contains(index))) {
      return;
    }

    if (!loadingAlreadyMarked) {
      setState(() => _loadingIndices.add(index));
    }
    final loadGeneration = _loadGeneration;
    try {
      final payload = await _loadPayload(index);
      final plainBytes = payload.bytes;
      if (!mounted ||
          loadGeneration != _loadGeneration ||
          _dismissAfterForeground ||
          !_retainedIndices().contains(index)) {
        plainBytes.fillRange(0, plainBytes.length, 0);
        if (mounted && loadGeneration == _loadGeneration) {
          _loadingIndices.remove(index);
        }
        return;
      }
      setState(() {
        _decryptedCache.put(index, plainBytes);
        if (payload.usesPreview) {
          _previewIndices.add(index);
          final invalidate = payload.invalidatePreview;
          if (invalidate != null) _previewInvalidators[index] = invalidate;
        } else {
          _previewIndices.remove(index);
          _previewInvalidators.remove(index);
        }
        _preparingPreviewIndices.remove(index);
      });
    } catch (_) {
      if (mounted &&
          loadGeneration == _loadGeneration &&
          !_dismissAfterForeground) {
        setState(() {
          _errorIndices.add(index);
          _preparingPreviewIndices.remove(index);
          _loadingIndices.remove(index);
        });
      }
    }
  }

  Future<ImagePreviewPayload> _loadPayload(int index) async {
    final attachment = widget.attachments[index];
    final reader = widget.readPayloadInBackground;
    if (reader != null) {
      return ImagePreviewPayload(
        bytes: await reader(attachment),
        usesPreview: false,
      );
    }
    final loader =
        widget.loadPreviewPayload ?? ImagePreviewPayloadLoader().load;
    return loader(
      attachment,
      forceOriginal: _originalRequestedIndices.contains(index),
      onPreparingPreview: () {
        if (mounted &&
            !_dismissAfterForeground &&
            _retainedIndices().contains(index)) {
          setState(() => _preparingPreviewIndices.add(index));
        }
      },
      shouldStorePreview: () =>
          mounted &&
          !_dismissAfterForeground &&
          _retainedIndices().contains(index),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActualBackground =
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
    if (isActualBackground) {
      _scrubForBackground();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _dismissAfterResumedFrame();
    }
  }

  void _scrubForBackground() {
    if (_dismissAfterForeground) return;
    _loadGeneration++;
    _decryptedCache.clear();
    setState(() {
      _dismissAfterForeground = true;
      _loadingIndices.clear();
      _errorIndices.clear();
      _previewIndices.clear();
      _previewInvalidators.clear();
      _preparingPreviewIndices.clear();
      _originalRequestedIndices.clear();
    });
  }

  void _dismissAfterResumedFrame() {
    if (!_dismissAfterForeground || _dismissScheduled) return;
    _dismissScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _pageController.dispose();
    _thumbnailController.dispose();

    _loadGeneration++;
    _originalRequestedIndices.clear();
    _previewInvalidators.clear();
    _decryptedCache.clear();
    super.dispose();
  }

  Future<void> _saveCurrentToGallery() async {
    final cachedBytes = _decryptedCache.bytesAt(_currentIndex);
    if (cachedBytes == null ||
        _loadingIndices.contains(_currentIndex) ||
        _isSavingToGallery) {
      return;
    }

    setState(() => _isSavingToGallery = true);

    Uint8List? originalBytes;
    try {
      final bytes = _previewIndices.contains(_currentIndex)
          ? (originalBytes =
                await (widget.readPayloadInBackground ??
                    AttachmentPayloadReader.readInBackground)(
                  widget.attachments[_currentIndex],
                ))
          : cachedBytes;
      await (widget.saveImageToGallery ?? _saveImageToGallery)(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存到系统相册')));
    } catch (_) {
      if (mounted) {
        showDialog<void>(
          context: context,
          useRootNavigator: false,
          builder: (context) => AlertDialog(
            title: const Text(
              '保存失败',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: const Text(
              '无法保存图片到相册，请稍后重试。',
              style: TextStyle(fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } finally {
      originalBytes?.fillRange(0, originalBytes.length, 0);
      if (mounted) {
        setState(() => _isSavingToGallery = false);
      }
    }
  }

  static Future<void> _saveImageToGallery(Uint8List bytes) async {
    var hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      hasAccess = await Gal.requestAccess();
    }
    if (!hasAccess) throw StateError('相册权限未授予');
    await Gal.putImageBytes(bytes);
  }

  void _onPageChanged(int index) {
    final previousCurrentIndex = _currentIndex;
    final shouldLoad =
        !_decryptedCache.contains(index) &&
        !_errorIndices.contains(index) &&
        !_loadingIndices.contains(index);
    setState(() {
      _currentIndex = index;
      if (previousCurrentIndex != index) {
        _previousIndex = previousCurrentIndex;
      }

      final retainedIndices = _retainedIndices();
      _decryptedCache.retainOnly(retainedIndices);
      if (shouldLoad) _loadingIndices.add(index);
      _errorIndices.removeWhere(
        (cachedIndex) => !retainedIndices.contains(cachedIndex),
      );
      _loadingIndices.removeWhere(
        (cachedIndex) => !retainedIndices.contains(cachedIndex),
      );
      _previewIndices.removeWhere(
        (cachedIndex) => !retainedIndices.contains(cachedIndex),
      );
      _previewInvalidators.removeWhere(
        (cachedIndex, _) => !retainedIndices.contains(cachedIndex),
      );
      _preparingPreviewIndices.removeWhere(
        (cachedIndex) => !retainedIndices.contains(cachedIndex),
      );
    });

    if (shouldLoad) _loadAndDecrypt(index, loadingAlreadyMarked: true);
  }

  Set<int> _retainedIndices() => {_currentIndex, ?_previousIndex};

  void _retryImage(int index) {
    if (_dismissAfterForeground ||
        index != _currentIndex ||
        _loadingIndices.contains(index) ||
        !_errorIndices.contains(index)) {
      return;
    }
    setState(() {
      _errorIndices.remove(index);
      if (_previewIndices.remove(index)) {
        _originalRequestedIndices.add(index);
      }
    });
    _loadAndDecrypt(index);
  }

  void _onImageDecoded(
    int index,
    ImageProvider provider, {
    required bool failed,
  }) {
    final generation = _loadGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          generation != _loadGeneration ||
          _dismissAfterForeground ||
          !identical(_decryptedCache.imageAt(index), provider) ||
          (!failed && !_loadingIndices.contains(index))) {
        return;
      }
      final invalidate = failed ? _previewInvalidators.remove(index) : null;
      setState(() {
        if (invalidate == null) _loadingIndices.remove(index);
        if (failed) {
          _decryptedCache.remove(index);
          _errorIndices.add(index);
        }
      });
      if (invalidate != null) {
        try {
          await invalidate();
        } catch (_) {
          // 派生缓存清理失败不阻断用户重试原图。
        }
        if (mounted &&
            generation == _loadGeneration &&
            _errorIndices.contains(index)) {
          setState(() => _loadingIndices.remove(index));
        }
      }
    });
  }

  Widget _buildImageError(int index) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AnchSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '附件暂时无法预览',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AnchSpacing.sm),
            TextButton(
              onPressed: _loadingIndices.contains(index)
                  ? null
                  : () => _retryImage(index),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
              ),
              child: const Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }

  void _revealCurrentThumbnail() {
    if (!mounted || !_thumbnailController.hasClients) return;
    final position = _thumbnailController.position;
    final start = _thumbnailPadding + _currentIndex * _thumbnailExtent;
    final end = start + _thumbnailExtent;
    final target =
        (start < position.pixels
                ? start
                : end > position.pixels + position.viewportDimension
                ? end - position.viewportDimension
                : position.pixels)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target == position.pixels) return;
    _thumbnailController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void _showOriginal() {
    if (!_previewIndices.contains(_currentIndex) ||
        _loadingIndices.contains(_currentIndex)) {
      return;
    }
    setState(() {
      _originalRequestedIndices.add(_currentIndex);
      _previewIndices.remove(_currentIndex);
      _decryptedCache.remove(_currentIndex);
    });
    _loadAndDecrypt(_currentIndex);
  }

  Widget _buildThumbnail(int index) {
    // 缩略图栏不再将上一张的清晰原始字节再解码成缩略图；它只展示当前页
    // 已完成的预览，其他项保持脱敏占位，避免额外的大图解码与闪烁。
    if (index != _currentIndex) {
      return Center(
        child: AnchIcon(
          AnchIcons.image,
          color: context.anchColors.textMuted,
          size: 20,
        ),
      );
    }
    final provider = _decryptedCache.imageAt(index);
    if (provider == null) {
      return Center(
        child: AnchIcon(
          AnchIcons.image,
          color: context.anchColors.textMuted,
          size: 20,
        ),
      );
    }
    return Image(
      image: provider,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) => Center(
        child: AnchIcon(
          AnchIcons.image,
          color: context.anchColors.textMuted,
          size: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ScreenProtectionScope(child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    if (_dismissAfterForeground) return const ColoredBox(color: Colors.black);
    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            "${_currentIndex + 1} / ${widget.attachments.length}",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const AnchIcon(AnchIcons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (_previewIndices.contains(_currentIndex) &&
                !_errorIndices.contains(_currentIndex))
              TextButton(
                key: const Key('view-original-action'),
                onPressed: _loadingIndices.contains(_currentIndex)
                    ? null
                    : _showOriginal,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white38,
                ),
                child: const Text('查看原图'),
              ),
            IconButton(
              key: const Key('save-image-action'),
              tooltip: '保存到相册',
              color: Colors.white,
              disabledColor: Colors.white38,
              icon: _isSavingToGallery
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const AnchIcon(AnchIcons.download),
              // 当前页读取或图片解码未完成时禁用
              onPressed:
                  _decryptedCache.contains(_currentIndex) &&
                      !_loadingIndices.contains(_currentIndex) &&
                      !_isSavingToGallery
                  ? () => _saveCurrentToGallery()
                  : null,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ExtendedImageGesturePageView.builder(
                controller: _pageController,
                itemCount: widget.attachments.length,
                allowImplicitScrolling: false,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  if (_errorIndices.contains(index)) {
                    return _buildImageError(index);
                  }
                  if (_loadingIndices.contains(index) &&
                      !_decryptedCache.contains(index)) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  final provider = _decryptedCache.imageAt(index);
                  if (provider == null) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  final image = _originalRequestedIndices.contains(index)
                      ? provider
                      : _decryptedCache.resizedImageAt(
                          index,
                          width: _previewDecodeWidth(context),
                        )!;
                  return ExtendedImage(
                    image: image,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    mode: ExtendedImageMode.gesture,
                    clearMemoryCacheWhenDispose: false,
                    loadStateChanged: (state) {
                      switch (state.extendedImageLoadState) {
                        case LoadState.loading:
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                        case LoadState.completed:
                          if (_loadingIndices.contains(index)) {
                            _onImageDecoded(index, provider, failed: false);
                          }
                          return null;
                        case LoadState.failed:
                          _onImageDecoded(index, provider, failed: true);
                          return _buildImageError(index);
                      }
                    },
                    initGestureConfigHandler: (_) => GestureConfig(
                      minScale: 1.0,
                      animationMinScale: 1.0,
                      maxScale: 4.0,
                      animationMaxScale: 4.0,
                      initialScale: 1.0,
                      inPageView: true,
                      cacheGesture: false,
                    ),
                  );
                },
              ),
            ),
            if (widget.attachments.length > 1)
              Container(
                height: 80,
                margin: const EdgeInsets.only(bottom: 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _revealCurrentThumbnail(),
                    );
                    return ListView.builder(
                      controller: _thumbnailController,
                      itemExtent: _thumbnailExtent,
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: _thumbnailPadding,
                      ),
                      itemCount: widget.attachments.length,
                      itemBuilder: (context, index) {
                        final isSelected = index == _currentIndex;
                        return GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            key: ValueKey('image_thumbnail_$index'),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 70,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? context.anchColors.accent
                                    : Colors.white24,
                                width: 2.5,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3.5),
                              child: Opacity(
                                opacity: isSelected ? 1.0 : 0.5,
                                child: _buildThumbnail(index),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  static int previewDecodeWidthFor({
    required Size logicalSize,
    required double devicePixelRatio,
  }) {
    final physicalWidth =
        logicalSize.width * devicePixelRatio * _previewDecodeScale;
    return math.min(_maximumPreviewDecodeWidth, physicalWidth.round());
  }

  int _previewDecodeWidth(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return previewDecodeWidthFor(
      logicalSize: mediaQuery.size,
      devicePixelRatio: mediaQuery.devicePixelRatio,
    );
  }
}
