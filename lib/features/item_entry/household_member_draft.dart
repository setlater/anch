import '../../core/repository/models/item_child_entry_model.dart';

class HouseholdMemberDraft {
  final String? id;
  final String name;
  final String relation;
  final String idNumber;
  final String formerName;
  final String ethnicity;
  final String nativePlace;
  final String birthPlace;
  final int sortOrder;

  HouseholdMemberDraft({
    this.id,
    required this.name,
    required this.relation,
    required this.idNumber,
    required this.formerName,
    required this.ethnicity,
    required this.nativePlace,
    required this.birthPlace,
    required this.sortOrder,
  });

  HouseholdMemberDraft copyWith({
    String? id,
    String? name,
    String? relation,
    String? idNumber,
    String? formerName,
    String? ethnicity,
    String? nativePlace,
    String? birthPlace,
    int? sortOrder,
  }) {
    return HouseholdMemberDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      idNumber: idNumber ?? this.idNumber,
      formerName: formerName ?? this.formerName,
      ethnicity: ethnicity ?? this.ethnicity,
      nativePlace: nativePlace ?? this.nativePlace,
      birthPlace: birthPlace ?? this.birthPlace,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  SaveItemChildEntryInput toSaveInput() {
    return SaveItemChildEntryInput(
      id: id,
      childType: 'household_member',
      sortOrder: sortOrder,
      fields: [
        SaveItemChildFieldInput(
          fieldKey: 'member_name',
          label: '成员姓名',
          valueText: name,
          valueType: 'text',
          sensitiveLevel: 'medium',
          searchable: true,
        ),
        SaveItemChildFieldInput(
          fieldKey: 'relation_to_head',
          label: '与户主关系',
          valueText: relation,
          valueType: 'text',
          sensitiveLevel: 'none',
        ),
        SaveItemChildFieldInput(
          fieldKey: 'member_id_number',
          label: '身份证号',
          valueText: idNumber,
          valueType: 'sensitiveText',
          sensitiveLevel: 'high',
          copyable: true,
        ),
        SaveItemChildFieldInput(
          fieldKey: 'former_name',
          label: '曾用名',
          valueText: formerName,
          valueType: 'text',
          sensitiveLevel: 'medium',
        ),
        SaveItemChildFieldInput(
          fieldKey: 'ethnicity',
          label: '民族',
          valueText: ethnicity,
          valueType: 'text',
          sensitiveLevel: 'none',
        ),
        SaveItemChildFieldInput(
          fieldKey: 'native_place',
          label: '籍贯',
          valueText: nativePlace,
          valueType: 'text',
          sensitiveLevel: 'medium',
        ),
        SaveItemChildFieldInput(
          fieldKey: 'birth_place',
          label: '出生地',
          valueText: birthPlace,
          valueType: 'text',
          sensitiveLevel: 'medium',
        ),
      ],
    );
  }

  factory HouseholdMemberDraft.fromModel(ItemChildEntryModel model) {
    String getVal(String key) {
      return model.fields
              .firstWhere(
                (f) => f.fieldKey == key,
                orElse: () => ItemChildFieldModel(
                  id: '',
                  childEntryId: '',
                  fieldKey: '',
                  label: '',
                  valueText: '',
                  valueType: '',
                  sensitiveLevel: '',
                  copyable: false,
                  searchable: false,
                  summary: false,
                  sortOrder: 0,
                  createdAt: 0,
                  updatedAt: 0,
                ),
              )
              .valueText ??
          '';
    }

    return HouseholdMemberDraft(
      id: model.id,
      name: getVal('member_name'),
      relation: getVal('relation_to_head'),
      idNumber: getVal('member_id_number'),
      formerName: getVal('former_name'),
      ethnicity: getVal('ethnicity'),
      nativePlace: getVal('native_place'),
      birthPlace: getVal('birth_place'),
      sortOrder: model.sortOrder,
    );
  }
}
