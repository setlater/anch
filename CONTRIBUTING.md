# 开发与反馈

安册由作者主导维护，优先修复核心流程、安全与数据可靠性问题。新增平台、模板业务和扩展能力先讨论范围；不接受以真实资料作为复现材料。项目原创代码与文档采用 [MIT 许可证](LICENSE) ，第三方材料保留各自许可，详见 [第三方材料说明](docs/third-party-materials.md) 。

## 开发环境

使用 `.fvmrc` 固定的 Flutter 3.44.2、JDK 17 和 Android SDK 36；应用最低 Android API 为 26。通过 Flutter 工具检查本机 Android 工具链，依赖版本以 `pubspec.lock` 为准。

```bash
fvm flutter doctor
fvm flutter pub get
fvm flutter analyze
fvm flutter test
```

GitHub Actions 在 `main` 推送和 PR 时运行静态分析、完整测试与 ARM64 贡献者 Debug 构建，使用 `.fvmrc` 中的固定 Flutter 版本及 JDK 17。工作流只读取仓库，不接入维护者签名、密钥或自动发行；CI 构建不是正式安装包，不能替代真机验证与发行准入。

## 贡献者应用

显式启用贡献者入口，不需要维护者的私有签名文件：

```bash
env ORG_GRADLE_PROJECT_anchContributor=true fvm flutter run -d <deviceId>
env ORG_GRADLE_PROJECT_anchContributor=true fvm flutter build apk --debug
```

应用标识为 `icu.codealive.anch.contributor`，使用本机默认开发签名，与正常安装隔离。该属性仅对当前命令生效，不建议保存为全局 Gradle 配置。默认 dev 模式使用内存数据库，进程退出后资料不保留。

需要体验加密持久化时，只能录入虚构资料：

```bash
env ORG_GRADLE_PROJECT_anchContributor=true fvm flutter run -d <deviceId> \
  --dart-define=ANCH_SECURITY_MODE=securityValidation
```

这仍是贡献者包，不替代维护者固定签名的安全验证。贡献者入口允许 Debug／Profile，禁止 Release，不配置内部 streaming_benchmark 模块。未启用属性时保持原内部签名要求；不要索要、提交或重新生成维护者签名。维护者构建见 [测试策略](docs/testing.md) 。

## 修改与反馈

提交前遵循 [项目规范](AGENTS.md) ，运行静态检查与完整测试。说明具体问题、用户可见变化和验证范围，避免无关格式化、重构或新依赖。涉及数据结构、备份兼容和安全规则时，先确认设计。

普通问题提供版本、Android 版本、复现步骤、预期与实际行为。截图只使用虚构资料，日志先移除个人内容、路径和设备标识。不上传数据库、备份、PIN、密码或密钥。

普通问题通过 [GitHub Issues](https://github.com/setlater/anch/issues) 反馈，项目不承诺响应时限。安全问题按 [安全报告说明](SECURITY.md) 使用私密入口处理，不在公开讨论中提交敏感复现材料。

## 源码与验证材料

公开主线以审查后的源码建立干净初始历史，完整旧开发历史保留在家庭私服。家庭私服与 GitHub 同步同一条公开主线；旧 main 与私有历史归档分支不得合入或推送到 GitHub，不使用 push --all。本机签名、编辑器设置、缓存和 `build/` 验证产物不进入公开文件，已有本地文件不因此删除。

路线图中的 `build/` 链接是维护者本机证据索引，公开快照不包含这些文件。能力、限制和验证范围在路线图正文说明，运行截图的来源见 [展示说明](docs/showcase/README.md) ；复现检查使用本文及 [测试策略](docs/testing.md) 中的命令，不通过收集他人的数据库、备份或签名补齐证据。
