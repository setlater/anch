# 第三方材料来源与许可边界

项目自身的许可证不替代第三方材料的许可。发布源码、设计样张或安装包时，应按实际包含的材料保留各自署名、条款与修改说明。本文件提供来源入口，不代表已完成全部依赖的许可审查；最新核验范围与待办见 [路线图](../ROADMAP.md) 。

## 仓库内资源与静态数据

| 材料 | 本地位置与用途 | 来源与许可依据 |
| --- | --- | --- |
| Solar 1.2.5 | `assets/icons/solar/1.2.5/` 为应用图标，`design/prototype/assets/solar/1.2.5/` 为设计样张资源 | [480 Design 原仓库](https://github.com/480-Design/Solar-Icon-Set) 与 [发布包元数据](https://registry.npmjs.org/@iconify-json/solar/1.2.5) ；该版本包声明 CC-BY-4.0，本地 NOTICE 保留作者、许可链接和改动说明 |
| Phosphor 2.1.2 | `design/prototype/assets/phosphor/2.1.2/`，仅设计样张 | 本地随附 MIT LICENSE，保留其原有版权年份；[上游许可](https://github.com/phosphor-icons/core/blob/main/LICENSE) 同为 MIT，上游当前版权年份不用于覆盖旧版本文本 |
| 中国省／市／区县数据 | `lib/core/service/shipping_address_region_data.dart`，本地地址候选，不联网更新 | 来源为 `china-division` 2.7.0／[Administrative-divisions-of-China](https://github.com/modood/Administrative-divisions-of-China) 的三级数据；实际发布包许可原文与元数据差异保留在 [随包声明](../assets/licenses/china-division-2.7.0.txt) |

Solar 的应用内署名由 `lib/app/third_party_licenses.dart` 注册；不是 Dart 包依赖的静态材料不能仅依靠 Flutter 自动采集许可。Phosphor 随设计样张保留，不能因未进入 APK 而在公开源码时省略其许可。

### 行政区数据许可来源差异

2.7.0 [实际发布包](https://registry.npmjs.org/china-division/-/china-division-2.7.0.tgz) 中的 `LICENSE` 为 WTFPL，包内 `package.json` 与 [发布包元数据](https://registry.npmjs.org/china-division/2.7.0) 声明 MIT。该版本元数据指向提交 `6fb5380de7e6c961869dcd1629df4adc088fa9bb`，其中的 [LICENSE](https://github.com/modood/Administrative-divisions-of-China/blob/6fb5380de7e6c961869dcd1629df4adc088fa9bb/LICENSE) 与 [package.json](https://github.com/modood/Administrative-divisions-of-China/blob/6fb5380de7e6c961869dcd1629df4adc088fa9bb/package.json) 也保留同一差异；不能据此推断所有材料均只有一个一致的许可。

本地静态树的 3351 条记录与该发布包的 `provinces.json`、`cities.json`、`areas.json` 按代码、名称、父级及层级逐项比对一致，顺序也一致。来源已定位到实际取用版本，但数据一致性不消除许可声明差异。

署名按实际分发包的 LICENSE 原文保留，元数据中的 MIT 声明并列记录；不修改上游声明，也不以安册的 MIT 许可证替代。实际版本、数据来源与随包原文已可复核，元数据一致性尚未获得上游澄清，不将这两类结论混写为全部许可声明一致。

源仓库说明数据截至 2023-06-30，并已停止更新；解析结果仍需用户确认，不表述为实时或权威地址校验。解析设计见 [地址解析](shipping-address-parsing.md) 。

## Dart、Flutter 与原生依赖

- Dart 包版本以 `pubspec.lock` 为准，核对相应版本中的 LICENSE／NOTICE；Flutter SDK 子包需要一并追溯到固定 SDK 根许可，不能只按子目录是否存在 LICENSE 判断缺失。
- 应用内 Flutter 许可页与仓库来源清单用途不同；设计资源、派生静态数据和原生二进制仍需单独核对。
- sqlite3 3.3.2 的 [取源脚本](https://github.com/simolus3/sqlite3.dart/blob/sqlite3-3.3.2/tool/download_sqlite.dart) 固定使用 SQLiteMC 2.3.4／SQLite 3.53.1，预编译来源固定到 [sqlite3-3.3.2 发布页](https://github.com/simolus3/sqlite3.dart/releases/tag/sqlite3-3.3.2) 。ARM64 构建合并前的库与包内发布哈希一致，APK 中的库与 Gradle 去除调试符号后的产物一致；两阶段哈希不同，不直接把处理后的 APK 库与下载哈希比较。
- [SQLiteMC 声明](../assets/licenses/sqlite3mc-2.3.4.txt) 保留实际版本的 MIT 原文、原始组件版权与许可说明、SQLite 公共领域声明，以及组件引用的 CC0 和 Apache-2.0 全文；项目许可证不覆盖这些条款。
- [Android 原生依赖声明](../assets/licenses/android-dependencies.txt) 记录 ARM64 Release 解析坐标、发布者 POM 许可来源、父 POM 继承声明，以及依赖包内实际存在的 LICENSE／NOTICE。Flutter engine 与 embedding 的声明由固定 SDK 的 sky_engine/LICENSE 自动收集，不重新归入 Apache-2.0。

这些额外声明通过固定 Flutter SDK 支持的 `flutter.licenses` 配置加入自动生成的许可包，由现有应用许可页展示；无需新增运行时加载代码。修改依赖或 SDK 后须同步核对来源及最终 APK 许可内容，不能只检查源文件存在。

## 更新原则

增加或升级材料时同步核对来源、版本和许可；修改图标或数据时记录实际修改。没有明确依据的材料保留待确认状态，不根据文件名、仓库徽标或另一版本的条款替代判断。项目原创代码与文档采用 MIT，首次公开范围为当前源码快照；这些决定不替代第三方材料的各自许可。
