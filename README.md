# Newbili MD

一个以 Material Design 为核心的开源 Bilibili 客户端。从 Newbili 的 `android` 分支独立，保留完整提交历史。

- 官网：<https://rseam-07.github.io>（[Cloudflare 备用](https://newbili-md.ny-ravel.workers.dev)）
- 下载与更新日志：<https://rseam-07.github.io/downloads/>（官网 APK / IPA 直链，GitHub Releases 备用）
- 问题反馈：<https://github.com/Rseam-07/Newbili-MD/issues>

## 本轮改进

- Android 与 iOS 同步提供 **1.1.1 · Build 21**：修复横屏全屏往返闪烁和评论图片导致暂停／重载，补齐平板侧卡滑动、关于页与双语字幕。详见 [本轮说明](docs/PLAYER_AND_SUBTITLES_2026-10-06.md)。
- Build 19：默认图片缓存降至 256 MB，增加“存储与缓存”管理，保护下载、账号和使用中的文件；限制预览图内存并补齐细节动效。详见 [本轮说明](docs/CACHE_AND_MOTION_2026-09-28.md)。
- 连贯的封面、页面与侧边内容卡片动画，补齐卡片和常用按钮按压、悬停、导航图标变化。离屏页面关闭 ticker，尊重减少动画设置。
- 按当前窗口与铰链布局播放页；支持左右分区及半折上下分区，保持播放器实例。
- 取消网络请求后停止重试，处理导航项删除越界和控制器销毁，存储初始化失败显示恢复指引而非直接退出。
- 官网默认跟随系统外观，支持手动深浅色切换，提供独立下载与更新日志页。
- iOS / iPadOS 迁移已恢复，复用 MD 页面与原生播放插件，提供需自行签名的 IPA 预览。验收记录与待完成项见 [iOS 迁移说明](docs/IOS_MIGRATION.md)。

## 目录

| 目录 | 内容 |
|---|---|
| `AndroidFlutter/` | 共享 MD 应用，含 Android 和 iOS 原生入口。保留原目录名以兼容已有脚本 |
| `Website/` | 官网静态源文件与 Cloudflare Workers 配置 |
| `Brand/` | 标志与应用图标源文件 |
| `Newbili/`、`Newbili.xcodeproj/` | 继承的原生 iOS 参考代码，不是 MD 版构建入口 |

## 开发

需要 Flutter **3.47.2**。项目有上游框架补丁，请使用独立 Flutter SDK，避免影响其他项目。

```sh
FLUTTER_BIN=/path/to/flutter/bin/flutter Scripts/prepare-android-flutter.sh
cd AndroidFlutter
flutter run
```

后续默认 Android 与 iOS 同步更新，版本统一读取 `AndroidFlutter/pubspec.yaml`。`.github/workflows/md-build.yml` 在共享检查后构建两端候选包；`.github/workflows/md-ios.yml` 保留手动 iOS / iPad 模拟器诊断。iOS 构建使用 `Scripts/build-md-ios.sh`，安装条件见 [iOS 迁移说明](docs/IOS_MIGRATION.md)，发布步骤见 [全平台发布规则](docs/RELEASE_POLICY.md)。

Android 沿用 `com.rseam07.newbili` 包名以保留原 MD 预览版的数据；独立仓库并不要求清除账号或缓存。iOS MD 包名是 `com.rseam07.newbili.md`，可以和原生 Newbili 共存。

## 致谢与许可

基于 [Newbili](https://github.com/Rseam-07/Newbili) 与 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 的工作继续开发。UI 研究参考了 Richasy 的 BiliBili-UWP 与 Qixingchen 的 MD-BiliBili。原许可与第三方声明保持有效，参见 [LICENSE](LICENSE) 与 [原项目说明](docs/UPSTREAM_README.md)。本项目与哔哩哔哩官方无隶属关系。
