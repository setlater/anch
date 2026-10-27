import '../../template/template_registry.dart';
import '../../template/field_value_type.dart';
import '../models/item_draft_input.dart';
import 'field_validation_error.dart';
import 'field_contract_validator.dart';
import '../../security/field_render_policy.dart';

/// 资料模板字段安全与格式校验器
class TemplateValidator {
  /// 校验资料草稿输入，返回校验报告结果
  static ValidationResult validate(ItemDraftInput draft) {
    // 1. 调用底层的轻量字段结构契约校验器进行结构检验
    final contractResult = FieldContractValidator.validate(draft);

    final errors = List<FieldValidationError>.from(contractResult.errors);
    final warnings = List<FieldValidationError>.from(contractResult.warnings);

    if (draft.typeKey == null || draft.typeKey!.isEmpty) {
      return ValidationResult(
        errors: errors,
        warnings: warnings,
        migrationRequired: contractResult.migrationRequired,
      );
    }

    // 获取当前适配的模板定义
    final typeDef = TemplateRegistry.getTemplate(
      draft.typeKey!,
      draft.templateVersion,
    );

    if (typeDef == null) {
      return ValidationResult(
        errors: errors,
        warnings: warnings,
        migrationRequired: contractResult.migrationRequired,
      );
    }

    final templateFieldsMap = {for (final f in typeDef.fields) f.fieldKey: f};

    // 2. 校验传入字段的业务层/安全层策略控制规则
    for (final inputField in draft.fields) {
      final fieldKey = inputField.fieldKey;

      // (a) 优先规则：高危敏感特征词拦截
      if (isForbiddenKey(fieldKey)) {
        errors.add(
          FieldValidationError(
            fieldKey: fieldKey,
            errorCode: FieldValidationErrorCode.forbiddenFieldSaved,
            errorMessage: '字段 [$fieldKey] 包含高危敏感特征词，系统绝不录入和保存此项高危凭证信息！',
          ),
        );
        continue; // 被敏感词拦截后，跳过后续级别校验
      }

      final fieldDef = templateFieldsMap[fieldKey];
      if (fieldDef == null) {
        // 如果是已被废弃的字段（且不在当前模板字段中），在上游契约阶段已被处理，这里直接跳过
        continue;
      }

      // (b) 校验是否在模板层被标记为 forbidden 级别
      if (!FieldRenderPolicy.shouldRenderField(fieldDef.sensitiveLevel)) {
        errors.add(
          FieldValidationError(
            fieldKey: fieldKey,
            errorCode: FieldValidationErrorCode.forbiddenFieldSaved,
            errorMessage:
                '字段 [$fieldKey] 的敏感度级别为 forbidden，属于系统绝不保留的高危凭证信息，拒绝保存。',
          ),
        );
        continue;
      }
    }

    return ValidationResult(
      errors: errors,
      warnings: warnings,
      migrationRequired: contractResult.migrationRequired,
    );
  }

  /// 检查是否为 forbidden 的敏感 key 特征（敏感特征词防呆拦截，排除 reserved_phone 例外）
  static bool isForbiddenKey(String fieldKey) {
    if (fieldKey == 'reserved_phone') {
      return false;
    }
    final lowerKey = fieldKey.toLowerCase();
    return lowerKey.contains('cvv') ||
        lowerKey.contains('cvc') ||
        lowerKey.contains('password') ||
        lowerKey.contains('login_key') ||
        lowerKey.contains('pay_pass') ||
        lowerKey.contains('auth_token') ||
        lowerKey.contains('verify_code') ||
        lowerKey.contains('dynamic_code') ||
        lowerKey.contains('otp') ||
        lowerKey.contains('pin') ||
        lowerKey.contains('security_code');
  }

  /// 「其他资料」自定义字段名也不得伪装保存高危凭证。
  static bool isForbiddenCustomFieldLabel(String label) {
    final lowerLabel = label.trim().toLowerCase();
    return lowerLabel.contains('密码') ||
        lowerLabel.contains('验证码') ||
        lowerLabel.contains('校验码') ||
        lowerLabel.contains('私钥') ||
        lowerLabel.contains('助记词') ||
        lowerLabel.contains('cvv') ||
        lowerLabel.contains('cvc') ||
        lowerLabel.contains('password') ||
        lowerLabel.contains('verify code') ||
        lowerLabel.contains('security code') ||
        lowerLabel.contains('otp') ||
        lowerLabel.contains('pin');
  }

  /// 实现强弱格式校验
  static String? validateValueType(FieldValueType type, String value) {
    switch (type) {
      // ==================== 强校验类型 (要求格式绝对精确，影响后续系统内部逻辑) ====================
      case FieldValueType.date:
        final dateReg = RegExp(r'^\d{4}-\d{2}-\d{2}$');
        if (!dateReg.hasMatch(value)) {
          return '必须符合 YYYY-MM-DD 格式 (例如 2026-06-10)。';
        }
        if (DateTime.tryParse(value) == null) {
          return '输入的日期数值非法。';
        }
        return null;

      case FieldValueType.number:
        if (int.tryParse(value) == null) {
          return '必须是合法的整数。';
        }
        return null;

      case FieldValueType.decimal:
        if (double.tryParse(value) == null) {
          return '必须是合法的数字或小数。';
        }
        return null;

      case FieldValueType.dayOfMonth:
        final intVal = int.tryParse(value);
        if (intVal == null || intVal < 1 || intVal > 31) {
          return '必须是 1 到 31 之间的整数。';
        }
        return null;

      case FieldValueType.boolean:
        final valLower = value.toLowerCase();
        if (valLower != 'true' && valLower != 'false') {
          return '必须为 "true" 或 "false"。';
        }
        return null;

      // ==================== 弱校验类型 (宽松匹配，仅阻断明显输入的乱码，不阻断特殊格式资料录入) ====================
      case FieldValueType.phone:
        // 允许包含数字、空格、加号、减号、左右括号，长度在 5-20 位之间以容纳座机与国际号
        final phoneReg = RegExp(r'^[0-9\s+\-()]{5,20}$');
        if (!phoneReg.hasMatch(value)) {
          return '格式不符合电话号码基本规范。';
        }
        return null;

      case FieldValueType.idNumber:
        // 仅检验符合中国身份证 15 位或 18 位数字的基本结构，末尾可为 X/x
        final idReg = RegExp(r'^(^\d{15}$)|(^\d{18}$)|(^\d{17}(\d|X|x)$)$');
        if (!idReg.hasMatch(value)) {
          return '必须符合 15 位或 18 位证件号码的基本规则。';
        }
        return null;

      case FieldValueType.bankCardNumber:
        // 仅校验 12 到 19 位纯数字，不对卡 bin 做精确认证
        final cardReg = RegExp(r'^\d{12,19}$');
        if (!cardReg.hasMatch(value)) {
          return '必须为 12 到 19 位的银行卡卡号。';
        }
        return null;

      default:
        // 其它文本类 (如 text, sensitiveText, enumeration 等) 不作强力限制
        return null;
    }
  }
}
