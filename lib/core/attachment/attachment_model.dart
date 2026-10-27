class AttachmentModel {
  final String id;
  final String originAttachmentId;
  final String itemId;
  final String? linkedFieldKey;
  final String attachmentRole;
  final String fileName;
  final String? originalName;
  final String mimeType;
  final int plainSize;
  final int encryptedSize;
  final String? sha256;
  final int sortOrder;
  final String status;
  final int createdAt;
  final int updatedAt;

  const AttachmentModel({
    required this.id,
    String? originAttachmentId,
    required this.itemId,
    this.linkedFieldKey,
    required this.attachmentRole,
    required this.fileName,
    this.originalName,
    required this.mimeType,
    required this.plainSize,
    required this.encryptedSize,
    this.sha256,
    required this.sortOrder,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  }) : originAttachmentId = originAttachmentId ?? id;
}
