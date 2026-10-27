import 'backup_payload.dart';

/// 已完成认证后、仅供当前前台恢复确认页展示的备份内容清单。
///
/// 该模型只保留成员名称、资料标题、类型、收纳状态和附件数量；绝不保留字段值、附件名称／内容、路径、
/// 密码、密钥或原始载荷。它不能写入持久化、日志或异常文本，页面退出、取消恢复或进入后台后必须释放。
///
/// 将清单独立为资料包层模型，后续家人间资料包的发送／接收预览可复用其分组与脱敏边界，但不能复用整库
/// 覆盖恢复语义。
class BackupPackageContentPreview {
  final List<BackupPackageMemberPreview> members;
  final List<BackupPackageItemPreview> unassignedItems;
  final int attachmentCount;

  const BackupPackageContentPreview({
    this.members = const [],
    this.unassignedItems = const [],
    this.attachmentCount = 0,
  });

  int get itemsCount =>
      unassignedItems.length +
      members.fold<int>(0, (sum, member) => sum + member.items.length);

  bool get isEmpty => members.isEmpty && unassignedItems.isEmpty;

  factory BackupPackageContentPreview.fromPayload(BackupPayloadV1 payload) {
    final attachmentCountsByItemId = <String, int>{};
    for (final attachment in payload.data.attachments) {
      attachmentCountsByItemId.update(
        attachment.itemId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final itemPreviewsByMemberId = <String, List<BackupPackageItemPreview>>{};
    final unassignedItems = <BackupPackageItemPreview>[];
    final knownMemberIds = payload.data.members
        .map((member) => member.id)
        .toSet();
    for (final item in payload.data.items) {
      final preview = BackupPackageItemPreview(
        title: item.title,
        typeKey: item.typeKey,
        templateVersion: item.templateVersion,
        status: BackupPackageItemPreviewStatus.fromStorageValue(item.status),
        attachmentCount: attachmentCountsByItemId[item.id] ?? 0,
      );
      final memberId = item.memberId;
      if (memberId == null || !knownMemberIds.contains(memberId)) {
        unassignedItems.add(preview);
      } else {
        itemPreviewsByMemberId.putIfAbsent(memberId, () => []).add(preview);
      }
    }

    return BackupPackageContentPreview(
      members: List.unmodifiable(
        payload.data.members.map(
          (member) => BackupPackageMemberPreview(
            displayName: member.name,
            items: List.unmodifiable(
              itemPreviewsByMemberId[member.id] ?? const [],
            ),
          ),
        ),
      ),
      unassignedItems: List.unmodifiable(unassignedItems),
      attachmentCount: payload.data.attachments.length,
    );
  }

  @override
  String toString() {
    return 'BackupPackageContentPreview('
        'membersCount: ${members.length}, '
        'itemsCount: $itemsCount, '
        'attachmentCount: $attachmentCount'
        ')';
  }
}

/// 恢复清单中的成员分组；不包含成员 ID、关系、备注或其他资料。
class BackupPackageMemberPreview {
  final String displayName;
  final List<BackupPackageItemPreview> items;

  const BackupPackageMemberPreview({
    required this.displayName,
    required this.items,
  });

  @override
  String toString() =>
      'BackupPackageMemberPreview(itemsCount: ${items.length})';
}

/// 恢复清单中的单条资料；不包含字段、备注、派生摘要、附件名称或附件内容。
class BackupPackageItemPreview {
  final String? title;
  final String? typeKey;
  final int templateVersion;
  final BackupPackageItemPreviewStatus status;
  final int attachmentCount;

  const BackupPackageItemPreview({
    required this.title,
    required this.typeKey,
    required this.templateVersion,
    required this.status,
    required this.attachmentCount,
  });

  @override
  String toString() {
    return 'BackupPackageItemPreview('
        'status: ${status.name}, '
        'attachmentCount: $attachmentCount'
        ')';
  }
}

enum BackupPackageItemPreviewStatus {
  active,
  archived,
  deleted,
  unknown;

  static BackupPackageItemPreviewStatus fromStorageValue(String value) {
    return switch (value) {
      'active' => BackupPackageItemPreviewStatus.active,
      'archived' => BackupPackageItemPreviewStatus.archived,
      'deleted' => BackupPackageItemPreviewStatus.deleted,
      _ => BackupPackageItemPreviewStatus.unknown,
    };
  }
}
