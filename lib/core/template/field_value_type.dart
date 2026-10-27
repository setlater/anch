/// 字段属性的值类型
enum FieldValueType {
  /// 普通文本
  text,

  /// 敏感文本（如户主名，身份证姓名等，明文保存但默认脱敏展示）
  sensitiveText,

  /// 整型数字
  number,

  /// 日期（YYYY-MM-DD）
  date,

  /// 月日（MM-DD）
  monthDay,

  /// 每月第几日
  dayOfMonth,

  /// 小数
  decimal,

  /// 布尔
  boolean,

  /// 枚举 Key
  enumeration,

  /// 手机号
  phone,

  /// 证件号
  idNumber,

  /// 银行卡号
  bankCardNumber,

  /// 扩展 JSON
  json;

  /// 将枚举转为物理数据库或模板配置所使用的稳定字符串 Key
  String toKey() {
    switch (this) {
      case FieldValueType.text:
        return 'text';
      case FieldValueType.sensitiveText:
        return 'sensitive_text';
      case FieldValueType.number:
        return 'number';
      case FieldValueType.date:
        return 'date';
      case FieldValueType.monthDay:
        return 'month_day';
      case FieldValueType.dayOfMonth:
        return 'day_of_month';
      case FieldValueType.decimal:
        return 'decimal';
      case FieldValueType.boolean:
        return 'bool';
      case FieldValueType.enumeration:
        return 'enum';
      case FieldValueType.phone:
        return 'phone';
      case FieldValueType.idNumber:
        return 'id_number';
      case FieldValueType.bankCardNumber:
        return 'bank_card_number';
      case FieldValueType.json:
        return 'json';
    }
  }

  /// 从字符串 Key 反向解析为枚举
  static FieldValueType fromKey(String key) {
    switch (key) {
      case 'text':
        return FieldValueType.text;
      case 'sensitive_text':
        return FieldValueType.sensitiveText;
      case 'number':
        return FieldValueType.number;
      case 'date':
        return FieldValueType.date;
      case 'month_day':
        return FieldValueType.monthDay;
      case 'day_of_month':
        return FieldValueType.dayOfMonth;
      case 'decimal':
        return FieldValueType.decimal;
      case 'bool':
        return FieldValueType.boolean;
      case 'enum':
        return FieldValueType.enumeration;
      case 'phone':
        return FieldValueType.phone;
      case 'id_number':
        return FieldValueType.idNumber;
      case 'bank_card_number':
        return FieldValueType.bankCardNumber;
      case 'json':
        return FieldValueType.json;
      default:
        return FieldValueType.text;
    }
  }
}
