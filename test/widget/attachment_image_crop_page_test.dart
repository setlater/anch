import 'package:anch/features/item_detail/attachment_image_crop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('初始缩放的浮点误差不会反转图片回弹范围', () {
    final offset = AttachmentImageCropPage.clampImageOffset(
      imageOffset: const Offset(24, 24),
      cropRect: const Rect.fromLTWH(24, 24, 300, 200),
      scaledImageSize: const Size(299.999999999943, 200),
    );

    expect(offset, const Offset(24, 24));
  });

  test('初始裁剪框按原图比例完整放入可视区域', () {
    const viewport = Size(360, 640);
    const sourceSize = Size(600, 1200);

    final cropRect = AttachmentImageCropPage.initialCropRectFor(
      viewport: viewport,
      sourceSize: sourceSize,
    );

    expect(cropRect.center, viewport.center(Offset.zero));
    expect(
      cropRect.width / sourceSize.width,
      closeTo(cropRect.height / sourceSize.height, 0.000001),
    );
    expect(cropRect.left, greaterThanOrEqualTo(24));
    expect(cropRect.top, greaterThanOrEqualTo(24));
    expect(cropRect.right, lessThanOrEqualTo(336));
    expect(cropRect.bottom, lessThanOrEqualTo(616));
  });

  testWidgets('320 宽与 200% 字号下裁剪角度操作可换行且不溢出', (tester) async {
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
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AttachmentCropRotationQuickActions(
              rotationDegrees: 0,
              isExporting: false,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('attachment_crop_rotation_actions_wrap')),
      findsOneWidget,
    );
    expect(find.text('重置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
