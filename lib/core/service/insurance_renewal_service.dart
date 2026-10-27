import '../repository/models/item_with_fields.dart';
import 'models/item_draft_input.dart';

abstract final class InsuranceRenewalService {
  static const copiedFieldKeys = {
    'insurance_company',
    'policy_name',
    'insurance_type',
    'applicant',
    'insured_person',
    'service_phone',
  };

  static ItemDraftInput createDraft(ItemWithFields source) {
    if (source.typeKey != 'insurance') {
      throw ArgumentError('续保来源必须是保险资料');
    }
    return ItemDraftInput(
      memberId: source.memberId,
      categoryKey: 'insurance',
      typeKey: 'insurance',
      templateVersion: source.templateVersion,
      fields: source.fields
          .where((field) => copiedFieldKeys.contains(field.fieldKey))
          .map(
            (field) => ItemFieldDraftInput(
              fieldKey: field.fieldKey,
              valueText: field.valueText,
            ),
          )
          .toList(growable: false),
    );
  }
}
