/// 校验错误代码枚举
enum FieldValidationErrorCode {
  /// 资料子类型模板不存在
  invalidTemplateType,

  /// 资料大类与子类型模板定义的 categoryKey 不匹配
  categoryMismatch,

  /// 高危认证特征信息（如密码、CVV）或定义为 forbidden 级别的字段被拦截
  forbiddenFieldSaved,

  /// 字段键不属于对应模板定义的字段集合（未知字段）
  unknownFieldKey,

  /// 模板声明的必填字段缺失或值为空
  requiredFieldMissing,

  /// 字段值类型格式校验不通过（包括强校验和弱校验失败）
  invalidFormat,

  /// 模板版本不匹配或版本不存在
  versionMismatch,

  /// 模板版本需要迁移
  migrationRequired,

  /// 字段已弃用
  deprecatedField,
}

/// 字段级结构化校验错误/警告
class FieldValidationError {
  /// 发生错误的字段 Key（若属于全局错误，如模板本身，则此项可为空）
  final String? fieldKey;

  /// 具体的错误代码枚举
  final FieldValidationErrorCode errorCode;

  /// 友好的中文错误展示消息
  final String errorMessage;

  /// 是否为警告属性（若为 true，则代表是非阻塞的，保存时不会被硬性阻断）
  final bool isWarning;

  FieldValidationError({
    this.fieldKey,
    required this.errorCode,
    required this.errorMessage,
    this.isWarning = false,
  });

  @override
  String toString() =>
      'FieldValidationError(fieldKey: $fieldKey, errorCode: $errorCode, isWarning: $isWarning, message: $errorMessage)';
}

/// 统一 Schema 相关校验错误类
class SchemaValidationError extends FieldValidationError {
  SchemaValidationError({
    super.fieldKey,
    required super.errorCode,
    required super.errorMessage,
    super.isWarning = false,
  });

  @override
  String toString() =>
      'SchemaValidationError(fieldKey: $fieldKey, errorCode: $errorCode, isWarning: $isWarning, message: $errorMessage)';
}

/// 聚合的校验报告结果
class ValidationResult {
  /// 严重错误集合（不阻断保存，仅用于诊断）
  final List<FieldValidationError> errors;

  /// 警告提示集合（仅提醒，不阻断保存）
  final List<FieldValidationError> warnings;

  /// 是否需要迁移标记
  final bool migrationRequired;

  /// 数据是否成功写入持久层 (非阻断模式下逻辑上始终为 true)
  final bool persisted;

  const ValidationResult({
    required this.errors,
    required this.warnings,
    this.migrationRequired = false,
    this.persisted = true,
  });

  /// 是否通过校验（逻辑校验状态，仅用于开发调试，非阻断）
  bool get isValid => !hasBlockingErrors;

  /// 任务是否成功（关联至 persisted）
  bool get success => persisted;

  /// 是否存在逻辑阻断错误（用于诊断）
  bool get hasBlockingErrors => errors.isNotEmpty;

  @override
  String toString() =>
      'ValidationResult(isValid: $isValid, success: $success, persisted: $persisted, hasBlockingErrors: $hasBlockingErrors, errorsCount: ${errors.length}, warningsCount: ${warnings.length}, migrationRequired: $migrationRequired)';
}

/// 结构化校验警告模型
class Warning {
  final String? fieldKey;
  final String errorCode;
  final String errorMessage;

  Warning({this.fieldKey, required this.errorCode, required this.errorMessage});

  Map<String, dynamic> toJson() => {
    'fieldKey': fieldKey,
    'errorCode': errorCode,
    'errorMessage': errorMessage,
  };

  factory Warning.fromJson(Map<String, dynamic> json) => Warning(
    fieldKey: json['fieldKey'] as String?,
    errorCode: json['errorCode'] as String,
    errorMessage: json['errorMessage'] as String,
  );

  @override
  String toString() =>
      'Warning(fieldKey: $fieldKey, errorCode: $errorCode, message: $errorMessage)';
}
