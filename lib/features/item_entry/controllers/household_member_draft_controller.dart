import '../household_member_draft.dart';

/// 户内成员草稿的纯业务规则，不依赖页面或弹窗生命周期。
class HouseholdMemberDraftController {
  const HouseholdMemberDraftController();

  String? validate(
    List<HouseholdMemberDraft> members,
    HouseholdMemberDraft candidate, {
    int? editingIndex,
  }) {
    if (candidate.name.isEmpty && candidate.idNumber.isEmpty) {
      return '请填写成员姓名或身份证号';
    }

    final normalizedId = candidate.idNumber.trim().toUpperCase();
    if (normalizedId.length != 18) return null;
    for (var index = 0; index < members.length; index++) {
      if (index == editingIndex) continue;
      if (members[index].idNumber.trim().toUpperCase() == normalizedId) {
        return '该身份证号已存在';
      }
    }
    return null;
  }

  List<HouseholdMemberDraft> upsert(
    List<HouseholdMemberDraft> members,
    HouseholdMemberDraft member, {
    int? editingIndex,
  }) {
    final updated = List<HouseholdMemberDraft>.from(members);
    if (editingIndex == null) {
      updated.add(member.copyWith(sortOrder: updated.length));
    } else {
      updated[editingIndex] = member;
    }
    return updated;
  }

  List<HouseholdMemberDraft> remove(
    List<HouseholdMemberDraft> members,
    int index,
  ) {
    final updated = List<HouseholdMemberDraft>.from(members)..removeAt(index);
    return [
      for (var i = 0; i < updated.length; i++)
        updated[i].copyWith(sortOrder: i),
    ];
  }
}
