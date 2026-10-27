@Tags(['security'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:anch/core/attachment/attachment_model.dart';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:anch/features/item_detail/decrypted_image_preview_page.dart';
import 'package:anch/features/item_detail/image_preview_payload_loader.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('图片失败可就地重试，加载时保存禁用且明确变暗', (tester) async {
    await tester.binding.setSurfaceSize(const Size(560, 280));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final read = Completer<Uint8List>();
    final retry = Completer<Uint8List>();
    var readCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: DecryptedImagePreviewPage(
          attachments: const [
            AttachmentModel(
              id: 'fictional-image',
              itemId: 'fictional-item',
              attachmentRole: 'proof',
              fileName: 'fictional-image.enc',
              mimeType: 'image/jpeg',
              plainSize: 1,
              encryptedSize: 29,
              sortOrder: 0,
              status: 'active',
              createdAt: 1,
              updatedAt: 1,
            ),
            _secondAttachment,
          ],
          initialIndex: 0,
          readPayloadInBackground: (_) {
            readCount++;
            return readCount == 1 ? read.future : retry.future;
          },
        ),
      ),
    );

    final closeIcon = find.byWidgetPredicate(
      (widget) => widget is AnchIcon && widget.icon == AnchIcons.close,
    );
    final downloadIcon = find.byWidgetPredicate(
      (widget) => widget is AnchIcon && widget.icon == AnchIcons.download,
    );

    expect(tester.widget<AnchIcon>(closeIcon).color, Colors.white);
    expect(IconTheme.of(tester.element(downloadIcon)).color, Colors.white38);
    final save = find.byKey(const Key('save-image-action'));
    expect(tester.widget<IconButton>(save).onPressed, isNull);
    read.completeError(StateError('fictional-read-failed'));
    await tester.pumpAndSettle();
    expect(find.text('附件暂时无法预览'), findsOneWidget);
    expect(tester.widget<IconButton>(save).onPressed, isNull);
    expect(IconTheme.of(tester.element(downloadIcon)).color, Colors.white38);
    expect(readCount, 1);
    await tester.ensureVisible(find.text('重新加载'));
    await tester.tap(find.text('重新加载'));
    await tester.pump();
    expect(readCount, 2);
    expect(find.text('重新加载'), findsNothing);
    expect(tester.widget<IconButton>(save).onPressed, isNull);
    expect(IconTheme.of(tester.element(downloadIcon)).color, Colors.white38);
    retry.complete(Uint8List.fromList(_validPng));
    await _settleDecodedImages(tester);
    expect(find.text('附件暂时无法预览'), findsNothing);
    expect(tester.widget<IconButton>(save).onPressed, isNotNull);
    expect(IconTheme.of(tester.element(downloadIcon)).color, Colors.white);
  });

  for (final usesPreview in [false, true]) {
    testWidgets('${usesPreview ? '缓存预览' : '原图'}解码失败可重试原图，清零失败字节并禁用保存', (
      tester,
    ) async {
      final invalidImage = Uint8List.fromList([1, 2, 3]);
      var readCount = 0;
      var invalidateCount = 0;
      final invalidation = Completer<void>();
      final originalRequests = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: DecryptedImagePreviewPage(
            attachments: const [_attachment, _secondAttachment],
            initialIndex: 0,
            loadPreviewPayload:
                (
                  _, {
                  required forceOriginal,
                  onPreparingPreview,
                  shouldStorePreview,
                }) async {
                  readCount++;
                  originalRequests.add(forceOriginal);
                  return ImagePreviewPayload(
                    bytes: readCount == 1 || (usesPreview && !forceOriginal)
                        ? invalidImage
                        : Uint8List.fromList(_validPng),
                    usesPreview: usesPreview && !forceOriginal,
                    invalidatePreview: usesPreview && !forceOriginal
                        ? () async {
                            invalidateCount++;
                            await invalidation.future;
                          }
                        : null,
                  );
                },
          ),
        ),
      );
      await _settleDecodedImages(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('附件暂时无法预览'), findsOneWidget);
      final save = find.byKey(const Key('save-image-action'));
      expect(tester.widget<IconButton>(save).onPressed, isNull);
      expect(invalidImage.every((byte) => byte == 0), isTrue);
      expect(readCount, 1);
      expect(invalidateCount, usesPreview ? 1 : 0);
      if (usesPreview) {
        final retry = find.widgetWithText(TextButton, '重新加载');
        expect(tester.widget<TextButton>(retry).onPressed, isNull);
        await tester.tap(retry);
        await tester.pump();
        expect(readCount, 1);
        invalidation.completeError(StateError('synthetic cleanup failure'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextButton>(retry).onPressed, isNotNull);
      }
      await tester.tap(find.text('重新加载'));
      await _settleDecodedImages(tester);
      expect(readCount, 2);
      expect(originalRequests, [false, usesPreview]);
      expect(find.text('附件暂时无法预览'), findsNothing);
      expect(tester.widget<IconButton>(save).onPressed, isNotNull);
    });
  }

  testWidgets('多图预览先完成转场且初次只解密当前图片', (tester) async {
    final requestedIds = <String>[];
    final readerCompleter = Completer<Uint8List>();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DecryptedImagePreviewPage(
                  attachments: const [
                    _attachment,
                    _secondAttachment,
                    _thirdAttachment,
                  ],
                  initialIndex: 1,
                  readPayloadInBackground: (attachment) async {
                    requestedIds.add(attachment.id);
                    return readerCompleter.future;
                  },
                ),
              ),
            ),
            child: const Text('打开预览'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开预览'));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(requestedIds, ['fictional-image-2']);
  });

  testWidgets('初次打开末图、切页往返和窗口缩窄时选中缩略图保持完整可见', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final attachments = [
      for (var i = 0; i < 8; i++)
        AttachmentModel(
          id: 'fictional-$i',
          itemId: 'fictional-item',
          attachmentRole: 'proof',
          fileName: 'fictional-$i.enc',
          mimeType: 'image/png',
          plainSize: _validPng.length,
          encryptedSize: _validPng.length + 28,
          sortOrder: i,
          status: 'active',
          createdAt: 1,
          updatedAt: 1,
        ),
    ];
    void expectVisible(WidgetTester tester, int index) {
      final selected = find.byKey(ValueKey('image_thumbnail_$index'));
      expect(selected, findsOneWidget);
      final viewport = tester.getRect(find.byType(ListView));
      final thumbnail = tester.getRect(selected);
      expect(thumbnail.left, greaterThanOrEqualTo(viewport.left - .5));
      expect(thumbnail.right, lessThanOrEqualTo(viewport.right + .5));
    }

    for (final width in [320.0, 600.0, 1000.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(Size(width, 800));
      final reads = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: DecryptedImagePreviewPage(
            attachments: attachments,
            initialIndex: 7,
            readPayloadInBackground: (attachment) async {
              reads.add(attachment.id);
              return Uint8List.fromList(_validPng);
            },
          ),
        ),
      );
      await _settleDecodedImages(tester);
      expectVisible(tester, 7);
      expect(reads, ['fictional-7']);
      final pages = tester.widget<ExtendedImageGesturePageView>(
        find.byType(ExtendedImageGesturePageView),
      );
      pages.controller.jumpToPage(0);
      await _settleDecodedImages(tester);
      expectVisible(tester, 0);
      pages.controller.jumpToPage(7);
      await _settleDecodedImages(tester);
      expectVisible(tester, 7);
      await tester.binding.setSurfaceSize(const Size(320, 800));
      await tester.pumpAndSettle();
      expectVisible(tester, 7);
      expect(reads, ['fictional-7', 'fictional-0']);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('首次读取图片时只显示单一加载圈', (tester) async {
    final readerCompleter = Completer<Uint8List>();

    await tester.pumpWidget(
      MaterialApp(
        home: DecryptedImagePreviewPage(
          attachments: const [_attachment, _secondAttachment],
          initialIndex: 0,
          readPayloadInBackground: (_) => readerCompleter.future,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    readerCompleter.complete(Uint8List.fromList(_validPng));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await _settleDecodedImages(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('返回上一张普通预览不会重复读取图片', (tester) async {
    final requestedIds = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: DecryptedImagePreviewPage(
          attachments: const [_attachment, _secondAttachment],
          initialIndex: 0,
          readPayloadInBackground: (attachment) async {
            requestedIds.add(attachment.id);
            return Uint8List.fromList(_validPng);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final pageView = find.byType(ExtendedImageGesturePageView);
    await tester.drag(pageView, const Offset(-400, 0));
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(pageView, const Offset(400, 0));
    await tester.pump(const Duration(seconds: 1));

    expect(requestedIds, ['fictional-image', 'fictional-image-2']);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('保存图片期间阻止重复写入并在完成后提示', (tester) async {
    final saveCompleter = Completer<void>();
    var saveCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DecryptedImagePreviewPage(
          attachments: const [_attachment],
          initialIndex: 0,
          readPayloadInBackground: (_) async => Uint8List.fromList(_validPng),
          saveImageToGallery: (_) async {
            saveCount++;
            await saveCompleter.future;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final saveAction = find.byKey(const Key('save-image-action'));
    await _settleDecodedImages(tester);
    expect(tester.widget<IconButton>(saveAction).onPressed, isNotNull);
    await tester.pump(const Duration(milliseconds: 200));
    final downloadIcon = find.descendant(
      of: saveAction,
      matching: find.byType(AnchIcon),
    );
    expect(IconTheme.of(tester.element(downloadIcon)).color, Colors.white);

    await tester.tap(saveAction);
    await tester.pump();
    expect(saveCount, 1);
    expect(
      find.descendant(
        of: saveAction,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<IconButton>(saveAction).onPressed, isNull);

    await tester.tap(saveAction);
    await tester.pump();
    expect(saveCount, 1);

    saveCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.widget<IconButton>(saveAction).onPressed, isNotNull);
    expect(find.text('已保存到系统相册'), findsOneWidget);
  });

  testWidgets('加密预览可在需要细节时切换查看原图', (tester) async {
    final forceOriginalRequests = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DecryptedImagePreviewPage(
          attachments: const [_attachment],
          initialIndex: 0,
          loadPreviewPayload:
              (
                _, {
                required forceOriginal,
                onPreparingPreview,
                shouldStorePreview,
              }) async {
                forceOriginalRequests.add(forceOriginal);
                return ImagePreviewPayload(
                  bytes: Uint8List.fromList(_validPng),
                  usesPreview: !forceOriginal,
                );
              },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await _settleDecodedImages(tester);
    expect(find.byKey(const Key('view-original-action')), findsOneWidget);
    final image = find.byType(ExtendedImage);
    expect(tester.widget<ExtendedImage>(image).image, isA<ResizeImage>());
    await tester.tap(find.byKey(const Key('view-original-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(forceOriginalRequests, <bool>[false, true]);
    expect(find.byKey(const Key('view-original-action')), findsNothing);
    expect(tester.widget<ExtendedImage>(image).image, isA<MemoryImage>());
  });

  testWidgets('选择原图后相邻往返不重复读取且保持原图选择', (tester) async {
    final requests = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DecryptedImagePreviewPage(
          attachments: const [_attachment, _secondAttachment],
          initialIndex: 0,
          loadPreviewPayload:
              (
                attachment, {
                required forceOriginal,
                onPreparingPreview,
                shouldStorePreview,
              }) async {
                requests.add('${attachment.id}:$forceOriginal');
                return ImagePreviewPayload(
                  bytes: Uint8List.fromList(_validPng),
                  usesPreview: !forceOriginal,
                );
              },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await _settleDecodedImages(tester);
    await tester.tap(find.byKey(const Key('view-original-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final pageView = find.byType(ExtendedImageGesturePageView);
    await tester.drag(pageView, const Offset(-400, 0));
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(pageView, const Offset(400, 0));
    await tester.pump(const Duration(seconds: 1));

    expect(requests, [
      'fictional-image:false',
      'fictional-image:true',
      'fictional-image-2:false',
    ]);
    expect(find.byKey(const Key('view-original-action')), findsNothing);
  });

  for (final pendingRetry in [false, true]) {
    testWidgets('${pendingRetry ? '正在重试' : '已加载'}时实际后台安全清理退出，inactive 不退页', (
      tester,
    ) async {
      final retry = Completer<Uint8List>();
      final bytes = Uint8List.fromList(_validPng);
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DecryptedImagePreviewPage(
                    attachments: const [_attachment],
                    initialIndex: 0,
                    readPayloadInBackground: (_) async {
                      reads++;
                      if (!pendingRetry) return bytes;
                      if (reads == 1) throw StateError('fictional-read-failed');
                      return retry.future;
                    },
                  ),
                ),
              ),
              child: const Text('详情页'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('详情页'));
      await tester.pump(const Duration(milliseconds: 400));
      await _settleDecodedImages(tester);
      if (pendingRetry) {
        await tester.tap(find.text('重新加载'));
        await tester.pump();
        expect(reads, 2);
      }

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('1 / 1'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      if (pendingRetry) {
        retry.complete(bytes);
        await tester.pump();
      }
      expect(bytes.every((value) => value == 0), isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('详情页'), findsOneWidget);
      expect(find.byType(DecryptedImagePreviewPage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('图片预览使用边缘接力分页组件并可切图', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DecryptedImagePreviewPage(
          attachments: const [_attachment, _secondAttachment],
          initialIndex: 0,
          readPayloadInBackground: (_) async => Uint8List.fromList(_validPng),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final pageView = find.byType(ExtendedImageGesturePageView);
    expect(pageView, findsOneWidget);
    await tester.drag(pageView, const Offset(-400, 0));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('2 / 2'), findsOneWidget);
  });

  test('大图预览按当前屏幕尺寸限制解码宽度', () {
    expect(
      DecryptedImagePreviewPageState.previewDecodeWidthFor(
        logicalSize: const Size(360, 800),
        devicePixelRatio: 3,
      ),
      2048,
    );
    expect(
      DecryptedImagePreviewPageState.previewDecodeWidthFor(
        logicalSize: const Size(240, 480),
        devicePixelRatio: 2,
      ),
      960,
    );
  });
}

const _attachment = AttachmentModel(
  id: 'fictional-image',
  itemId: 'fictional-item',
  attachmentRole: 'proof',
  fileName: 'fictional-image.enc',
  mimeType: 'image/jpeg',
  plainSize: 1,
  encryptedSize: 29,
  sortOrder: 0,
  status: 'active',
  createdAt: 1,
  updatedAt: 1,
);

const _secondAttachment = AttachmentModel(
  id: 'fictional-image-2',
  itemId: 'fictional-item',
  attachmentRole: 'proof',
  fileName: 'fictional-image-2.enc',
  mimeType: 'image/jpeg',
  plainSize: 1,
  encryptedSize: 29,
  sortOrder: 1,
  status: 'active',
  createdAt: 1,
  updatedAt: 1,
);

const _thirdAttachment = AttachmentModel(
  id: 'fictional-image-3',
  itemId: 'fictional-item',
  attachmentRole: 'proof',
  fileName: 'fictional-image-3.enc',
  mimeType: 'image/jpeg',
  plainSize: 1,
  encryptedSize: 29,
  sortOrder: 2,
  status: 'active',
  createdAt: 1,
  updatedAt: 1,
);

Future<void> _settleDecodedImages(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    for (final element in find.byType(ExtendedImage).evaluate()) {
      final image = element.widget as ExtendedImage;
      await precacheImage(image.image, element, onError: (_, _) {});
    }
  });
  await tester.pumpAndSettle();
}

final _validPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAEklEQVR4nGNIyav4j4wZSBcAAMzIJJFx64scAAAAAElFTkSuQmCC',
);
