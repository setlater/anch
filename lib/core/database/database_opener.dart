import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 抽象的数据库打开器接口
abstract class AppDatabaseOpener {
  QueryExecutor openConnection();
}

/// 临时明文 Native 数据库打开器实现，供开发验证及测试使用
class NativeAppDatabaseOpener implements AppDatabaseOpener {
  final String dbName;
  final bool inMemory;

  NativeAppDatabaseOpener({this.dbName = 'anch.db', this.inMemory = true});

  @override
  QueryExecutor openConnection() {
    return LazyDatabase(() async {
      if (inMemory) {
        return NativeDatabase.memory(
          setup: (db) {
            db.execute('PRAGMA foreign_keys = ON;');
          },
        );
      }
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, dbName));
      return NativeDatabase.createInBackground(
        file,
        setup: (db) {
          db.execute('PRAGMA foreign_keys = ON;');
        },
      );
    });
  }
}

// ============================================================
// ⚠️  正式密钥管理器已接入 (AppKeyManager)
// ⚠️  禁止硬编码任何默认密钥，此处移除所有开发占位密钥
// ============================================================

/// 基于 SQLite3MultipleCiphers 的加密文件数据库打开器
///
/// 使用 SQLiteMC PRAGMA key 打开本机加密数据库。
/// 数据库主密钥由 AppKeyManager 生成并通过平台安全存储保护。
///
/// === 数据库文件路径 ===
/// 默认使用 `getApplicationDocumentsDirectory()` 返回的 App 私有目录，
/// 例如 Android 上的 `/data/data/icu.codealive.anch/app_flutter/`。
/// 此目录由系统保护，无需声明任何外部存储权限（READ/WRITE_EXTERNAL_STORAGE）。
///
/// === 安全约定 ===
/// - 不打印密钥到任何日志（包括 debugPrint）
/// - 不在 UI 上展示密钥
/// - 不在成功或失败路径输出数据库运行日志
///
/// === 测试环境说明 ===
/// `fvm flutter test` 在宿主 Dart VM 上运行。
/// sqlite3mc hooks 对宿主机也生效（第一批实测验证），
/// 因此 PRAGMA key 能真实加密文件，错误密钥会触发 SqliteException(26)。
///
/// 已知 cipher_version 表现：
/// - Android background isolate 中：PRAGMA cipher_version 返回空值行，
///   不能用于 assert 判断 sqlite3mc 可用性。
/// - sqlite3mc 可用性已通过第一批 flutter build apk 编译验证确认。
class EncryptedAppDatabaseOpener implements AppDatabaseOpener {
  final String databaseName;
  final String databaseKey;

  /// 开发阶段密钥覆盖（仅测试/开发用），null 时使用传入的 databaseKey
  /// ⚠️ 生产版本不允许从外部传入明文密钥，此属性仅限测试使用
  final String? databaseKeyOverrideForTest;

  /// 目录覆盖（仅测试用），null 时使用 app 私有 documents 目录
  final Directory? directoryOverride;

  const EncryptedAppDatabaseOpener({
    required this.databaseKey,
    this.databaseName = 'anch_encrypted_dev.db',
    this.databaseKeyOverrideForTest,
    this.directoryOverride,
  });

  @override
  QueryExecutor openConnection() {
    final key = databaseKeyOverrideForTest ?? databaseKey;

    return LazyDatabase(() async {
      final directory =
          directoryOverride ?? await getApplicationDocumentsDirectory();
      final file = File(p.join(directory.path, databaseName));

      return NativeDatabase.createInBackground(
        file,
        setup: (db) {
          // 1. 设置加密密钥（必须在所有操作之前的第一步执行）。
          //    不打印密钥到日志，不在 UI 展示密钥。
          //    注意：PRAGMA cipher_version 在 Android background isolate
          //    中返回空值行，不能用作 sqlite3mc 可用性的 assert 判断依据。
          //    sqlite3mc 可用性已通过第一批 flutter build apk 编译验证确认。
          db.execute("PRAGMA key = '$key';");

          // 2. 开启外键约束
          db.execute('PRAGMA foreign_keys = ON;');
        },
      );
    });
  }
}
