import 'package:anch/core/backup/backup_package_content_preview.dart';
import 'package:anch/core/backup/backup_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('认证后的恢复清单按成员列出资料状态和附件数量，且 toString 不泄露展示内容', () {
    final payload = BackupPayloadV1(
      exportedAt: 1718035200000,
      appVersion: '1.0.0-test',
      schemaVersion: 8,
      source: BackupSourceInfo(
        appId: 'icu.codealive.anch.test',
        platform: 'android-test',
        exportMode: 'manual',
      ),
      data: BackupDataV1(
        members: [
          _member(id: 'member-a', name: 'TEST-成员甲'),
          _member(id: 'member-b', name: 'TEST-成员乙'),
        ],
        items: [
          _item(
            id: 'item-active',
            memberId: 'member-a',
            title: 'TEST-当前资料',
            status: 'active',
          ),
          _item(
            id: 'item-archived',
            memberId: 'member-a',
            title: 'TEST-归档资料',
            status: 'archived',
          ),
          _item(
            id: 'item-deleted',
            memberId: 'member-b',
            title: 'TEST-删除资料',
            status: 'deleted',
          ),
          _item(
            id: 'item-unassigned',
            memberId: null,
            title: 'TEST-未归属资料',
            status: 'unexpected',
          ),
        ],
        itemFields: const [],
        appSettings: const [],
        attachments: [
          _attachment(id: 'attachment-1', itemId: 'item-active'),
          _attachment(id: 'attachment-2', itemId: 'item-active'),
          _attachment(id: 'attachment-3', itemId: 'item-deleted'),
        ],
      ),
    );

    final preview = BackupPackageContentPreview.fromPayload(payload);

    expect(preview.members, hasLength(2));
    expect(preview.itemsCount, 4);
    expect(preview.attachmentCount, 3);
    expect(preview.members.first.displayName, 'TEST-成员甲');
    expect(preview.members.first.items, hasLength(2));
    expect(
      preview.members.first.items.first.status,
      BackupPackageItemPreviewStatus.active,
    );
    expect(
      preview.members.first.items[1].status,
      BackupPackageItemPreviewStatus.archived,
    );
    expect(preview.members.first.items.first.attachmentCount, 2);
    expect(
      preview.members[1].items.single.status,
      BackupPackageItemPreviewStatus.deleted,
    );
    expect(preview.members[1].items.single.attachmentCount, 1);
    expect(
      preview.unassignedItems.single.status,
      BackupPackageItemPreviewStatus.unknown,
    );

    final text =
        '${preview.members.first} ${preview.members.first.items.first} $preview';
    expect(text, isNot(contains('TEST-成员甲')));
    expect(text, isNot(contains('TEST-当前资料')));
    expect(text, isNot(contains('TEST-附件内容')));
  });
}

BackupMemberV1 _member({required String id, required String name}) {
  return BackupMemberV1(
    id: id,
    name: name,
    relationKey: 'other',
    isSystem: false,
    sortOrder: 0,
    createdAt: 1718035200000,
    updatedAt: 1718035200000,
    isArchived: false,
  );
}

BackupItemV1 _item({
  required String id,
  required String? memberId,
  required String title,
  required String status,
}) {
  return BackupItemV1(
    id: id,
    memberId: memberId,
    categoryKey: 'other',
    typeKey: 'generic',
    templateVersion: 1,
    title: title,
    createdAt: 1718035200000,
    updatedAt: 1718035200000,
    isFavorite: false,
    isPinned: false,
    sortOrder: 0,
    status: status,
  );
}

BackupAttachmentV1 _attachment({required String id, required String itemId}) {
  return BackupAttachmentV1(
    id: id,
    itemId: itemId,
    attachmentRole: 'other',
    fileName: 'TEST-attachment-name',
    mimeType: 'application/octet-stream',
    plainSize: 1,
    encryptedSize: 1,
    sortOrder: 0,
    status: 'active',
    createdAt: 1718035200000,
    updatedAt: 1718035200000,
    encryptedData: 'TEST-附件内容',
  );
}
