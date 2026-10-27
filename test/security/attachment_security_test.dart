@Tags(['security'])
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/models/save_member_input.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/attachment/attachment_crypto_service.dart';
import 'package:anch/core/attachment/attachment_model.dart';
import 'package:anch/core/attachment/attachment_payload_reader.dart';
import 'package:anch/core/attachment/save_attachment_input.dart';
import 'package:anch/core/backup/backup_export_service.dart';
import 'package:anch/core/backup/backup_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MemberRepository memberRepo;
  late ItemRepository itemRepo;
  late BackupExportService exportService;
  late BackupImportService importService;
  late Directory testDir;

  const MethodChannel pathChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  setUp(() async {
    // 1. 设置 PathProvider 模拟通道，指定独立的临时目录作为 documents 目录
    testDir = Directory('./test_documents_directory');
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
    testDir.createSync(recursive: true);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return testDir.path;
          }
          return null;
        });

    // 2. 初始化数据库与 Repo
    final opener = NativeAppDatabaseOpener(inMemory: true);
    db = AppDatabase.fromOpener(opener);
    memberRepo = MemberRepository(db);
    itemRepo = ItemRepository(db);

    final metadata = BackupExportMetadata(
      appVersion: '1.0.0-test',
      schemaVersion: 1,
      appId: 'icu.codealive.anch',
      platform: 'test',
      locale: 'zh_CN',
    );

    exportService = BackupExportService(
      itemRepository: itemRepo,
      memberRepository: memberRepo,
      metadata: metadata,
    );

    importService = BackupImportService(database: db);

    // 3. 初始化主密钥
    AttachmentCryptoService.init(base64UrlEncode(List<int>.filled(32, 7)));
  });

  tearDown(() async {
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  });

  group('附件加解密服务 (AttachmentCryptoService) 安全性测试', () {
    test('0. 缺失或非法主密钥不得降级为固定附件密钥', () {
      expect(
        () => AttachmentCryptoService.init(''),
        throwsA(isA<StateError>()),
      );
      expect(
        () => AttachmentCryptoService.init('not-a-32-byte-base64-key'),
        throwsA(isA<StateError>()),
      );
    });

    test('1. 加解密一致性验证', () async {
      final plaintext = Uint8List.fromList(
        utf8.encode("Hello Anch Secure Attachment Data!"),
      );
      final encrypted = await AttachmentCryptoService.encryptData(plaintext);

      expect(
        encrypted.length,
        greaterThan(28),
      ); // nonce (12) + mac (16) + cipher

      final decrypted = await AttachmentCryptoService.decryptData(encrypted);
      expect(utf8.decode(decrypted), "Hello Anch Secure Attachment Data!");
    });

    test('1.1. 导出尺寸以实际加密封装为准而不是历史元数据', () async {
      final plaintext = Uint8List.fromList(utf8.encode('fictional attachment'));
      final encrypted = await AttachmentCryptoService.encryptData(plaintext);
      final attachmentsDirectory = Directory(
        p.join(testDir.path, 'attachments'),
      );
      await attachmentsDirectory.create();
      await File(
        p.join(attachmentsDirectory.path, 'fictional.enc'),
      ).writeAsBytes(encrypted);
      final attachment = AttachmentModel(
        id: 'fictional-attachment',
        itemId: 'fictional-item',
        attachmentRole: 'document',
        fileName: 'fictional.enc',
        mimeType: 'application/octet-stream',
        plainSize: plaintext.length + 99,
        encryptedSize: encrypted.length + 99,
        sortOrder: 0,
        status: 'active',
        createdAt: 1,
        updatedAt: 1,
      );

      expect(
        await AttachmentPayloadReader.resolvePlainSize(attachment),
        plaintext.length,
      );
      expect(await AttachmentPayloadReader.read(attachment), plaintext);
      expect(
        await AttachmentPayloadReader.readInBackground(attachment),
        plaintext,
      );
    });

    test('2. 错误主密钥或损坏数据时的解密安全阻断与脱敏异常抛出', () async {
      final plaintext = Uint8List.fromList(utf8.encode("Sensitive Doc Data"));
      final encrypted = await AttachmentCryptoService.encryptData(plaintext);

      // 错误密钥解密应抛出异常
      expect(
        () => AttachmentCryptoService.decryptData(
          encrypted,
          "wrong-db-key-value-1234567890-",
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('解密附件失败'),
          ),
        ),
      );

      // 篡改密文最后一个字节
      encrypted[encrypted.length - 1] ^= 0xFF;
      expect(
        () => AttachmentCryptoService.decryptData(encrypted),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('解密附件失败'),
          ),
        ),
      );
    });
  });

  group('附件数据仓库与物理垃圾清理集成测试', () {
    test('1. 验证新增附件落库且生成对应的物理密文文件，以及级联物理删除的闭环', () async {
      // 创建成员
      final memberId = await memberRepo.saveMember(
        SaveMemberInput(name: 'Test Member', memberType: 'person'),
      );

      // 模拟两个物理附件密文
      final docDir = testDir.path;
      final attachmentsDir = Directory(p.join(docDir, 'attachments'));
      attachmentsDir.createSync(recursive: true);

      final file1Name = 'att1.enc';
      final file2Name = 'att2.enc';
      final file1 = File(p.join(attachmentsDir.path, file1Name));
      final file2 = File(p.join(attachmentsDir.path, file2Name));
      final previewsDir = Directory(p.join(docDir, 'attachment_previews'));
      final preview1 = File(p.join(previewsDir.path, '$file1Name.preview.enc'));
      final preview2 = File(p.join(previewsDir.path, '$file2Name.preview.enc'));
      final thumbnailsDir = Directory(p.join(docDir, 'attachment_thumbnails'));
      final thumbnail1 = File(
        p.join(thumbnailsDir.path, '$file1Name.thumbnail.enc'),
      );
      final thumbnail2 = File(
        p.join(thumbnailsDir.path, '$file2Name.thumbnail.enc'),
      );

      await file1.writeAsBytes(
        await AttachmentCryptoService.encryptData(
          Uint8List.fromList([1, 2, 3]),
        ),
      );
      await file2.writeAsBytes(
        await AttachmentCryptoService.encryptData(
          Uint8List.fromList([4, 5, 6]),
        ),
      );
      await previewsDir.create(recursive: true);
      await preview1.writeAsBytes(<int>[1]);
      await preview2.writeAsBytes(<int>[2]);
      await thumbnailsDir.create(recursive: true);
      await thumbnail1.writeAsBytes(<int>[3]);
      await thumbnail2.writeAsBytes(<int>[4]);

      expect(file1.existsSync(), isTrue);
      expect(file2.existsSync(), isTrue);

      // 保存资料并挂载附件
      final itemId = await itemRepo.saveItemWithFields(
        SaveItemInput(
          memberId: memberId,
          categoryKey: 'identity',
          typeKey: 'id_card',
          title: 'ID Card with Attachments',
          fields: [],
          attachments: [
            SaveAttachmentInput(
              itemId: '', // 由 repo 自动回填
              attachmentRole: 'front',
              fileName: file1Name,
              mimeType: 'image/jpeg',
              plainSize: 3,
              encryptedSize: file1.lengthSync(),
              sortOrder: 0,
            ),
            SaveAttachmentInput(
              itemId: '',
              attachmentRole: 'back',
              fileName: file2Name,
              mimeType: 'image/jpeg',
              plainSize: 3,
              encryptedSize: file2.lengthSync(),
              sortOrder: 1,
            ),
          ],
        ),
      );

      // 验证联表查询是否能正常读出附件
      final item = await itemRepo.getItemWithFields(itemId);
      expect(item, isNotNull);
      expect(item!.attachments.length, 2);
      expect(item.attachments[0].fileName, file1Name);
      expect(item.attachments[1].fileName, file2Name);

      // 删除其中一个附件 (在 saveItemWithFields 时少传入一个)
      await itemRepo.saveItemWithFields(
        SaveItemInput(
          id: itemId,
          memberId: memberId,
          categoryKey: 'identity',
          typeKey: 'id_card',
          title: 'ID Card with Attachments',
          fields: [],
          attachments: [
            SaveAttachmentInput(
              itemId: itemId,
              attachmentRole: 'front',
              fileName: file1Name,
              mimeType: 'image/jpeg',
              plainSize: 3,
              encryptedSize: file1.lengthSync(),
              sortOrder: 0,
            ),
          ],
        ),
      );

      // 验证已从数据库删除，并且物理文件被清理
      final itemAfterUpdate = await itemRepo.getItemWithFields(itemId);
      expect(itemAfterUpdate!.attachments.length, 1);
      expect(file1.existsSync(), isTrue);
      expect(file2.existsSync(), isFalse); // file2 对应的物理文件已被自动清除
      expect(preview1.existsSync(), isTrue);
      expect(preview2.existsSync(), isFalse);
      expect(thumbnail1.existsSync(), isTrue);
      expect(thumbnail2.existsSync(), isFalse);

      // 物理删除条目
      await itemRepo.deleteItem(itemId);

      // 验证所有相关的数据库附件记录和物理加密文件均被清除
      final dbAtts = await db.select(db.attachments).get();
      expect(dbAtts, isEmpty);
      expect(file1.existsSync(), isFalse);
      expect(preview1.existsSync(), isFalse);
      expect(thumbnail1.existsSync(), isFalse);
    });
  });

  group('备份与恢复附件闭环测试 (E2E)', () {
    test('1. 完整备份导出与导入，验证附件数据与物理文件还原', () async {
      // 准备初始成员：系统内置的“家庭”虚拟成员已在 db onCreate 中自动插入，可直接使用
      const memberId = '00000000-0000-4000-8000-000000000001';

      // 模拟附件
      final docDir = testDir.path;
      final attachmentsDir = Directory(p.join(docDir, 'attachments'));
      attachmentsDir.createSync(recursive: true);

      final fileName = 'test_backup_att.enc';
      final file = File(p.join(attachmentsDir.path, fileName));
      final plainData = Uint8List.fromList(
        utf8.encode("Secure Backup Content"),
      );
      final encryptedData = await AttachmentCryptoService.encryptData(
        plainData,
      );
      await file.writeAsBytes(encryptedData);

      // 写入数据库
      final itemId = await itemRepo.saveItemWithFields(
        SaveItemInput(
          memberId: memberId,
          categoryKey: 'identity',
          typeKey: 'id_card',
          title: 'Backup Test Item',
          fields: [],
          attachments: [
            SaveAttachmentInput(
              itemId: '',
              attachmentRole: 'portrait',
              fileName: fileName,
              mimeType: 'image/png',
              plainSize: plainData.length,
              encryptedSize: encryptedData.length,
              sortOrder: 0,
            ),
          ],
        ),
      );

      // 执行导出
      final backupPassword = "strong-backup-pwd-789";
      final envelope = await exportService.exportEncryptedBackup(
        backupPassword: backupPassword,
        iterations: 1000,
      );

      // 验证导出的 JSON
      final envelopeJson = envelope.toJson();
      expect(envelopeJson['magic'], 'ANCH_BACKUP');

      // 物理删除本地文件，清空数据库，准备执行恢复
      file.deleteSync();
      await db.delete(db.attachments).go();
      await db.delete(db.itemFields).go();
      await db.delete(db.items).go();
      await db.delete(db.members).go();

      expect(file.existsSync(), isFalse);

      // 执行恢复
      final importResult = await importService.restoreFromEnvelope(
        envelope: envelope,
        backupPassword: backupPassword,
      );

      expect(importResult.restoredItemsCount, 1);

      // 验证数据库附件已恢复
      final itemAfterRestore = await itemRepo.getItemWithFields(itemId);
      expect(itemAfterRestore, isNotNull);
      expect(itemAfterRestore!.attachments.length, 1);
      expect(itemAfterRestore.attachments[0].fileName, fileName);

      // 验证物理文件已成功解密还原在对应位置并可以被解密
      expect(file.existsSync(), isTrue);
      final restoredEncryptedBytes = await file.readAsBytes();
      final restoredPlainBytes = await AttachmentCryptoService.decryptData(
        restoredEncryptedBytes,
      );
      expect(utf8.decode(restoredPlainBytes), "Secure Backup Content");
    });
  });
}
