class AliasRule {
  final String key;
  final List<String> targets;

  const AliasRule({required this.key, required this.targets});
}

class AliasRegistry {
  static const List<AliasRule> rules = [
    AliasRule(key: '招行', targets: ['招商银行', '招行']),
    AliasRule(key: '工行', targets: ['工商银行', '工行']),
    AliasRule(key: '中行', targets: ['中国银行', '中行']),
    AliasRule(key: '建行', targets: ['建设银行', '建行']),
  ];
}
