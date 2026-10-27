import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// 只用于短暂预览的解密图片缓存。
///
/// 缓存容量严格受限；淘汰和清理时会驱逐 Flutter 图片缓存并清零仍由本类持有的
/// 明文字节，避免随着用户翻页累积敏感图片。
class SensitiveImageCache {
  final int maximumEntries;
  final Map<int, Uint8List> _bytesByIndex = {};
  final Map<int, MemoryImage> _providersByIndex = {};
  final Map<int, Set<ImageProvider>> _displayProvidersByIndex = {};

  SensitiveImageCache({this.maximumEntries = 3}) : assert(maximumEntries > 0);

  bool contains(int index) => _bytesByIndex.containsKey(index);

  Uint8List? bytesAt(int index) => _bytesByIndex[index];

  MemoryImage? imageAt(int index) => _providersByIndex[index];

  /// 返回用于预览的缩放图片，并登记实际使用的缓存键。
  ///
  /// [ResizeImage] 会生成独立的 Flutter 图片缓存键；因此不能只驱逐原始
  /// [MemoryImage]，页面退出后也必须驱逐这个缩放版本。
  ImageProvider? resizedImageAt(int index, {required int width}) {
    final provider = _providersByIndex[index];
    if (provider == null) return null;
    final resizedProvider = ResizeImage(provider, width: width);
    _displayProvidersByIndex
        .putIfAbsent(index, () => {provider})
        .add(resizedProvider);
    return resizedProvider;
  }

  void remove(int index) => _release(index);

  void put(int index, Uint8List bytes) {
    _release(index);
    while (_bytesByIndex.length >= maximumEntries) {
      _release(_bytesByIndex.keys.first);
    }
    _bytesByIndex[index] = bytes;
    final provider = MemoryImage(bytes);
    _providersByIndex[index] = provider;
    _displayProvidersByIndex[index] = {provider};
  }

  void retainOnly(Set<int> indices) {
    for (final index in _bytesByIndex.keys.toList()) {
      if (!indices.contains(index)) {
        _release(index);
      }
    }
  }

  void clear() {
    for (final index in _bytesByIndex.keys.toList()) {
      _release(index);
    }
  }

  void _release(int index) {
    _providersByIndex.remove(index);
    for (final provider in _displayProvidersByIndex.remove(index) ?? {}) {
      unawaited(provider.evict());
    }
    final bytes = _bytesByIndex.remove(index);
    if (bytes != null) {
      bytes.fillRange(0, bytes.length, 0);
    }
  }
}
