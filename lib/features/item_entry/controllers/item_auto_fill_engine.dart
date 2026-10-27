import '../../../core/repository/models/member_model.dart';
import '../../../core/template/field_definition.dart';
import '../../../core/template/field_value_type.dart';
import '../../../core/time/time_domain_source.dart';
import '../../../core/template/type_definition.dart';

/// ItemAutoFillEngine computes deterministic mock and default values
/// for fields based on selected types and selected owners.
class ItemAutoFillEngine {
  final TimeDomainSource timeDomainSource;

  const ItemAutoFillEngine({required this.timeDomainSource});

  Map<String, String> generateAutoFillValues({
    required TypeDefinition type,
    required MemberModel owner,
  }) {
    final result = <String, String>{};
    final now = timeDomainSource.now();

    for (final field in type.fields) {
      final value = _getAutoFillValueForField(field, owner, now);
      if (value != null) {
        result[field.fieldKey] = value;
      }
    }
    return result;
  }

  String? _getAutoFillValueForField(
    FieldDefinition field,
    MemberModel owner,
    DateTime now,
  ) {
    switch (field.valueType) {
      case FieldValueType.date:
        return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      case FieldValueType.monthDay:
        return '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      case FieldValueType.dayOfMonth:
        return now.day.toString();
      case FieldValueType.boolean:
        return 'false';
      case FieldValueType.phone:
        return '13800000000';
      case FieldValueType.idNumber:
        return '110101199003072345';
      case FieldValueType.bankCardNumber:
        return '622202000000000000';
      case FieldValueType.number:
        return '123456';
      case FieldValueType.decimal:
        return '100.00';
      case FieldValueType.enumeration:
        return field.label;
      case FieldValueType.sensitiveText:
      case FieldValueType.text:
      default:
        if (field.fieldKey.contains('name') ||
            field.fieldKey.contains('owner')) {
          return owner.name;
        }
        return field.label;
    }
  }
}
