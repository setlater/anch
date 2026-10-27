import 'package:anch/core/attachment/attachment_model.dart';
import 'package:anch/core/widgets/encrypted_attachment_thumbnail.dart';
import 'package:anch/features/item_entry/item_entry_supplement_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('附件缩略图在窄屏内容区仍均分为两列', () {
    const availableWidth = 296.0;

    final slotWidth = ItemEntrySupplementSection.attachmentSlotWidthFor(
      availableWidth,
    );

    expect(slotWidth, 142);
    expect(slotWidth * 2 + 12, availableWidth);
  });

  testWidgets('非图片附件在编辑页显示文件卡片，不进入图片解码器', (tester) async {
    const attachment = AttachmentModel(
      id: 'fake-file',
      itemId: 'fake-item',
      attachmentRole: 'other',
      fileName: 'fake-file.enc',
      originalName: 'fake.pdf',
      mimeType: 'application/pdf',
      plainSize: 1,
      encryptedSize: 1,
      sortOrder: 0,
      status: 'active',
      createdAt: 0,
      updatedAt: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItemEntrySupplementSection(
            attachments: const [attachment],
            onAddAttachment: () {},
            onDeleteAttachment: (_) {},
            noteInput: const SizedBox.shrink(),
            householdMemberSection: null,
            expiryPreview: null,
            isKeyboardVisible: false,
            existingItemId: 'fake-item',
            isSaving: false,
            onSave: () {},
          ),
        ),
      ),
    );

    expect(find.text('PDF'), findsOneWidget);
    expect(find.byType(EncryptedAttachmentThumbnail), findsNothing);
  });

  testWidgets('补充资料内容与页面边距对齐，不叠加分组横向边距', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItemEntrySupplementSection(
            attachments: const [],
            onAddAttachment: () {},
            onDeleteAttachment: (_) {},
            noteInput: const Text('备注'),
            householdMemberSection: null,
            expiryPreview: null,
            isKeyboardVisible: false,
            existingItemId: null,
            isSaving: false,
            onSave: () {},
          ),
        ),
      ),
    );

    expect(tester.getRect(find.text('附件')).left, 16);
    expect(tester.getRect(find.text('备注')).left, 16);
  });

  testWidgets('附件达到上限时不显示添加附件入口', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItemEntrySupplementSection(
            attachments: List.generate(12, _fakeAttachment),
            showAddAttachment: false,
            onAddAttachment: () {},
            onDeleteAttachment: (_) {},
            noteInput: const SizedBox.shrink(),
            householdMemberSection: null,
            expiryPreview: null,
            isKeyboardVisible: false,
            existingItemId: null,
            isSaving: false,
            onSave: () {},
          ),
        ),
      ),
    );

    expect(find.text('添加附件或照片'), findsNothing);
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
