/// 备份文件保存与读取策略纯函数工具类。
///
/// ⚠️ 【安全边界】
/// 1. 本类仅提供纯算法与数据转换服务，**严禁调用**任何平台通道、插件 API 或物理文件 I/O。
/// 2. 文件名只允许出现安全字符（小写字母 `a-z`、数字 `0-9`、`-`、`.`），防泄露个人敏感隐私，且防路径穿越。
abstract final class BackupFilePolicy {
  BackupFilePolicy._();

  /// 备份文件标准扩展名
  static const String extension = 'abk';

  /// 新导出备份的专用 MIME 类型。
  ///
  /// 不能使用通用的 `application/octet-stream`：部分 Android 文件提供方会
  /// 将它的建议文件名后缀改写为 `.bin`。子类型必须以 [extension] 结尾，
  /// 以兼容会从 MIME 子类型推导不可编辑后缀的文件提供方。
  static const String defaultMimeType = 'application/vnd.icu.codealive.abk';

  /// 历史导出文件使用的通用二进制 MIME 类型。
  ///
  /// 仅用于文件选择器兼容旧备份；新导出不会再使用它。
  static const String legacyMimeType = 'application/octet-stream';

  /// 当前已完成真机验证的 V2 备份容量。
  ///
  /// 它只用于提示耗时和目标位置空间风险，不是导出或恢复的硬上限。
  static const int verifiedV2CapacityBytes = 240 * 1024 * 1024;

  static bool exceedsVerifiedV2Capacity(int bytes) =>
      bytes > verifiedV2CapacityBytes;

  /// 根据传入的时间戳生成默认备份文件名。
  ///
  /// 使用本地时间，以避免时区差异导致文件名混乱或在界面展示上对用户产生误导。
  static String buildDefaultFileName({required int nowMillis}) {
    final localDateTime = DateTime.fromMillisecondsSinceEpoch(
      nowMillis,
      isUtc: false,
    );

    final year = localDateTime.year.toString();
    final month = localDateTime.month.toString().padLeft(2, '0');
    final day = localDateTime.day.toString().padLeft(2, '0');
    final hour = localDateTime.hour.toString().padLeft(2, '0');
    final minute = localDateTime.minute.toString().padLeft(2, '0');
    final second = localDateTime.second.toString().padLeft(2, '0');

    return 'anch-$year$month$day-$hour$minute$second.$extension';
  }

  /// 校验文件名是否匹配当前或历史默认格式的完整格式。
  ///
  /// 通过正则表达式严格匹配，在过滤非法文件名同时天然防御了路径穿越等危险输入。
  static bool isLikelyBackupFileName(String fileName) {
    // 当前格式为 anch-8位数字-6位数字.abk；兼容历史 anch-backup- 格式。
    final reg = RegExp(r'^anch(?:-backup)?-\d{8}-\d{6}\.abk$');
    return reg.hasMatch(fileName);
  }

  /// 格式化字节数为人类可读的容量大小提示。
  ///
  /// 若传入负数，安全返回 '0 B'。
  static String formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}
