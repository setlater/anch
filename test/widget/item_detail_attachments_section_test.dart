import 'package:anch/core/attachment/attachment_model.dart';
import 'package:anch/features/item_detail/item_detail_attachments_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('附件达到上限时详情页不显示添加附件按钮', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItemDetailAttachmentsSection(
            attachments: List.generate(12, _fakeAttachment),
            showAddAttachment: false,
            onAddAttachment: () {},
            onPreviewImages: (_, _) {},
            onOpenFileAttachment: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('add_attachment_button')), findsNothing);
  });

  testWidgets('文件附件不在点击前常驻显示打开方式', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItemDetailAttachmentsSection(
            attachments: [
              _fileAttachment(
                id: 'small-text',
                mimeType: 'text/plain',
                plainSize: 512 * 1024,
              ),
              _fileAttachment(
                id: 'large-text',
                mimeType: 'text/plain',
                plainSize: 512 * 1024 + 1,
              ),
              _fileAttachment(
                id: 'pdf',
                mimeType: 'application/pdf',
                plainSize: 1,
              ),
            ],
            onAddAttachment: () {},
            onPreviewImages: (_, _) {},
            onOpenFileAttachment: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('预览'), findsNothing);
    expect(find.text('外部打开'), findsNothing);
    expect(
      find.text('小于 512 KB 的文本可在应用内预览；PDF、文档和较大文本将使用其他应用打开。'),
      findsNothing,
    );
  });
}

AttachmentModel _fakeAttachment(int index) => AttachmentModel(
  id: 'fake-$index',
  itemId: 'fake-item',
  attachmentRole: 'other',
  fileName: 'fake-$index.enc',
  originalName: 'fake-$index.jpg',
  mimeType: 'image/jpeg',
  plainSize: 1,
  encryptedSize: 1,
  sortOrder: index,
  status: 'active',
  createdAt: 0,
  updatedAt: 0,
);

AttachmentModel _fileAttachment({
  required String id,
  required String mimeType,
  required int plainSize,
}) => AttachmentModel(
  id: id,
  itemId: 'fake-item',
  attachmentRole: 'other',
  fileName: '$id.enc',
  originalName: '$id.txt',
  mimeType: mimeType,
  plainSize: plainSize,
  encryptedSize: plainSize + 28,
  sortOrder: 0,
  status: 'active',
  createdAt: 0,
  updatedAt: 0,
);
