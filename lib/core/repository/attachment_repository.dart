import 'dart:math';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../attachment/attachment_model.dart';
import '../attachment/save_attachment_input.dart';

/// 加密附件元信息数据访问仓储
class AttachmentRepository {
  final AppDatabase db;

  /// DO NOT instantiate directly outside DI layer.
  AttachmentRepository(this.db);

  /// 转换数据库物理实体至业务模型
  AttachmentModel _mapToModel(Attachment f) {
    return AttachmentModel(
      id: f.id,
      originAttachmentId: f.originAttachmentId,
      itemId: f.itemId,
      linkedFieldKey: f.linkedFieldKey,
      attachmentRole: f.attachmentRole,
      fileName: f.fileName,
      originalName: f.originalName,
      mimeType: f.mimeType,
      plainSize: f.plainSize,
      encryptedSize: f.encryptedSize,
      sha256: f.sha256,
      sortOrder: f.sortOrder,
      status: f.status,
      createdAt: f.createdAt,
      updatedAt: f.updatedAt,
    );
  }

  /// 原生生成高安全强度的 UUID v4 字符串
  String _generateUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // version 4
    values[8] = (values[8] & 0x3f) | 0x80; // variant RFC4122

    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// 获取指定资料下的所有活跃附件记录
  Future<List<AttachmentModel>> getAttachmentsByItemId(String itemId) async {
    final list =
        await (db.select(db.attachments)
              ..where(
                (tbl) =>
                    tbl.itemId.equals(itemId) & tbl.status.equals('active'),
              )
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.sortOrder)]))
            .get();
    return list.map(_mapToModel).toList();
  }

  /// 返回活跃附件数量，仅用于本地数据概览。
  Future<int> getActiveAttachmentCount() {
    final countExpression = db.attachments.id.count();
    return (db.selectOnly(db.attachments)
          ..addColumns([countExpression])
          ..where(db.attachments.status.equals('active')))
        .map((row) => row.read(countExpression) ?? 0)
        .getSingle();
  }

  /// 根据 ID 获取单个附件记录
  Future<AttachmentModel?> getAttachmentById(String id) async {
    final record = await (db.select(
      db.attachments,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (record == null) return null;
    return _mapToModel(record);
  }

  /// 插入或更新附件元信息记录
  Future<String> insertAttachment(SaveAttachmentInput input) async {
    final attachmentId = input.id ?? _generateUuid();
    final now = DateTime.now().millisecondsSinceEpoch;

    int createdAtVal = now;
    Attachment? existingAttachment;
    if (input.id != null) {
      existingAttachment = await (db.select(
        db.attachments,
      )..where((tbl) => tbl.id.equals(attachmentId))).getSingleOrNull();
      if (existingAttachment != null) {
        createdAtVal = existingAttachment.createdAt;
      }
    }

    final companion = AttachmentsCompanion(
      id: Value(attachmentId),
      originAttachmentId: Value(
        existingAttachment?.originAttachmentId ??
            input.originAttachmentId ??
            attachmentId,
      ),
      itemId: Value(input.itemId),
      linkedFieldKey: Value(input.linkedFieldKey),
      attachmentRole: Value(input.attachmentRole),
      fileName: Value(input.fileName),
      originalName: Value(input.originalName),
      mimeType: Value(input.mimeType),
      plainSize: Value(input.plainSize),
      encryptedSize: Value(input.encryptedSize),
      sha256: Value(input.sha256),
      sortOrder: Value(input.sortOrder),
      status: const Value('active'),
      createdAt: Value(createdAtVal),
      updatedAt: Value(now),
    );

    await db.into(db.attachments).insertOnConflictUpdate(companion);
    return attachmentId;
  }

  /// 从数据库中物理删除附件记录
  Future<void> deleteAttachment(String id) async {
    await (db.delete(db.attachments)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// 删除指定资料下的所有附件记录
  Future<void> deleteAttachmentsByItemId(String itemId) async {
    await (db.delete(
      db.attachments,
    )..where((tbl) => tbl.itemId.equals(itemId))).go();
  }
}
