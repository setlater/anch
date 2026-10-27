import '../validation/field_validation_error.dart';

/// 资料保存业务结果模型（Result 风格）
class ItemSaveResult {
  /// 数据是否成功写入持久层 (非阻断模式下逻辑上始终为 true)
  final bool persisted;

  /// 是否保存成功 (关联至 persisted)
  bool get success => persisted;

  /// 保存成功后返回的资料 UUID
  final String? itemId;

  /// 校验失败时的结构化错误列表
  final List<FieldValidationError> errors;

  ItemSaveResult({
    required this.persisted,
    this.itemId,
    this.errors = const [],
  });

  /// 快速构造成功结果
  factory ItemSaveResult.success(
    String itemId, [
    List<FieldValidationError> errors = const [],
  ]) {
    return ItemSaveResult(persisted: true, itemId: itemId, errors: errors);
  }

  /// 快速构造失败结果
  factory ItemSaveResult.failure(List<FieldValidationError> errors) {
    return ItemSaveResult(persisted: false, errors: errors);
  }
}
