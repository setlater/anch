@Tags(['security'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:anch/core/attachment/sensitive_image_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('解密图片缓存最多保留三项，淘汰时清零明文字节', (tester) async {
    final cache = SensitiveImageCache();
    final first = Uint8List.fromList([1, 2, 3]);
    final second = Uint8List.fromList([4, 5, 6]);
    final third = Uint8List.fromList([7, 8, 9]);
    final fourth = Uint8List.fromList([10, 11, 12]);

    cache.put(0, first);
    cache.put(1, second);
    cache.put(2, third);
    cache.put(3, fourth);

    expect(cache.contains(0), isFalse);
    expect(cache.contains(1), isTrue);
    expect(first, [0, 0, 0]);

    cache.retainOnly({3});
    expect(cache.contains(1), isFalse);
    expect(cache.contains(2), isFalse);
    expect(second, [0, 0, 0]);
    expect(third, [0, 0, 0]);

    cache.clear();
    expect(cache.contains(3), isFalse);
    expect(fourth, [0, 0, 0]);
  });

  testWidgets('清理时也驱逐缩放预览的图片缓存', (tester) async {
    final cache = SensitiveImageCache();
    cache.put(0, Uint8List.fromList(_validPng));
    final preview = cache.resizedImageAt(0, width: 1)!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Image(image: preview)),
      ),
    );
    await tester.pumpAndSettle();

    final configuration = createLocalImageConfiguration(
      tester.element(find.byType(Image)),
    );
    expect(
      await preview.obtainCacheStatus(configuration: configuration),
      isNotNull,
    );

    cache.clear();
    await tester.pump();

    final status = await preview.obtainCacheStatus(
      configuration: configuration,
    );
    expect(status?.pending, isFalse);
    expect(status?.live, isFalse);
    expect(status?.keepAlive, isFalse);
  });
}

final _validPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL5GQAAAABJRU5ErkJggg==',
);
