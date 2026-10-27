@Tags(['security'])
library;

import 'dart:convert';

import 'package:anch/core/repository/models/item_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('摘要白名单排除完整字段和原始快照，保留正式状态字段优先级', () {
    final summary = ItemModel(
      id: 'TEST',
      templateVersion: 1,
      title: 'TEST summary',
      note: 'TEST private note',
      metadata: jsonEncode({
        'raw_state': {
          'fields': {
            'private_field': 'TEST private field',
            'valid_until': '2028-01-01',
            'is_long_term': true,
          },
        },
      }),
      fieldValues: const {
        'valid_until': '2030-01-01',
        'private_field': 'TEST private field',
      },
      isFavorite: false,
      isPinned: true,
      sortOrder: 0,
      status: 'active',
      createdAt: 1,
      updatedAt: 1,
    ).toListSummary();
    expect(summary.title, 'TEST summary');
    expect(summary.isPinned, isTrue);
    expect(summary.note == null && summary.metadata == null, isTrue);
    expect(summary.fieldValues, {
      'valid_until': '2030-01-01',
      'is_long_term': 'true',
    });
    expect(
      () => summary.fieldValues['private_field'] = '',
      throwsUnsupportedError,
    );
  });
  test('保险摘要只保留低敏险种与日期，排除中敏保障对象且重复提取不丢值', () {
    final source = ItemModel(
      id: 'mock-insurance',
      typeKey: 'insurance',
      templateVersion: 1,
      title: 'MOCK policy',
      primaryText: 'MOCK retired beneficiary',
      summaryText: 'MOCK retired status',
      secondaryText: 'MOCK retired agent',
      metadata: jsonEncode({
        'raw_state': {
          'fields': {
            'insurance_type': 'MOCK old type',
            'insured_person': 'MOCK old person',
            'end_date': '2027-01-01',
            'beneficiary': 'MOCK retired beneficiary',
          },
        },
      }),
      fieldValues: {
        'insurance_type': 'MOCK formal type',
        'insured_person': 'MOCK formal person',
      },
      isFavorite: false,
      isPinned: false,
      sortOrder: 0,
      status: 'active',
      createdAt: 0,
      updatedAt: 0,
    );
    final summary = source.toListSummary();
    expect(summary.summaryText, 'MOCK formal type · 2027-01-01');
    expect(summary.toListSummary().summaryText, summary.summaryText);
    expect(summary.secondaryText, isNull);
    expect(summary.metadata, isNull);
    expect(summary.fieldValues.keys, isNot(contains('beneficiary')));
    expect(summary.fieldValues.keys, isNot(contains('insured_person')));
    expect(summary.summaryText, isNot(contains('MOCK formal person')));
    expect(summary.primaryText, isNot(contains('retired')));
  });
}
