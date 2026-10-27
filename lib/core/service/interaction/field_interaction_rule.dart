/// 模板字段联动规则抽象基类
abstract class FieldInteractionRule {
  /// 判断当前规则是否适用于指定模板类型和改变字段
  bool canApply(String typeKey, String fieldKey);

  /// 执行联动计算，返回建议联动更新的字段 Key 和新值 Map
  Map<String, String> apply(
    String changedValue,
    Map<String, String> currentFormValues,
  );
}

/// 身份证信息联动自动推导规则
class IdCardFieldsRule implements FieldInteractionRule {
  @override
  bool canApply(String typeKey, String fieldKey) {
    return typeKey == 'id_card' && fieldKey == 'id_number';
  }

  @override
  Map<String, String> apply(
    String changedValue,
    Map<String, String> currentFormValues,
  ) {
    final results = <String, String>{};
    final cleaned = changedValue.trim();

    // 中国居民身份证号推导规则：当前只针对合规的 18 位身份证执行
    if (cleaned.length != 18) {
      return results;
    }

    // 基本号规检查：前 17 位纯数字，最后一位数字或 X/x
    final idReg = RegExp(r'^\d{17}[\dXx]$');
    if (!idReg.hasMatch(cleaned)) {
      return results;
    }

    // 1. 自动推导出年、月、日（第 7 到 14 位，即 6 到 14 索引区间）
    final birthStr = cleaned.substring(6, 14); // 比如 19900307
    final year = birthStr.substring(0, 4);
    final month = birthStr.substring(4, 6);
    final day = birthStr.substring(6, 8);

    // 使用 DateTime.tryParse 进行 round-trip 双向比对，排查 1990-02-30 等非法日期
    final dateString = '$year-$month-$day';
    final parsedDate = DateTime.tryParse(dateString);
    if (parsedDate != null) {
      final y = int.tryParse(year);
      final m = int.tryParse(month);
      final d = int.tryParse(day);
      if (parsedDate.year == y &&
          parsedDate.month == m &&
          parsedDate.day == d) {
        results['birth_date'] = dateString;
      }
    }

    // 2. 自动推导性别（第 17 位奇数为男，偶数为女）
    final genderChar = cleaned.substring(16, 17);
    final genderNum = int.tryParse(genderChar);
    if (genderNum != null) {
      // 根据当前模板定义写入匹配的文本值，不进行复杂的 enum 选项扩展
      results['gender'] = (genderNum % 2 == 1) ? '男' : '女';
    }

    return results;
  }
}

/// 字段交互计算引擎（纯 Dart 逻辑，解耦所有 Flutter 视图及控制器）
class FieldInteractionEngine {
  final List<FieldInteractionRule> _rules;

  FieldInteractionEngine(this._rules);

  /// 默认内置规则引擎实例
  factory FieldInteractionEngine.defaultEngine() {
    return FieldInteractionEngine([IdCardFieldsRule()]);
  }

  /// 过滤并触发匹配的联动计算，返回建议更新的值 Map
  Map<String, String> evaluate({
    required String typeKey,
    required String fieldKey,
    required String value,
    required Map<String, String> currentFormValues,
  }) {
    final updates = <String, String>{};
    for (final rule in _rules) {
      if (rule.canApply(typeKey, fieldKey)) {
        updates.addAll(rule.apply(value, currentFormValues));
      }
    }
    return updates;
  }
}
