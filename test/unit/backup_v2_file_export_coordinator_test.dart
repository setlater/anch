@Tags(['security'])
library;

import 'dart:async';
import 'dart:io';

import 'package:anch/core/attachment/save_attachment_input.dart';
import 'package:anch/core/backup/backup_file_save_service.dart';
import 'package:anch/core/backup/backup_export_progress.dart';
import 'package:anch/core/backup/backup_export_service.dart';
import 'package:anch/core/backup/backup_payload.dart';
import 'package:anch/core/backup/backup_unavailable_attachment.dart';
import 'package:anch/core/backup/backup_v2_file_export_coordinator.dart';
import 'package:anch/core/backup/backup_v2_format.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('anch/backup_stream_v2');
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.fromOpener(NativeAppDatabaseOpener(inMemory: true));
  });

  tearDown(() async {
    await database.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('选择目标后先报告加密准备，实际写入后才报告确定进度', () async {
    final begin = Completer<Map<Object?, Object?>>();
    final finish = Completer<Map<Object?, Object?>>();
    var writtenBytes = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'beginStreamingBackupDocument':
              return begin.future;
            case 'writeStreamingBackupChunk':
              writtenBytes += (call.arguments['bytes'] as Uint8List).length;
              return <Object?, Object?>{'success': true};
            case 'finishStreamingBackupDocument':
              return finish.future;
            case 'abortStreamingBackupDocument':
              return null;
          }
          return null;
        });

    final coordinator = BackupV2FileExportCoordinator(
      exportService: BackupExportService(
        itemRepository: ItemRepository(database),
        memberRepository: MemberRepository(database),
        metadata: BackupExportMetadata(
          appVersion: 'test',
          schemaVersion: 1,
          appId: 'icu.codealive.anch',
          platform: 'test',
          locale: 'zh_CN',
        ),
      ),
    );
    final progress = <BackupExportProgress>[];
    final reachedFinalizing = Completer<void>();

    final export = coordinator.exportAndSave(
      backupPassword: 'temporary-test-password',
      iterations: 2,
      nowMillisForTest: 1,
      onProgress: (event) {
        progress.add(event);
        if (event.stage == BackupExportProgressStage.finalizing &&
            !reachedFinalizing.isCompleted) {
          reachedFinalizing.complete();
        }
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(progress, isEmpty);

    begin.complete(<Object?, Object?>{'success': true});
    await reachedFinalizing.future.timeout(const Duration(seconds: 2));
    expect(progress.first.stage, BackupExportProgressStage.preparing);
    expect(progress.first.fraction, 0);
    expect(
      progress.any(
        (event) =>
            event.stage == BackupExportProgressStage.writing &&
            event.fraction > 0,
      ),
      isTrue,
    );
    expect(progress.last.fraction, 0.99);
    expect(progress.every((event) => event.fraction <= 0.99), isTrue);

    finish.complete(<Object?, Object?>{
      'success': true,
      'savedAt': 1,
      'sizeBytes': writtenBytes,
    });
    await export;

    expect(progress.last.stage, BackupExportProgressStage.completed);
    expect(progress.last.fraction, 1);
  });

  test('附件来源预检失败时不打开系统保存位置', () async {
    var platformCallCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          platformCallCount++;
          return <Object?, Object?>{'success': true};
        });
    final attachment = _attachment(encryptedSize: 1);
    final coordinator = _fixtureCoordinator(
      database,
      BackupV2ExportPlan(
        manifestPayload: _payload([attachment]),
        attachmentSourcesById: const {},
      ),
    );

    await expectLater(
      coordinator.exportAndSave(
        backupPassword: 'temporary-test-password',
        iterations: 2,
        nowMillisForTest: 1,
      ),
      throwsA(
        isA<BackupFileSaveException>().having(
          (error) => error.type,
          'type',
          BackupFileSaveErrorType.sourceUnavailable,
        ),
      ),
    );

    expect(platformCallCount, 0);
  });

  test('真实附件缺失时，容量估算与导出均保留汇总明细且不打开保存位置', () async {
    final documents = await Directory.systemTemp.createTemp('anch-export-');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async {
          return call.method == 'getApplicationDocumentsDirectory'
              ? documents.path
              : null;
        });
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      await documents.delete();
    });
    var platformCallCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          platformCallCount++;
          return null;
        });
    final repository = ItemRepository(database);
    final itemId = await repository.saveItemWithFields(
      SaveItemInput(
        categoryKey: 'identity',
        typeKey: 'id_card',
        title: 'TEST-MISSING-FILES',
        fields: [],
        attachments: [
          for (var index = 0; index < 2; index++)
            SaveAttachmentInput(
              itemId: '',
              attachmentRole: 'other',
              fileName: 'missing-$index.enc',
              originalName: 'TEST-ATTACHMENT-$index.png',
              mimeType: 'image/png',
              plainSize: 1,
              encryptedSize: 41,
              sortOrder: index,
            ),
        ],
      ),
    );
    final coordinator = BackupV2FileExportCoordinator(
      exportService: BackupExportService(
        itemRepository: repository,
        memberRepository: MemberRepository(database),
        metadata: BackupExportMetadata(
          appVersion: 'test',
          schemaVersion: 1,
          appId: 'icu.codealive.anch',
          platform: 'test',
          locale: 'zh_CN',
        ),
      ),
    );
    final unavailable = isA<BackupFileSaveException>()
        .having(
          (error) => error.type,
          'type',
          BackupFileSaveErrorType.sourceUnavailable,
        )
        .having(
          (error) => error.unavailableAttachments,
          'unavailable attachments',
          hasLength(2),
        )
        .having(
          (error) => error.unavailableAttachments.map((entry) => entry.itemId),
          'item references',
          everyElement(itemId),
        )
        .having(
          (error) => error.unavailableAttachments.map((entry) => entry.reason),
          'reasons',
          everyElement(BackupUnavailableAttachmentReason.fileMissing),
        );
    await expectLater(coordinator.estimateOutput(), throwsA(unavailable));
    await expectLater(
      coordinator.exportAndSave(backupPassword: 'temporary-test-password'),
      throwsA(unavailable),
    );
    expect(platformCallCount, 0);
    expect(
      (await repository.getItemWithFields(itemId))!.attachments,
      hasLength(2),
    );
  });

  test('导出前可获取保守容量估算，且不打开系统保存位置', () async {
    var platformCallCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          platformCallCount++;
          return <Object?, Object?>{'success': true};
        });
    final coordinator = _fixtureCoordinator(
      database,
      BackupV2ExportPlan(
        manifestPayload: _payload(const []),
        attachmentSourcesById: const {},
      ),
    );

    final preflight = await coordinator.estimateOutput(nowMillisForTest: 1);

    expect(preflight.estimatedOutputBytes, greaterThan(0));
    expect(platformCallCount, 0);
  });

  test('首写失败时标记保存位置不可写、中止会话且不写最终提交帧', () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          switch (call.method) {
            case 'beginStreamingBackupDocument':
              return <Object?, Object?>{'success': true};
            case 'writeStreamingBackupChunk':
              throw PlatformException(
                code: 'writeFailed',
                message: 'virtual output failure',
              );
            case 'abortStreamingBackupDocument':
              return null;
            case 'finishStreamingBackupDocument':
              fail('写入失败后不得写入最终提交帧');
          }
          return null;
        });
    final coordinator = _fixtureCoordinator(
      database,
      BackupV2ExportPlan(
        manifestPayload: _payload(const []),
        attachmentSourcesById: const {},
      ),
    );

    await expectLater(
      coordinator.exportAndSave(
        backupPassword: 'temporary-test-password',
        iterations: 2,
        nowMillisForTest: 1,
      ),
      throwsA(
        isA<BackupFileSaveException>().having(
          (error) => error.type,
          'type',
          BackupFileSaveErrorType.targetWriteFailed,
        ),
      ),
    );

    expect(
      methods,
      containsAllInOrder([
        'beginStreamingBackupDocument',
        'writeStreamingBackupChunk',
        'abortStreamingBackupDocument',
      ]),
    );
    expect(methods, isNot(contains('finishStreamingBackupDocument')));
  });

  test('导出中的附件读取异常会一次性列出其余不可用附件', () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          switch (call.method) {
            case 'beginStreamingBackupDocument':
            case 'writeStreamingBackupChunk':
              return <Object?, Object?>{'success': true};
            case 'abortStreamingBackupDocument':
              return null;
            case 'finishStreamingBackupDocument':
              fail('附件读取失败后不得写入最终提交帧');
          }
          return null;
        });
    final firstUnreadable = _attachment(
      encryptedSize: 1,
      id: 'first-unreadable',
      originalName: 'first-virtual.bin',
    );
    final laterUnreadable = _attachment(
      encryptedSize: 1,
      id: 'later-unreadable',
      originalName: 'later-virtual.bin',
    );
    final readable = _attachment(
      encryptedSize: 1,
      id: 'readable',
      originalName: 'readable-virtual.bin',
    );
    final progress = <BackupExportProgress>[];
    final coordinator = _fixtureCoordinator(
      database,
      BackupV2ExportPlan(
        manifestPayload: _payload([firstUnreadable, laterUnreadable, readable]),
        attachmentSourcesById: {
          firstUnreadable.id: BackupV2AttachmentSource(
            attachment: firstUnreadable,
            openPayloadStream: () =>
                Stream<List<int>>.error(StateError('virtual read error')),
          ),
          laterUnreadable.id: BackupV2AttachmentSource(
            attachment: laterUnreadable,
            openPayloadStream: () =>
                Stream<List<int>>.error(StateError('virtual read error')),
          ),
          readable.id: BackupV2AttachmentSource(
            attachment: readable,
            openPayloadStream: () => Stream<List<int>>.value(const <int>[1]),
          ),
        },
      ),
    );

    await expectLater(
      coordinator.exportAndSave(
        backupPassword: 'temporary-test-password',
        iterations: 2,
        nowMillisForTest: 1,
        onProgress: progress.add,
      ),
      throwsA(
        isA<BackupFileSaveException>()
            .having(
              (error) => error.type,
              'type',
              BackupFileSaveErrorType.sourceUnavailable,
            )
            .having(
              (error) => error.unavailableAttachments
                  .map((attachment) => attachment.displayName)
                  .toList(),
              'unavailable attachments',
              ['first-virtual.bin', 'later-virtual.bin'],
            ),
      ),
    );

    expect(
      progress.map((event) => event.stage),
      contains(BackupExportProgressStage.checkingAttachments),
    );
    final attachmentAuditProgress = progress
        .where(
          (event) =>
              event.stage == BackupExportProgressStage.checkingAttachments,
        )
        .toList();
    expect(attachmentAuditProgress.first.completedAttachments, 1);
    expect(attachmentAuditProgress.first.totalAttachments, 3);
    expect(attachmentAuditProgress.last.completedAttachments, 3);
    expect(attachmentAuditProgress.last.totalAttachments, 3);
    expect(methods, contains('abortStreamingBackupDocument'));
    expect(methods, isNot(contains('finishStreamingBackupDocument')));
  });
}

BackupV2FileExportCoordinator _fixtureCoordinator(
  AppDatabase database,
  BackupV2ExportPlan plan,
) {
  return BackupV2FileExportCoordinator(
    exportService: _FixtureBackupExportService(
      plan: plan,
      itemRepository: ItemRepository(database),
      memberRepository: MemberRepository(database),
    ),
  );
}

class _FixtureBackupExportService extends BackupExportService {
  _FixtureBackupExportService({
    required this.plan,
    required super.itemRepository,
    required super.memberRepository,
  }) : super(
         metadata: BackupExportMetadata(
           appVersion: 'test',
           schemaVersion: 1,
           appId: 'icu.codealive.anch',
           platform: 'test',
           locale: 'zh_CN',
         ),
       );

  final BackupV2ExportPlan plan;

  @override
  Future<BackupV2ExportPlan> prepareStreamingV2Export({
    int? nowMillisForTest,
  }) async => plan;
}

BackupPayloadV1 _payload(List<BackupAttachmentV1> attachments) {
  return BackupPayloadV1(
    exportedAt: 1,
    appVersion: 'test',
    schemaVersion: 1,
    source: BackupSourceInfo(appId: 'test', platform: 'test'),
    data: BackupDataV1(
      members: const [],
      items: const [],
      itemFields: const [],
      appSettings: const [],
      attachments: attachments,
      childEntries: const [],
      childFields: const [],
      itemEvents: const [],
      itemEventChanges: const [],
    ),
  );
}

BackupAttachmentV1 _attachment({
  required int encryptedSize,
  String id = 'virtual-attachment',
  String originalName = 'virtual.bin',
}) {
  return BackupAttachmentV1(
    id: id,
    itemId: 'virtual-item',
    attachmentRole: 'other',
    fileName: '$id.enc',
    originalName: originalName,
    mimeType: 'application/octet-stream',
    plainSize: encryptedSize,
    encryptedSize: encryptedSize,
    sortOrder: 0,
    status: 'active',
    createdAt: 1,
    updatedAt: 1,
    encryptedData: '',
  );
}
