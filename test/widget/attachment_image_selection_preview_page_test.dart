import 'package:anch/features/item_detail/attachment_image_selection_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('多选预览完成时一次返回全部图片', (tester) async {
    Future<List<AttachmentImageSelection>?>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                result = Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AttachmentImageSelectionPreviewPage(
                      files: [
                        XFile('test-image-a.jpg'),
                        XFile('test-image-b.jpg'),
                      ],
                      cropPickedImage: _doNotCrop,
                    ),
                  ),
                );
              },
              child: const Text('打开预览'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开预览'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(tester.widget<Text>(find.text('1 / 2')).style?.color, Colors.white);
    expect(find.text('裁剪'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(await result, hasLength(2));
  });

  testWidgets('320 宽与 200% 字号下预览操作纵排且不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AttachmentImageSelectionPreviewPage(
          files: [XFile('fictional-image.jpg')],
          cropPickedImage: _doNotCrop,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cropRect = tester.getRect(find.text('裁剪'));
    final finishRect = tester.getRect(find.text('完成'));
    expect(cropRect.bottom, lessThanOrEqualTo(finishRect.top));
    expect(tester.takeException(), isNull);
  });
}

Future<XFile?> _doNotCrop(
  NavigatorState navigator,
  XFile pickedFile, {
  bool retainSourceWhenCancelled = false,
}) async => null;
