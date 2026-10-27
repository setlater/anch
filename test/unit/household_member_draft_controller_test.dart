import 'package:anch/features/item_entry/controllers/household_member_draft_controller.dart';
import 'package:anch/features/item_entry/household_member_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const controller = HouseholdMemberDraftController();

  HouseholdMemberDraft member({
    String name = '张三',
    String idNumber = '',
    int sortOrder = 0,
  }) => HouseholdMemberDraft(
    name: name,
    relation: '子女',
    idNumber: idNumber,
    formerName: '',
    ethnicity: '',
    nativePlace: '',
    birthPlace: '',
    sortOrder: sortOrder,
  );

  test('成员草稿要求姓名或身份证号，且拒绝重复的完整身份证号', () {
    expect(controller.validate(const [], member(name: '')), '请填写成员姓名或身份证号');
    const idNumber = '110101199003072345';
    final members = [member(idNumber: idNumber)];
    expect(
      controller.validate(members, member(name: '李四', idNumber: idNumber)),
      '该身份证号已存在',
    );
    expect(
      controller.validate(members, member(idNumber: idNumber), editingIndex: 0),
      isNull,
    );
  });

  test('新增和删除成员保持连续排序', () {
    final first = controller.upsert(const [], member());
    final second = controller.upsert(first, member(name: '李四'));
    expect(second.map((item) => item.sortOrder), [0, 1]);

    final remaining = controller.remove(second, 0);
    expect(remaining.single.name, '李四');
    expect(remaining.single.sortOrder, 0);
  });
}
