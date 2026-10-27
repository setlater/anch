import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_bootstrap.dart';

void main() {
  test('活跃资料按成员和类型在查询中收窄，保留置顶顺序并排除归档与删除', () async {
    final context = createTestRepositoryContext();
    SaveItemInput row(
      String id,
      String member,
      String type, {
      bool pinned = false,
      String status = 'active',
    }) => SaveItemInput(
      id: id,
      memberId: member,
      typeKey: type,
      title: 'TEST $id',
      status: status,
      deletedAt: status == 'deleted' ? 1 : null,
      statusBeforeDeletion: status == 'deleted' ? 'active' : null,
      isPinned: pinned,
      fields: [],
    );
    await context.itemRepository.saveItemsInBatch([
      row('family-id', systemFamilyMemberId, 'id_card'),
      row('family-pinned', systemFamilyMemberId, 'passport', pinned: true),
      row('self-id', systemMeMemberId, 'id_card'),
      row('archived-id', systemFamilyMemberId, 'id_card', status: 'archived'),
      row('deleted-id', systemFamilyMemberId, 'id_card', status: 'deleted'),
    ]);

    final repository = context.itemRepository;
    final family = await repository.getActiveItems(
      memberId: systemFamilyMemberId,
    );
    expect(family.map((item) => item.id), ['family-pinned', 'family-id']);
    final ids = await repository.getActiveItems(typeKey: 'id_card');
    expect(
      ids.map((item) => item.id),
      unorderedEquals(['family-id', 'self-id']),
    );
    expect(
      (await repository.getActiveItems(
        memberId: systemMeMemberId,
        typeKey: 'id_card',
      )).single.id,
      'self-id',
    );
    expect(await repository.getActiveItems(memberId: 'missing'), isEmpty);
    expect(await repository.getActiveItems(typeKey: 'missing'), isEmpty);
    expect(await repository.getActiveItems(), hasLength(3));
    expect(await repository.getActiveItemCount(), 3);
  });

  test('空资料库统计为零', () async {
    final context = createTestRepositoryContext();
    expect(await context.itemRepository.getActiveItemCount(), 0);
  });
}
