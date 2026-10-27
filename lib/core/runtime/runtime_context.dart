import 'package:meta/meta.dart';
import '../security/anch_security_runtime_config.dart';
import '../database/database_opener.dart';

/// 表示应用运行期的上下文配置与外部资源持有。
@immutable
class RuntimeContext {
  final AnchSecurityRuntimeConfig config;
  final AppDatabaseOpener databaseOpener;

  const RuntimeContext({required this.config, required this.databaseOpener});

  bool get isDevMode => config.mode == AnchSecurityMode.dev;
  bool get isEncrypted => config.useEncryptedDatabase;
  bool get isFormal => config.mode == AnchSecurityMode.formal;
}
