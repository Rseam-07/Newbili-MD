# Android 与 iOS 同步更新

后续默认同时维护、构建和发布 Android 与 iOS / iPadOS。共享功能修复、缓存策略、设计和动效更新必须覆盖两端。某端尚未通过构建或缺少安装包时，应明确记录阻碍，不把该轮更新标为全平台完成。

- `AndroidFlutter/pubspec.yaml` 的 `version` 是两端版本号与构建号的唯一来源。iOS 不再另行维护构建号。
- CI 的共享检查只运行一轮，然后分别构建三个 Android 架构及未签名 iOS IPA。CI 的 Android 包是候选包，公开发布前必须由 `Scripts/package-android-apk.sh` 验证并沿用现有测试渠道签名。
- 本地已验证且源码未变时，打包不重复跑整套测试。验证发生变化的代码，以及各平台的编译、包身份、签名和必要启动流程；如实记录尚未完成的真机验收。
- 默认 GitHub 发布标签为 `v版本-build.构建号`，同一发布附上三份 APK、一份未签名 IPA 和校验清单。iOS 需用户自行签名。
- `Scripts/update-website-release.py` 只有在三份 APK 和同版本 IPA 均存在时才生成正式下载页；校验 IPA 内部版本，生成两端直链、大小、SHA-256 和统一清单。`--pending` 只用于本地设计预览。
- 官网同步更新下载页、`releases.json`、更新日志和对应的四份安装文件。发布后验证下载内容；保留历史版本与原有静态资源。

Build 19 补齐 Android 时复用已经验证的 iOS Build 19 安装包；共享应用代码一致，无需重复编译 iOS。该轮 Android 构建提交仅增加版本对齐与发布流程，不改变已验证的 Flutter 应用实现。
