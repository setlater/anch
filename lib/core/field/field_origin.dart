enum FieldOrigin {
  user, // 用户手动输入或修改
  autofill, // 系统开发辅助自动填充
  systemSeed, // 系统底座预置数据
  unknown, // 元数据丢失或还原失败时的安全未知来源
}
