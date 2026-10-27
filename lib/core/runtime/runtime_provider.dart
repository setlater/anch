import 'runtime_context.dart';
import '../security/anch_security_runtime_config.dart';
import '../database/database_opener.dart';

/// 运行时上下文提供者，作为纯静态构造工厂。
class RuntimeProvider {
  static RuntimeContext create(
    AnchSecurityRuntimeConfig config, {
    String? databaseKey,
    AppDatabaseOpener? databaseOpenerOverride,
  }) {
    return RuntimeContext(
      config: config,
      databaseOpener: databaseOpenerOverride ?? _createDB(config, databaseKey),
    );
  }

  static AppDatabaseOpener _createDB(
    AnchSecurityRuntimeConfig config,
    String? databaseKey,
  ) {
    if (config.useEncryptedDatabase) {
      if (databaseKey == null) {
        throw ArgumentError(
          'databaseKey must be provided when useEncryptedDatabase is true',
        );
      }
      return EncryptedAppDatabaseOpener(
        databaseKey: databaseKey,
        databaseName: 'anch_encrypted_dev.db',
      );
    } else {
      return NativeAppDatabaseOpener(inMemory: true);
    }
  }
}
