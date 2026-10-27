import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../attachment/attachment_crypto_service.dart';
import '../attachment/attachment_thumbnail_cache.dart';
import '../theme/anch_colors.dart';

/// 用于列表和录入页的短生命周期加密附件缩略图。
///
/// 只读取独立的小缩略图缓存，绝不为列表或详情缩略图回退读取大原附件。
class EncryptedAttachmentThumbnail extends StatefulWidget {
  final String fileName;
  final bool showProgressIndicator;
  final Future<Directory> Function()? documentsDirectoryProvider;
  final Future<Uint8List?> Function()? encryptedBytesProvider;

  const EncryptedAttachmentThumbnail({
    super.key,
    required this.fileName,
    this.showProgressIndicator = false,
    this.documentsDirectoryProvider,
    this.encryptedBytesProvider,
  });

  @override
  State<EncryptedAttachmentThumbnail> createState() =>
      _EncryptedAttachmentThumbnailState();
}

class _EncryptedAttachmentThumbnailState
    extends State<EncryptedAttachmentThumbnail> {
  Uint8List? _decryptedBytes;
  MemoryImage? _imageProvider;
  bool _loading = true;
  bool _failed = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadAndDecrypt();
  }

  @override
  void didUpdateWidget(covariant EncryptedAttachmentThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileName != widget.fileName) {
      _releaseSensitiveImage();
      setState(() {
        _loading = true;
        _failed = false;
      });
      _loadAndDecrypt();
    }
  }

  Future<void> _loadAndDecrypt() async {
    final generation = ++_loadGeneration;
    try {
      final plainBytes = widget.encryptedBytesProvider == null
          ? await AttachmentThumbnailCache.read(
              widget.fileName,
              documentsDirectoryProvider: widget.documentsDirectoryProvider,
            )
          : await _readInjectedEncryptedBytes();
      if (plainBytes == null) {
        if (mounted && generation == _loadGeneration) {
          setState(() {
            _loading = false;
            _failed = true;
          });
        }
        return;
      }
      if (!mounted || generation != _loadGeneration) {
        plainBytes.fillRange(0, plainBytes.length, 0);
        return;
      }
      setState(() {
        _decryptedBytes = plainBytes;
        _imageProvider = MemoryImage(plainBytes);
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<Uint8List?> _readInjectedEncryptedBytes() async {
    final encryptedBytes = await widget.encryptedBytesProvider!.call();
    if (encryptedBytes == null) return null;
    try {
      return await AttachmentCryptoService.decryptData(encryptedBytes);
    } finally {
      encryptedBytes.fillRange(0, encryptedBytes.length, 0);
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _releaseSensitiveImage();
    super.dispose();
  }

  void _releaseSensitiveImage() {
    _imageProvider?.evict();
    _imageProvider = null;
    final bytes = _decryptedBytes;
    _decryptedBytes = null;
    if (bytes != null) {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      if (widget.showProgressIndicator) {
        return const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      return Center(
        child: AnchIcon(
          AnchIcons.image,
          color: context.anchColors.textMuted,
          size: 24,
        ),
      );
    }
    if (_failed || _imageProvider == null) {
      return Center(
        child: AnchIcon(
          AnchIcons.image,
          color: context.anchColors.textMuted,
          size: 24,
        ),
      );
    }
    return Image(
      image: _imageProvider!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
