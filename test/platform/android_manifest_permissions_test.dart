@Tags(['platform'])
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

enum ManifestKind { main, debug, profile, releaseMerged }

void main() {
  group('AndroidManifest.xml 权限红线自动化测试', () {
    const backupDomains = [
      'root',
      'file',
      'database',
      'sharedpref',
      'external',
      'device_root',
      'device_file',
      'device_database',
      'device_sharedpref',
    ];

    // ⚠️ 【安全红线】禁止声明的高危/敏感权限列表
    final baseForbiddenPermissions = [
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
      'android.permission.MANAGE_EXTERNAL_STORAGE',
      'android.permission.READ_MEDIA_IMAGES',
      'android.permission.READ_MEDIA_VIDEO',
      'android.permission.READ_MEDIA_AUDIO',
      'android.permission.READ_MEDIA_VISUAL_USER_SELECTED',
      'android.permission.RECORD_AUDIO',
      'android.permission.POST_NOTIFICATIONS',
    ];

    // 获取特定 Manifest 类型禁止的权限列表
    List<String> forbiddenPermissionsForManifestKind(ManifestKind kind) {
      switch (kind) {
        case ManifestKind.main:
        case ManifestKind.releaseMerged:
          return baseForbiddenPermissions;
        case ManifestKind.debug:
        case ManifestKind.profile:
          // 调试与 Profile 清单可以包含 INTERNET，但严禁其它高危权限
          return [
            ...baseForbiddenPermissions,
            'android.permission.ACCESS_NETWORK_STATE',
          ];
      }
    }

    // 根据路径推断 Manifest 类型
    ManifestKind inferManifestKindFromPath(String path) {
      if (path.contains('src/main/')) {
        return ManifestKind.main;
      } else if (path.contains('src/debug/')) {
        return ManifestKind.debug;
      } else if (path.contains('src/profile/')) {
        return ManifestKind.profile;
      } else {
        return ManifestKind.releaseMerged;
      }
    }

    // 收集现存的 Manifest 文件
    List<File> collectExistingManifestFiles() {
      final possiblePaths = [
        'android/app/src/main/AndroidManifest.xml',
        'android/app/src/debug/AndroidManifest.xml',
        'android/app/src/profile/AndroidManifest.xml',
        // Release Merged Manifest 各种可能的中间路径 (取决于 Gradle/AGP 版本)
        'build/app/intermediates/merged_manifests/release/AndroidManifest.xml',
        'build/app/intermediates/merged_manifest/release/AndroidManifest.xml',
        'build/app/intermediates/packaged_manifests/release/AndroidManifest.xml',
      ];

      final files = <File>[];
      for (final path in possiblePaths) {
        final file = File(path);
        if (file.existsSync()) {
          files.add(file);
        }
      }
      return files;
    }

    test('对所有现存的 Manifest 配置文件及发布合并产物实施严格的权限白名单扫描', () {
      final existingFiles = collectExistingManifestFiles();

      // 必须确保 main, debug, profile 存在
      final hasMain = existingFiles.any((f) => f.path.contains('src/main/'));
      final hasDebug = existingFiles.any((f) => f.path.contains('src/debug/'));
      final hasProfile = existingFiles.any(
        (f) => f.path.contains('src/profile/'),
      );

      expect(hasMain, isTrue, reason: 'main AndroidManifest.xml 必须存在于源码中');
      expect(hasDebug, isTrue, reason: 'debug AndroidManifest.xml 必须存在于源码中');
      expect(
        hasProfile,
        isTrue,
        reason: 'profile AndroidManifest.xml 必须存在于源码中',
      );

      // 对收集到的每一个现存 Manifest 进行权限匹配断言
      for (final file in existingFiles) {
        final content = file.readAsStringSync();
        final kind = inferManifestKindFromPath(file.path);
        final forbiddenList = forbiddenPermissionsForManifestKind(kind);

        for (final permission in forbiddenList) {
          expect(
            content.contains(permission),
            isFalse,
            reason: '${file.path} (类型: ${kind.name}) 绝对不得包含违规权限声明: $permission',
          );
        }

        if (kind == ManifestKind.main || kind == ManifestKind.releaseMerged) {
          expect(
            content.contains('android.permission.INTERNET'),
            isFalse,
            reason: '${file.path} 不得在离线产品中声明 INTERNET',
          );
          expect(
            content.contains('android.permission.CAMERA'),
            isFalse,
            reason: '${file.path} 不得声明非功能所需 CAMERA',
          );
          expect(
            content.contains('android.permission.ACCESS_NETWORK_STATE'),
            isFalse,
            reason: '${file.path} 不得声明非功能所需网络状态权限',
          );
          expect(
            content.contains('android.permission.NEARBY_WIFI_DEVICES'),
            isFalse,
            reason: '${file.path} 不得声明非功能所需本地网络权限',
          );
        }

        // 调试与 Profile 源清单继续只额外声明 Flutter 工具所需 INTERNET。
        if (kind == ManifestKind.debug || kind == ManifestKind.profile) {
          expect(
            content.contains('android.permission.INTERNET'),
            isTrue,
            reason: '${file.path} (调试环境) 应该声明 android.permission.INTERNET 权限',
          );
          expect(content.contains('android.permission.CAMERA'), isFalse);
          expect(
            content.contains('android.permission.NEARBY_WIFI_DEVICES'),
            isFalse,
          );
        }
      }

      // ⚠️ 注释说明：若 release merged manifest 未被扫描到，需要先执行 fvm flutter build apk --release 后，再执行测试或进行手工文档走查以补齐审计。
    });

    test('主应用明确拒绝系统云备份与设备迁移，并排除全部本机数据域', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:allowBackup="false"'));
      expect(
        manifest,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );

      final legacyRules = File(
        'android/app/src/main/res/xml/backup_rules.xml',
      ).readAsStringSync();
      final modernRules = File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      ).readAsStringSync();
      expect(modernRules, contains('<cloud-backup>'));
      expect(modernRules, contains('<device-transfer>'));

      for (final domain in backupDomains) {
        final exclusion = '<exclude domain="$domain" path="." />';
        expect(
          legacyRules,
          contains(exclusion),
          reason: 'Android 11 及以下必须排除 $domain 数据域',
        );
        expect(
          exclusion.allMatches(modernRules),
          hasLength(2),
          reason: 'Android 12 及以上的云备份与设备迁移都必须排除 $domain 数据域',
        );
      }
    });
  });
}
