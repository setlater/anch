@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:anch/core/backup/backup_import_service.dart';
import 'package:anch/core/backup/attachment_restore_recovery_service.dart';
import 'package:anch/core/backup/backup_payload.dart';
import 'package:anch/core/backup/backup_v2_attachment_directory_staging.dart';
import 'package:anch/core/backup/backup_v2_format.dart';
import 'package:anch/core/backup/backup_v2_restore_coordinator.dart';
import 'package:anch/core/attachment/attachment_crypto_service.dart';
import 'package:anch/core/backup/backup_file_restore_decrypt_preview_coordinator.dart';
import 'package:anch/core/backup/backup_file_restore_apply_coordinator.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const streamChannel = MethodChannel('anch/backup_stream_v2');
  late AppDatabase database;
  late Directory documentsDirectory;

  setUp(() async {
    AttachmentCryptoService.init(base64UrlEncode(List<int>.filled(32, 41)));
    database = AppDatabase.fromOpener(NativeAppDatabaseOpener(inMemory: true));
    documentsDirectory = await Directory.systemTemp.createTemp(
      'anch-v2-fictional-',
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(streamChannel, null);
    await database.close();
    if (await documentsDirectory.exists()) {
      await documentsDirectory.delete(recursive: true);
    }
  });

  test('V2 经逐帧认证 staging 后覆盖恢复附件，不需要 Base64 回读', () async {
    final plaintext = Uint8List.fromList(
      List<int>.generate(
        BackupV2Format.framePlaintextLimit + 19,
        (i) => i % 239,
      ),
    );
    final payload = _payload(
      plaintext.length + 28,
      plainSize: plaintext.length,
    );
    final sink = _MemorySink();
    final password = _ephemeralPassword();
    await BackupV2Format.encodeToSink(
      plan: _portablePlan(payload, plaintext),
      backupPassword: password,
      sink: sink,
      iterations: 2,
    );

    final decoded = await BackupV2Format.decodeAndStage(
      source: _MemorySource(sink.bytes),
      backupPassword: password,
      stagingFactory: (manifest, attachmentEncoding) =>
          BackupV2AttachmentDirectoryStaging.create(
            manifest,
            attachmentEncoding: attachmentEncoding,
            documentsDirectoryProvider: () async => documentsDirectory,
          ),
    );
    final importService = BackupImportService(
      database: database,
      documentsDirectoryProvider: () async => documentsDirectory,
    );

    final result = await importService.restoreFromV2PreparedPayload(
      payload: decoded.payload,
      attachmentStaging: decoded.staging as BackupV2AttachmentDirectoryStaging,
    );

    expect(result.restoredItemsCount, 1);
    expect(result.restoredMembersCount, 1);
    final attachments = await database.select(database.attachments).get();
    expect(attachments, hasLength(1));
    final restored = File(
      p.join(documentsDirectory.path, 'attachments', 'fictional.enc'),
    );
    expect(
      await AttachmentCryptoService.decryptData(await restored.readAsBytes()),
      plaintext,
    );
  });

  test('同一份 V2 备份重复覆盖恢复时保留完整密文附件', () async {
    final plaintext = Uint8List.fromList(
      List<int>.generate(
        BackupV2Format.framePlaintextLimit + 19,
        (i) => i % 239,
      ),
    );
    final payload = _payload(
      plaintext.length + 28,
      plainSize: plaintext.length,
    );
    final sink = _MemorySink();
    final password = _ephemeralPassword();
    await BackupV2Format.encodeToSink(
      plan: _portablePlan(payload, plaintext),
      backupPassword: password,
      sink: sink,
      iterations: 2,
    );
    final backupBytes = sink.bytes;
    final importService = BackupImportService(
      database: database,
      documentsDirectoryProvider: () async => documentsDirectory,
    );

    Future<void> restoreOnce() async {
      final decoded = await BackupV2Format.decodeAndStage(
        source: _MemorySource(backupBytes),
        backupPassword: password,
        stagingFactory: (manifest, attachmentEncoding) =>
            BackupV2AttachmentDirectoryStaging.create(
              manifest,
              attachmentEncoding: attachmentEncoding,
              documentsDirectoryProvider: () async => documentsDirectory,
            ),
      );
      await importService.restoreFromV2PreparedPayload(
        payload: decoded.payload,
        attachmentStaging:
            decoded.staging as BackupV2AttachmentDirectoryStaging,
      );
    }

    final restored = File(
      p.join(documentsDirectory.path, 'attachments', 'fictional.enc'),
    );
    await restoreOnce();
    expect(
      await AttachmentCryptoService.decryptData(await restored.readAsBytes()),
      plaintext,
    );

    await restoreOnce();
    expect(await database.select(database.attachments).get(), hasLength(1));
    expect(
      await AttachmentCryptoService.decryptData(await restored.readAsBytes()),
      plaintext,
    );
  });

  test('覆盖恢复成功后清除不进入备份的图片预览与缩略图缓存', () async {
    final plaintext = Uint8List.fromList(<int>[1, 2, 3]);
    final payload = _payload(
      plaintext.length + 28,
      plainSize: plaintext.length,
    );
    final sink = _MemorySink();
    final password = _ephemeralPassword();
    await BackupV2Format.encodeToSink(
      plan: _portablePlan(payload, plaintext),
      backupPassword: password,
      sink: sink,
      iterations: 2,
    );
    final previews = Directory(
      p.join(documentsDirectory.path, 'attachment_previews'),
    );
    await previews.create();
    await File(
      p.join(previews.path, 'fictional.enc.preview.enc'),
    ).writeAsBytes(<int>[1, 2, 3]);
    final thumbnails = Directory(
      p.join(documentsDirectory.path, 'attachment_thumbnails'),
    );
    await thumbnails.create();
    await File(
      p.join(thumbnails.path, 'fictional.enc.thumbnail.enc'),
    ).writeAsBytes(<int>[4, 5, 6]);

    final decoded = await BackupV2Format.decodeAndStage(
      source: _MemorySource(sink.bytes),
      backupPassword: password,
      stagingFactory: (manifest, attachmentEncoding) =>
          BackupV2AttachmentDirectoryStaging.create(
            manifest,
            attachmentEncoding: attachmentEncoding,
            documentsDirectoryProvider: () async => documentsDirectory,
          ),
    );
    await BackupImportService(
      database: database,
      documentsDirectoryProvider: () async => documentsDirectory,
    ).restoreFromV2PreparedPayload(
      payload: decoded.payload,
      attachmentStaging: decoded.staging as BackupV2AttachmentDirectoryStaging,
    );

    expect(await previews.exists(), isFalse);
    expect(await thumbnails.exists(), isFalse);
  });

  test('已提交恢复的旧附件清理失败时，重开数据库后仍保留新附件', () async {
    await database.close();
    final databaseKey = base64UrlEncode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    AppDatabase openDatabase() => AppDatabase.fromOpener(
      EncryptedAppDatabaseOpener(
        databaseKey: databaseKey,
        databaseName: 'fixture.db',
        directoryOverride: documentsDirectory,
      ),
    );
    database = openDatabase();
    final oldPlaintext = Uint8List.fromList([1, 2, 3]);
    final newPlaintext = Uint8List.fromList([4, 5, 6]);
    Future<void> restoreBytes(Uint8List plaintext) async {
      final sink = _MemorySink();
      final password = _ephemeralPassword();
      await BackupV2Format.encodeToSink(
        plan: _portablePlan(
          _payload(plaintext.length + 28, plainSize: plaintext.length),
          plaintext,
        ),
        backupPassword: password,
        sink: sink,
        iterations: 2,
      );
      final decoded = await BackupV2Format.decodeAndStage(
        source: _MemorySource(sink.bytes),
        backupPassword: password,
        stagingFactory: (payload, encoding) =>
            BackupV2AttachmentDirectoryStaging.create(
              payload,
              attachmentEncoding: encoding,
              documentsDirectoryProvider: () async => documentsDirectory,
            ),
      );
      await BackupImportService(
        database: database,
        documentsDirectoryProvider: () async => documentsDirectory,
      ).restoreFromV2PreparedPayload(
        payload: decoded.payload,
        attachmentStaging:
            decoded.staging as BackupV2AttachmentDirectoryStaging,
      );
    }

    await restoreBytes(oldPlaintext);
    final parentZone = Zone.current;
    var cleanupFailures = 0;
    await IOOverrides.runZoned(
      () => restoreBytes(newPlaintext),
      createDirectory: (path) {
        final directory = parentZone.run(() => Directory(path));
        if (p.basename(path).startsWith('.attachments-restore-rollback-')) {
          return _FailingCleanupDirectory(directory, () => cleanupFailures++);
        }
        return directory;
      },
    );
    expect(cleanupFailures, 1);
    final journal = File(
      p.join(documentsDirectory.path, attachmentRestoreJournalFileName),
    );
    expect(await journal.exists(), isTrue);

    await database.close();
    database = openDatabase();
    await AttachmentRestoreRecoveryService(
      database: database,
      documentsDirectoryProvider: () async => documentsDirectory,
    ).recoverPendingRestore();

    final attachment = File(
      p.join(documentsDirectory.path, 'attachments', 'fictional.enc'),
    );
    expect(
      await AttachmentCryptoService.decryptData(await attachment.readAsBytes()),
      newPlaintext,
    );
    expect(await database.select(database.attachments).get(), hasLength(1));
    expect(await journal.exists(), isFalse);
    expect(
      (await documentsDirectory.list().toList()).where(
        (entry) =>
            p.basename(entry.path).startsWith('.attachments-restore-rollback-'),
      ),
      isEmpty,
    );
  });

  test('V3 零字节附件恢复后仍保留有效加密文件', () async {
    final payload = _payload(28, plainSize: 0);
    final sink = _MemorySink();
    final password = _ephemeralPassword();
    await BackupV2Format.encodeToSink(
      plan: _portablePlan(payload, Uint8List(0)),
      backupPassword: password,
      sink: sink,
      iterations: 2,
    );

    final decoded = await BackupV2Format.decodeAndStage(
      source: _MemorySource(sink.bytes),
      backupPassword: password,
      stagingFactory: (manifest, attachmentEncoding) =>
          BackupV2AttachmentDirectoryStaging.create(
            manifest,
            attachmentEncoding: attachmentEncoding,
            documentsDirectoryProvider: () async => documentsDirectory,
          ),
    );
    final importService = BackupImportService(
      database: database,
      documentsDirectoryProvider: () async => documentsDirectory,
    );
    await importService.restoreFromV2PreparedPayload(
      payload: decoded.payload,
      attachmentStaging: decoded.staging as BackupV2AttachmentDirectoryStaging,
    );

    final restored = File(
      p.join(documentsDirectory.path, 'attachments', 'fictional.enc'),
    );
    expect(await restored.exists(), isTrue);
    expect(await restored.length(), 28);
    expect(
      await AttachmentCryptoService.decryptData(await restored.readAsBytes()),
      isEmpty,
    );
  });

  test('V3 在本机密钥重建后会重新加密附件，不会留下损坏图片', () async {
    final plaintext = Uint8List.fromList(
      List<int>.generate(97, (index) => index % 251),
    );
    final payload = _payload(
      plaintext.length + 28,
      plainSize: plaintext.length,
    );
    final sink = _MemorySink();
    final password = _ephemeralPassword();

    AttachmentCryptoService.init(_testKey(51));
    await BackupV2Format.encodeToSink(
      plan: _portablePlan(payload, plaintext),
      backupPassword: password,
      sink: sink,
      iterations: 2,
    );

    AttachmentCryptoService.init(_testKey(52));
    final decoded = await BackupV2Format.decodeAndStage(
      source: _MemorySource(sink.bytes),
      backupPassword: password,
      stagingFactory: (manifest, attachmentEncoding) =>
          BackupV2AttachmentDirectoryStaging.create(
            manifest,
            attachmentEncoding: attachmentEncoding,
            documentsDirectoryProvider: () async => documentsDirectory,
          ),
    );
    final importService = BackupImportService(
      database: database,
      documentsDirectoryProvider: () async => documentsDirectory,
    );
    await importService.restoreFromV2PreparedPayload(
      payload: decoded.payload,
      attachmentStaging: decoded.staging as BackupV2AttachmentDirectoryStaging,
    );

    final restored = File(
      p.join(documentsDirectory.path, 'attachments', 'fictional.enc'),
    );
    expect(
      await AttachmentCryptoService.decryptData(await restored.readAsBytes()),
      plaintext,
    );
  });

  test('历史 V2 在本机密钥已重建时会在覆盖前拒绝附件恢复', () async {
    final plaintext = Uint8List.fromList(List<int>.generate(31, (i) => i));
    AttachmentCryptoService.init(_testKey(61));
    final oldEncrypted = await AttachmentCryptoService.encryptData(plaintext);
    final payload = _payload(oldEncrypted.length, plainSize: plaintext.length);
    final sink = _MemorySink();
    final password = _ephemeralPassword();
    await BackupV2Format.encodeToSink(
      plan: BackupV2ExportPlan(
        manifestPayload: payload,
        attachmentSourcesById: {
          payload.data.attachments.single.id: BackupV2AttachmentSource(
            attachment: payload.data.attachments.single,
            openEncryptedStream: () => Stream<List<int>>.value(oldEncrypted),
          ),
        },
      ),
      backupPassword: password,
      sink: sink,
      iterations: 2,
    );

    AttachmentCryptoService.init(_testKey(62));
    await expectLater(
      BackupV2Format.decodeAndStage(
        source: _MemorySource(sink.bytes),
        backupPassword: password,
        stagingFactory: (manifest, attachmentEncoding) =>
            BackupV2AttachmentDirectoryStaging.create(
              manifest,
              attachmentEncoding: attachmentEncoding,
              documentsDirectoryProvider: () async => documentsDirectory,
            ),
      ),
      throwsA(
        isA<BackupV2FormatException>().having(
          (error) => error.type,
          'type',
          BackupV2FormatErrorType.attachmentNotRecoverable,
        ),
      ),
    );
    expect(await Directory(documentsDirectory.path).list().toList(), isEmpty);
  });

  test('V2 密码错误后重开同一选择流，正确密码可直接再次认证', () async {
    final payload = _payload(28, plainSize: 0);
    final sink = _MemorySink();
    final password = _ephemeralPassword();
    await BackupV2Format.encodeToSink(
      plan: _portablePlan(payload, Uint8List(0)),
      backupPassword: password,
      sink: sink,
      iterations: 2,
    );
    final bytes = sink.bytes;
    var offset = 0;
    var restartCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(streamChannel, (call) async {
          switch (call.method) {
            case 'getSelectedStreamingBackupInfo':
              return <Object?, Object?>{
                'success': true,
                'sizeBytes': bytes.length,
              };
            case 'readSelectedStreamingBackupChunk':
              if (offset == bytes.length) {
                return <Object?, Object?>{'success': true, 'eof': true};
              }
              final end = min(offset + 97, bytes.length);
              final chunk = Uint8List.sublistView(bytes, offset, end);
              offset = end;
              return <Object?, Object?>{
                'success': true,
                'bytes': chunk,
                'eof': false,
              };
            case 'restartSelectedStreamingBackupRead':
              restartCalls++;
              offset = 0;
              return <Object?, Object?>{
                'success': true,
                'sizeBytes': bytes.length,
              };
            case 'closeSelectedStreamingBackupRead':
              return null;
          }
          return null;
        });
    final coordinator = BackupV2RestoreCoordinator(
      importService: BackupImportService(
        database: database,
        documentsDirectoryProvider: () async => documentsDirectory,
      ),
      supportedSchemaVersion: database.schemaVersion,
      documentsDirectoryProvider: () async => documentsDirectory,
    );

    await coordinator.prepareSelectedFile();
    await expectLater(
      coordinator.decryptAndPreviewManifest(backupPassword: '$password-wrong'),
      throwsA(
        isA<BackupFileRestoreDecryptPreviewException>().having(
          (error) => error.type,
          'type',
          BackupFileRestoreDecryptPreviewErrorType
              .invalidPasswordOrCorruptedData,
        ),
      ),
    );
    expect(restartCalls, 1);

    final preview = await coordinator.decryptAndPreviewManifest(
      backupPassword: password,
    );
    expect(preview.itemsCount, 1);
    expect(preview.requiresFullVerificationOnApply, isTrue);
    expect(coordinator.hasPreparedRestore, isTrue);
    expect(restartCalls, 2);

    final progress = <int>[];
    final restored = await coordinator.stageAndApply(
      backupPassword: password,
      onProgress: (value) => progress.add(value.readBytes),
    );
    expect(restored.restoredItemsCount, 1);
    expect(progress, isNotEmpty);
    expect(progress, contains(bytes.length));
    expect(coordinator.hasPreparedRestore, isFalse);
  });

  test('流式恢复清理后拒绝晚到的文件会话', () async {
    final opened = Completer<void>();
    final release = Completer<void>();
    var openCalls = 0;
    var closeCalls = 0;
    _mockSelectedBackup(
      Uint8List(0),
      beforeCall: (method) async {
        if (method == 'getSelectedStreamingBackupInfo') {
          openCalls++;
          if (!opened.isCompleted) {
            opened.complete();
            await release.future;
          }
        }
        if (method == 'closeSelectedStreamingBackupRead') closeCalls++;
      },
    );
    final coordinator = BackupV2RestoreCoordinator(
      importService: BackupImportService(database: database),
      supportedSchemaVersion: database.schemaVersion,
    );
    final pending = coordinator.prepareSelectedFile();
    await opened.future;
    final cleanup = coordinator.clearPreparedRestoreAndWait();
    final rejected = expectLater(
      pending,
      throwsA(isA<BackupFileRestoreDecryptPreviewException>()),
    );
    final nextSelection = coordinator.prepareSelectedFile();
    await Future<void>.delayed(Duration.zero);
    expect(openCalls, 1);
    release.complete();
    await rejected;
    await cleanup;
    await nextSelection;
    expect(openCalls, 2);
    await coordinator.clearPreparedRestoreAndWait();
    expect(closeCalls, 2);
    expect(coordinator.hasPreparedRestore, isFalse);
    expect(await database.select(database.items).get(), isEmpty);
  });

  for (final correctPassword in [true, false]) {
    test('流式恢复清理后拒绝晚到的${correctPassword ? '认证清单' : '密码重试会话'}', () async {
      final password = _ephemeralPassword();
      final sink = _MemorySink();
      await BackupV2Format.encodeToSink(
        plan: _portablePlan(_payload(28, plainSize: 0), Uint8List(0)),
        backupPassword: password,
        sink: sink,
        iterations: 2,
      );
      final restarting = Completer<void>();
      final release = Completer<void>();
      _mockSelectedBackup(
        sink.bytes,
        beforeCall: (method) async {
          if (method == 'restartSelectedStreamingBackupRead' &&
              !restarting.isCompleted) {
            restarting.complete();
            await release.future;
          }
        },
      );
      final coordinator = BackupV2RestoreCoordinator(
        importService: BackupImportService(database: database),
        supportedSchemaVersion: database.schemaVersion,
      );
      await coordinator.prepareSelectedFile();
      final pending = coordinator.decryptAndPreviewManifest(
        backupPassword: correctPassword ? password : '$password-wrong',
      );
      final rejected = expectLater(
        pending,
        throwsA(
          isA<BackupFileRestoreDecryptPreviewException>().having(
            (error) => error.type,
            'type',
            BackupFileRestoreDecryptPreviewErrorType.fileReadFailed,
          ),
        ),
      );
      await restarting.future;
      await coordinator.clearPreparedRestoreAndWait();
      await coordinator.prepareSelectedFile();
      release.complete();
      await rejected;
      expect(coordinator.hasPreparedRestore, isFalse);
      expect(await database.select(database.items).get(), isEmpty);

      final preview = await coordinator.decryptAndPreviewManifest(
        backupPassword: password,
      );
      expect(preview.itemsCount, 1);
      final cleanup = coordinator.clearPreparedRestoreAndWait();
      expect(coordinator.hasPreparedRestore, isFalse);
      await cleanup;
    });
  }

  test('流式恢复清理后完整认证的晚到结果不能覆盖数据', () async {
    final password = _ephemeralPassword();
    final sink = _MemorySink();
    await BackupV2Format.encodeToSink(
      plan: _portablePlan(_payload(28, plainSize: 0), Uint8List(0)),
      backupPassword: password,
      sink: sink,
      iterations: 2,
    );
    _mockSelectedBackup(sink.bytes, beforeCall: (_) async {});
    final coordinator = BackupV2RestoreCoordinator(
      importService: BackupImportService(
        database: database,
        documentsDirectoryProvider: () async => documentsDirectory,
      ),
      supportedSchemaVersion: database.schemaVersion,
      documentsDirectoryProvider: () async => documentsDirectory,
    );
    await coordinator.prepareSelectedFile();
    await coordinator.decryptAndPreviewManifest(backupPassword: password);
    var cleared = false;
    await expectLater(
      coordinator.stageAndApply(
        backupPassword: password,
        onProgress: (_) {
          if (!cleared) {
            cleared = true;
            coordinator.clearPreparedRestore();
          }
        },
      ),
      throwsA(
        isA<BackupFileRestoreApplyException>().having(
          (error) => error.type,
          'type',
          BackupFileRestoreApplyErrorType.fileReadFailed,
        ),
      ),
    );
    await coordinator.clearPreparedRestoreAndWait();
    expect(cleared, isTrue);
    expect(coordinator.hasPreparedRestore, isFalse);
    expect(await database.select(database.items).get(), isEmpty);
    expect(await documentsDirectory.list().toList(), isEmpty);
  });
}

void _mockSelectedBackup(
  Uint8List bytes, {
  required Future<void> Function(String method) beforeCall,
}) {
  var offset = 0;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('anch/backup_stream_v2'), (
        call,
      ) async {
        await beforeCall(call.method);
        switch (call.method) {
          case 'getSelectedStreamingBackupInfo':
            return <Object?, Object?>{
              'success': true,
              'sizeBytes': bytes.length,
            };
          case 'readSelectedStreamingBackupChunk':
            if (offset == bytes.length) {
              return <Object?, Object?>{'success': true, 'eof': true};
            }
            final chunk = Uint8List.sublistView(bytes, offset);
            offset = bytes.length;
            return <Object?, Object?>{'success': true, 'bytes': chunk};
          case 'restartSelectedStreamingBackupRead':
            offset = 0;
            return <Object?, Object?>{
              'success': true,
              'sizeBytes': bytes.length,
            };
          default:
            return null;
        }
      });
}

BackupPayloadV1 _payload(int encryptedSize, {int? plainSize}) {
  const familyId = '00000000-0000-4000-8000-000000000001';
  return BackupPayloadV1(
    exportedAt: 1,
    appVersion: 'test',
    schemaVersion: 8,
    source: BackupSourceInfo(appId: 'test', platform: 'test'),
    data: BackupDataV1(
      members: [
        BackupMemberV1(
          id: familyId,
          name: '虚构家庭',
          relationKey: 'family',
          isSystem: true,
          sortOrder: 0,
          createdAt: 1,
          updatedAt: 1,
          isArchived: false,
        ),
      ],
      items: [
        BackupItemV1(
          id: 'fictional-item',
          memberId: familyId,
          categoryKey: 'other',
          typeKey: 'other',
          templateVersion: 1,
          title: '虚构资料',
          createdAt: 1,
          updatedAt: 1,
          isFavorite: false,
          isPinned: false,
          sortOrder: 0,
          status: 'active',
        ),
      ],
      itemFields: const [],
      appSettings: const [],
      attachments: [
        BackupAttachmentV1(
          id: 'fictional-attachment',
          itemId: 'fictional-item',
          attachmentRole: 'other',
          fileName: 'fictional.enc',
          mimeType: 'application/octet-stream',
          plainSize: plainSize ?? encryptedSize,
          encryptedSize: encryptedSize,
          sortOrder: 0,
          status: 'active',
          createdAt: 1,
          updatedAt: 1,
          encryptedData: '',
        ),
      ],
      childEntries: const [],
      childFields: const [],
      itemEvents: const [],
      itemEventChanges: const [],
    ),
  );
}

BackupV2ExportPlan _portablePlan(BackupPayloadV1 payload, Uint8List plaintext) {
  final attachment = payload.data.attachments.single;
  return BackupV2ExportPlan(
    manifestPayload: payload,
    attachmentEncoding: BackupV2AttachmentEncoding.portablePlaintext,
    attachmentSourcesById: {
      attachment.id: BackupV2AttachmentSource(
        attachment: attachment,
        payloadSize: plaintext.length,
        openPayloadStream: () => Stream<List<int>>.fromIterable([
          plaintext.sublist(0, plaintext.length.clamp(0, 33).toInt()),
          plaintext.sublist(plaintext.length.clamp(0, 33).toInt()),
        ]),
      ),
    },
  );
}

String _ephemeralPassword() {
  final random = Random.secure();
  return List<String>.generate(
    20,
    (_) => String.fromCharCode(33 + random.nextInt(90)),
  ).join();
}

String _testKey(int byte) => base64UrlEncode(List<int>.filled(32, byte));

class _FailingCleanupDirectory implements Directory {
  _FailingCleanupDirectory(this.directory, this.onDelete);

  final Directory directory;
  final void Function() onDelete;

  @override
  String get path => directory.path;

  @override
  Future<bool> exists() => directory.exists();

  @override
  Future<Directory> delete({bool recursive = false}) async {
    onDelete();
    throw const FileSystemException('Synthetic cleanup failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemorySink implements BackupV2ByteSink {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  Uint8List get bytes => _builder.toBytes();

  @override
  Future<void> write(Uint8List bytes) async => _builder.add(bytes);
}

class _MemorySource implements BackupV2ByteSource {
  final Uint8List bytes;
  var _offset = 0;

  _MemorySource(this.bytes);

  @override
  Future<Uint8List?> readChunk() async {
    if (_offset == bytes.length) return null;
    final end = min(_offset + 701, bytes.length);
    final chunk = Uint8List.sublistView(bytes, _offset, end);
    _offset = end;
    return chunk;
  }
}
