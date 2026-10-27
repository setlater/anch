// ignore_for_file: avoid_print

@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:anch/core/backup/backup_crypto.dart';
import 'package:anch/core/backup/backup_file_codec.dart';
import 'package:anch/core/backup/backup_payload.dart';
import 'package:flutter_test/flutter_test.dart';

const _miB = 1024 * 1024;

class _AttachmentProfile {
  const _AttachmentProfile(this.label, this.attachmentBytes);

  final String label;
  final List<int> attachmentBytes;

  int get totalAttachmentBytes => attachmentBytes.fold(0, (a, b) => a + b);
}

void main() {
  group('备份容量 V1 手动基准', () {
    for (final profile in const [
      _AttachmentProfile('无附件', []),
      _AttachmentProfile('单附件 5 MiB', [5 * _miB]),
      _AttachmentProfile('单附件 20 MiB', [20 * _miB]),
      _AttachmentProfile('双附件共 28 MiB', [14 * _miB, 14 * _miB]),
      _AttachmentProfile('双附件共 30 MiB', [15 * _miB, 15 * _miB]),
    ]) {
      test(profile.label, () async {
        final result = await _runProfile(
          profile,
          benchmarkPassword: _createEphemeralBenchmarkPassword(),
        );
        expect(result.decryptedAttachmentCount, profile.attachmentBytes.length);
        if (result.packageSizeBytes != null) {
          expect(result.packageSizeBytes, lessThanOrEqualTo(_maxPackageBytes));
        }
      });
    }
  });
}

const _maxPackageBytes = BackupFileCodec.maxBackupFileBytes;

class _ProfileResult {
  const _ProfileResult({
    required this.decryptedAttachmentCount,
    required this.packageSizeBytes,
  });

  final int decryptedAttachmentCount;
  final int? packageSizeBytes;
}

Future<_ProfileResult> _runProfile(
  _AttachmentProfile profile, {
  required String benchmarkPassword,
}) async {
  final beforeRss = ProcessInfo.currentRss;
  final buildStopwatch = Stopwatch()..start();
  final payload = _buildPayload(profile);
  buildStopwatch.stop();

  final encryptStopwatch = Stopwatch()..start();
  final envelope = await BackupCryptoService.encryptPayload(
    payload: payload,
    backupPassword: benchmarkPassword,
    iterations: BackupCryptoService.defaultIterations,
    nowMillisForTest: 0,
  );
  encryptStopwatch.stop();

  final codecStopwatch = Stopwatch()..start();
  int? packageSizeBytes;
  var packageAccepted = true;
  try {
    packageSizeBytes = BackupFileCodec.encodeEnvelope(
      envelope: envelope,
      nowMillis: 0,
    ).sizeBytes;
  } on BackupFileCodecException catch (error) {
    if (error.type != BackupFileCodecErrorType.fileTooLarge) rethrow;
    packageAccepted = false;
  }
  codecStopwatch.stop();

  final decryptStopwatch = Stopwatch()..start();
  final decrypted = await BackupCryptoService.decryptPayload(
    envelope: envelope,
    backupPassword: benchmarkPassword,
  );
  decryptStopwatch.stop();
  final afterRss = ProcessInfo.currentRss;

  print(
    '[backup-capacity] profile=${profile.label}; '
    'rawAttachments=${_formatMiB(profile.totalAttachmentBytes)}; '
    'build=${buildStopwatch.elapsedMilliseconds}ms; '
    'encrypt=${encryptStopwatch.elapsedMilliseconds}ms; '
    'envelope=${packageSizeBytes == null ? 'rejected' : _formatMiB(packageSizeBytes)}; '
    'encode=${codecStopwatch.elapsedMilliseconds}ms; '
    'decrypt=${decryptStopwatch.elapsedMilliseconds}ms; '
    'accepted=$packageAccepted; '
    'observedRssDelta=${_formatMiB(afterRss - beforeRss)}',
  );

  return _ProfileResult(
    decryptedAttachmentCount: decrypted.data.attachments.length,
    packageSizeBytes: packageSizeBytes,
  );
}

BackupPayloadV1 _buildPayload(_AttachmentProfile profile) {
  const itemId = 'benchmark-item';
  final attachments = <BackupAttachmentV1>[];
  for (var index = 0; index < profile.attachmentBytes.length; index++) {
    final byteLength = profile.attachmentBytes[index];
    attachments.add(
      BackupAttachmentV1(
        id: 'benchmark-attachment-$index',
        itemId: itemId,
        attachmentRole: 'other',
        fileName: 'benchmark-$index.enc',
        mimeType: 'application/octet-stream',
        plainSize: byteLength,
        encryptedSize: byteLength,
        sortOrder: index,
        status: 'active',
        createdAt: 0,
        updatedAt: 0,
        encryptedData: _fakeBase64Attachment(byteLength, index),
      ),
    );
  }

  return BackupPayloadV1(
    exportedAt: 0,
    appVersion: 'benchmark',
    schemaVersion: 8,
    source: BackupSourceInfo(
      appId: 'icu.codealive.anch.benchmark',
      platform: 'benchmark',
    ),
    data: BackupDataV1(
      members: [
        BackupMemberV1(
          id: 'benchmark-member',
          name: '虚构成员',
          relationKey: 'other',
          isSystem: false,
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
          isArchived: false,
        ),
      ],
      items: [
        BackupItemV1(
          id: itemId,
          memberId: 'benchmark-member',
          categoryKey: 'other',
          typeKey: 'other',
          templateVersion: 1,
          title: '虚构容量基准资料',
          createdAt: 0,
          updatedAt: 0,
          isFavorite: false,
          isPinned: false,
          sortOrder: 0,
          status: 'active',
        ),
      ],
      itemFields: const [],
      appSettings: const [],
      attachments: attachments,
    ),
  );
}

String _fakeBase64Attachment(int byteLength, int seed) {
  final bytes = Uint8List(byteLength);
  for (var index = 0; index < byteLength; index++) {
    bytes[index] = (index * 31 + seed * 17) & 0xff;
  }
  return base64Url.encode(bytes);
}

String _createEphemeralBenchmarkPassword() {
  final random = Random.secure();
  return List.generate(
    32,
    (_) => 33 + random.nextInt(94),
  ).map(String.fromCharCode).join();
}

String _formatMiB(int bytes) => '${(bytes / _miB).toStringAsFixed(1)}MiB';
