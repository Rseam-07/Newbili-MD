# Newbili MD

一个以 Material Design 为核心的开源 Bilibili 客户端。从 Newbili 的 `android` 分支独立，保留完整提交历史。

- 官网：<https://rseam-07.github.io>（[Cloudflare 备用](https://newbili-md.ny-ravel.workers.dev)）
- 下载与更新日志：<https://rseam-07.github.io/downloads/>（官网 APK 直链，GitHub Releases 备用）
- 问题反馈：<https://github.com/Rseam-07/Newbili-MD/issues>

## 本轮改进

- 连贯的封面、页面与侧边内容卡片动画，补齐卡片和常用按钮按压、悬停、导航图标变化。离屏页面关闭 ticker，尊重减少动画设置。
- 按当前窗口与铰链布局播放页；支持左右分区及半折上下分区，保持播放器实例。
- 取消网络请求后停止重试，处理导航项删除越界和控制器销毁，存储初始化失败显示恢复指引而非直接退出。
- 官网默认跟随系统外观，支持手动深浅色切换，提供独立下载与更新日志页。
- iOS / iPadOS 迁移暂缓，优先完善 Android 与官网。已有探索记录保留在 [iOS 迁移说明](docs/IOS_MIGRATION.md)。

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

iOS 入口为暂缓的探索工程，当前 CI 只检查并构建 Android。

Android 沿用 `com.rseam07.newbili` 包名以保留原 MD 预览版的数据；独立仓库并不要求清除账号或缓存。iOS MD 包名是 `com.rseam07.newbili.md`，可以和原生 Newbili 共存。

## 致谢与许可

基于 [Newbili](https://github.com/Rseam-07/Newbili) 与 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 的工作继续开发。UI 研究参考了 Richasy 的 BiliBili-UWP 与 Qixingchen 的 MD-BiliBili。原许可与第三方声明保持有效，参见 [LICENSE](LICENSE) 与 [原项目说明](docs/UPSTREAM_README.md)。本项目与哔哩哔哩官方无隶属关系。
