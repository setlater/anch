import 'dart:convert';

import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/template/field_value_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_bootstrap.dart';

void main() {
  late TestRepositoryContext context;

  setUp(() => context = createTestRepositoryContext());

  Future<String> saveCard(String number, {String? id}) {
    return context.itemRepository.saveItemWithFields(
      SaveItemInput(
        id: id,
        memberId: systemFamilyMemberId,
        categoryKey: 'bank_card',
        typeKey: 'debit_card',
        title: 'TEST 招商银行',
        searchText: '招商银行',
        fields: [
          SaveItemFieldInput(
            fieldKey: 'card_number',
            valueType: FieldValueType.bankCardNumber,
            valueText: number,
          ),
        ],
      ),
    );
  }

  test('先查空尾号再新增、修改和恢复资料，结果始终反映当前数据', () async {
    final service = context.itemUseCaseService;
    expect(await service.searchItems('4321'), isEmpty);
    final id = await saveCard('6225880000004321');
    expect((await service.searchItems('4321')).map((item) => item.id), [id]);

    await saveCard('6225880000008765', id: id);
    expect(await service.searchItems('4321'), isEmpty);
    expect((await service.searchItems('8765')).map((item) => item.id), [id]);
    await context.itemRepository.archiveItem(id);
    expect(await service.searchItems('8765'), isEmpty);
    await context.itemRepository.unarchiveItem(id);
    expect((await service.searchItems('8765')).map((item) => item.id), [id]);
    await context.itemRepository.moveToTrash(id);
    expect(await service.searchItems('8765'), isEmpty);
    await context.itemRepository.restoreFromTrash(id);
    expect((await service.searchItems('8765')).map((item) => item.id), [id]);
  });

  test('文字与别名搜索保留超过 100 条的完整候选供页面筛选', () async {
    await context.itemRepository.saveItemsInBatch([
      for (var index = 0; index < 120; index++)
        SaveItemInput(
          id: 'search-$index',
          memberId: systemFamilyMemberId,
          typeKey: 'debit_card',
          title: 'TEST 招商银行 $index',
          searchText: '招商银行',
          fields: [],
        ),
    ]);
    expect(
      await context.itemUseCaseService.searchItems('TEST'),
      hasLength(120),
    );
    expect(await context.itemUseCaseService.searchItems('招行'), hasLength(120));
  });

  test('文字、尾号和别名搜索均只返回低敏摘要及状态字段', () async {
    final id = await context.itemRepository.saveItemWithFields(
      SaveItemInput(
        memberId: systemFamilyMemberId,
        typeKey: 'credit_card',
        title: 'TEST 招商银行',
        searchText: '招商银行',
        note: 'TEST private note',
        metadata: jsonEncode({
          'raw_state': {
            'fields': {'private_field': 'TEST private value'},
          },
        }),
        fields: [
          SaveItemFieldInput(
            fieldKey: 'card_number',
            valueType: FieldValueType.bankCardNumber,
            valueText: '6225880000004321',
          ),
          SaveItemFieldInput(
            fieldKey: 'valid_until',
            valueType: FieldValueType.date,
            valueText: '2030-01-01',
          ),
        ],
      ),
    );
    for (final query in ['TEST', '4321', '招行']) {
      final result = (await context.itemUseCaseService.searchItems(
        query,
      )).single;
      expect(result.id, id);
      expect(result.note == null && result.metadata == null, isTrue);
      expect(result.fieldValues.keys, ['valid_until']);
      expect(result.rawState?['fields'], {'valid_until': '2030-01-01'});
    }
  });
}
