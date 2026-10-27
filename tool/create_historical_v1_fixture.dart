import 'dart:io';

import 'package:anch/core/backup/backup_crypto.dart';
import 'package:anch/core/backup/backup_file_codec.dart';
import 'package:anch/core/backup/backup_payload.dart';

const _fixtureOutputPath =
    'build/manual-fixtures/historical-v1-virtual-backup.abk';
const _historicalExportedAt = 1718035200000;

// 历史 V1 备份所要求的系统家庭成员固定标识。工具不能导入数据库层，
// 否则普通 Dart CLI 会间接加载 Flutter 平台 API。
const _systemFamilyMemberId = '00000000-0000-4000-8000-000000000001';

Future<void> main() async {
  if (!stdin.hasTerminal) {
    stderr.writeln('需要在本地交互式终端中运行，未生成备份文件。');
    exitCode = 64;
    return;
  }

  stdout.write('输入仅用于本次虚构 V1 备份的临时密码：');
  var previousEchoMode = true;
  var echoModeChanged = false;
  String? backupPassword;
  try {
    previousEchoMode = stdin.echoMode;
    stdin.echoMode = false;
    echoModeChanged = true;
    backupPassword = stdin.readLineSync();
  } on StdinException {
    stderr.writeln('当前终端无法启用隐藏输入，未生成备份文件。');
    exitCode = 64;
    return;
  } finally {
    if (echoModeChanged) {
      stdin.echoMode = previousEchoMode;
    }
    stdout.writeln();
  }

  if (backupPassword == null || backupPassword.trim().length < 8) {
    stderr.writeln('临时密码至少需要 8 个字符，未生成备份文件。');
    exitCode = 64;
    return;
  }

  final output = File(_fixtureOutputPath);
  if (await output.exists()) {
    stderr.writeln('测试备份已存在，未覆盖现有文件。');
    exitCode = 73;
    return;
  }

  final payload = BackupPayloadV1(
    exportedAt: _historicalExportedAt,
    appVersion: '1.0.0',
    schemaVersion: 8,
    source: BackupSourceInfo(
      appId: 'icu.codealive.anch',
      platform: 'android',
      locale: 'zh_CN',
      exportMode: 'manual',
    ),
    data: BackupDataV1(
      members: [
        BackupMemberV1(
          id: _systemFamilyMemberId,
          name: '虚构家庭',
          relationKey: 'family',
          isSystem: true,
          sortOrder: 0,
          createdAt: _historicalExportedAt,
          updatedAt: _historicalExportedAt,
          isArchived: false,
        ),
      ],
      items: [
        BackupItemV1(
          id: 'fixture-v1-item',
          memberId: _systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'other',
          templateVersion: 1,
          title: 'V1 虚构恢复资料',
          createdAt: _historicalExportedAt,
          updatedAt: _historicalExportedAt,
          isFavorite: false,
          isPinned: false,
          sortOrder: 0,
          status: 'active',
        ),
      ],
      itemFields: const [],
      appSettings: const [],
    ),
  );

  final envelope = await BackupCryptoService.encryptPayload(
    payload: payload,
    backupPassword: backupPassword,
  );
  backupPassword = null;
  final package = BackupFileCodec.encodeEnvelope(
    envelope: envelope,
    nowMillis: _historicalExportedAt,
  );

  await output.parent.create(recursive: true);
  await output.create(exclusive: true);
  await output.writeAsBytes(package.bytes, flush: true);
  stdout.writeln('已生成仅含虚构资料的历史 V1 测试备份。');
}
