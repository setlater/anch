import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/encrypted_attachment_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/anch_icon_finder.dart';

void main() {
  testWidgets('缺失附件只显示脱敏失败态，不暴露文件名或路径', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 100,
          height: 100,
          child: EncryptedAttachmentThumbnail(
            fileName: 'sensitive-file.enc',
            encryptedBytesProvider: () async => null,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(findAnchIcon(AnchIcons.image), findsOneWidget);
    for (final element in find.byType(Text).evaluate()) {
      expect((element.widget as Text).data, isNot(contains('sensitive-file')));
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
