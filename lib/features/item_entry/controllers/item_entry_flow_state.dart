import 'package:meta/meta.dart';
import '../../../core/repository/models/member_model.dart';
import '../../../core/template/type_definition.dart';
import 'field_state.dart';

/// 单一录入顺序，同时用于步骤指示器。
enum ItemEntryStep { type, owner, editableReview, supplement }

@immutable
class ItemEntryFlowState {
  final ItemEntryStep currentStep;
  final TypeDefinition? selectedType;
  final int? selectedTemplateVersion;
  final MemberModel? selectedOwner;
  final Map<String, FieldState> fieldValues;
  final int genericCustomFieldCount;

  const ItemEntryFlowState({
    required this.currentStep,
    this.selectedType,
    this.selectedTemplateVersion,
    this.selectedOwner,
    this.fieldValues = const {},
    this.genericCustomFieldCount = 1,
  });

  ItemEntryFlowState copyWith({
    ItemEntryStep? currentStep,
    TypeDefinition? selectedType,
    int? selectedTemplateVersion,
    MemberModel? selectedOwner,
    Map<String, FieldState>? fieldValues,
    int? genericCustomFieldCount,
  }) {
    return ItemEntryFlowState(
      currentStep: currentStep ?? this.currentStep,
      selectedType: selectedType ?? this.selectedType,
      selectedTemplateVersion:
          selectedTemplateVersion ?? this.selectedTemplateVersion,
      selectedOwner: selectedOwner ?? this.selectedOwner,
      fieldValues: fieldValues ?? this.fieldValues,
      genericCustomFieldCount:
          genericCustomFieldCount ?? this.genericCustomFieldCount,
    );
  }
}
