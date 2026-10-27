@Tags(['security'])
library;

import 'package:anch/core/attachment/attachment_model.dart';
import 'package:anch/core/attachment/attachment_preview_policy.dart';
import 'package:anch/features/item_detail/decrypted_document_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('超过内置文本预览上限时不读取或排版全文', (tester) async {
    const attachment = AttachmentModel(
      id: 'attachment-id',
      itemId: 'item-id',
      attachmentRole: 'proof',
      fileName: 'attachment.enc',
      originalName: 'large.txt',
      mimeType: 'text/plain',
      plainSize: AttachmentPreviewPolicy.maxInlineTextPreviewBytes + 1,
      encryptedSize: AttachmentPreviewPolicy.maxInlineTextPreviewBytes + 29,
      sortOrder: 0,
      status: 'active',
      createdAt: 0,
      updatedAt: 0,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: DecryptedDocumentPreviewPage(attachment: attachment),
      ),
    );
    await tester.pump();

    expect(find.text('该文本附件较大，无法在应用内预览。请返回后使用其他应用打开。'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('实际后台后在恢复前台安全退出，inactive 不退页', (tester) async {
    const attachment = AttachmentModel(
      id: 'attachment-id',
      itemId: 'item-id',
      attachmentRole: 'proof',
      fileName: 'attachment.enc',
      originalName: 'large.txt',
      mimeType: 'text/plain',
      plainSize: AttachmentPreviewPolicy.maxInlineTextPreviewBytes + 1,
      encryptedSize: AttachmentPreviewPolicy.maxInlineTextPreviewBytes + 29,
      sortOrder: 0,
      status: 'active',
      createdAt: 0,
      updatedAt: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const DecryptedDocumentPreviewPage(attachment: attachment),
              ),
            ),
            child: const Text('详情页'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('详情页'));
    await tester.pump(const Duration(milliseconds: 400));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('文本预览'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('文本预览'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('详情页'), findsOneWidget);
    expect(find.byType(DecryptedDocumentPreviewPage), findsNothing);
  });
}
