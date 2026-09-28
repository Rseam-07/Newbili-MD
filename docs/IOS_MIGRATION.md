# iOS / iPadOS 迁移预览

2026-09-22 恢复迁移。MD 版使用 `AndroidFlutter/ios/Runner.xcworkspace`，和 Android 共用 Flutter 页面与 MD 设计。根目录的原生 Swift 工程仅为历史参考，不参与 MD 构建。

## 当前交付

- iOS 15 及以上，独立包名 `com.rseam07.newbili.md`，可与原生 Newbili 共存。
- 提供 **Release / ARM64 未签名 IPA**，需要使用自己的有效证书和匹配的描述文件签名后安装；不是 App Store / TestFlight 安装包。不要直接安装模拟器 `.app`。
- 预览包和说明：[Android 与 iOS 同步更新 · Build 19](https://github.com/Rseam-07/Newbili-MD/releases/tag/v1.1.0-build.19)。

## 本轮修复

- 模拟器保留原生媒体库的 ad-hoc 签名，修复编译成功但启动时 dyld 拒绝加载播放器的问题。
- 构建产物可放到非文档同步目录，避免 Finder 元数据导致 codesign 失败。
- 首次介绍统一使用应用的 Material 主题，修复主题脱节和浅色状态栏不可读。
- iOS 使用可交互的边缘返回动画，页面内容、封面及侧卡仍使用 MD 设计。
- `newbili-md://video/BV…` 接入已有视频路由；更新检查只选择 iOS 的 IPA，不提示安装 APK。
- 追更请求取消和替换按代次隔离，旧任务不能覆盖新任务状态；失效请求也不能继续追加通知。
- 账号 Hive 的随机 256-bit 加密密钥保存在 Keychain，读取失败不会退回明文存储。

## 已做的验收

在 iOS / iPadOS 26.5 模拟器中检查真实接口和原生插件，记录见 `docs/releases/IOS-PREVIEW-1.json`。

| 环境 | 检查内容 |
|---|---|
| iPhone 17 Pro，402 × 874 | 启动、首次介绍、真实推荐、搜索结果页、MD 视频链接、原生视频进度推进、暂停恢复、返回、Keychain、追更取消/替换 |
| iPad Pro 11，1210 × 834 | XCTest 操作系统横屏；真实视频、右侧评论卡片展开/切换/收起、暂停恢复、返回、同一套原生存储和追更检查 |
| 定向回归 | 7 项首次介绍检查、3 项版本与平台筛选检查 |

这是功能冒烟与布局验证，不是实机帧率或所有账号功能验收。模拟器上的长视频只播放了短片段。

## 构建

需要 Xcode、CocoaPods 和项目指定的独立 Flutter **3.47.2** SDK。

```sh
flutter config --no-enable-swift-package-manager
FLUTTER_BIN=/path/to/flutter/bin/flutter Scripts/prepare-android-flutter.sh
FLUTTER_BIN=/path/to/flutter/bin/flutter Scripts/build-md-ios.sh simulator
FLUTTER_BIN=/path/to/flutter/bin/flutter Scripts/build-md-ios.sh unsigned
```

`unsigned` 产物位于 `dist/`，使用正常的 `lib/main.dart` 入口，包含版本和提交信息。`simulator` 不使用 `--no-codesign`，并检查嵌入库的签名。

若工程位于 iCloud / Documents 同步目录，先将已有 `AndroidFlutter/build` 移至非同步目录，再设置 `MD_IOS_BUILD_DIR` 指向它。脚本不会删除或覆盖另一个构建目录。

### 可选的在线 iPad 冒烟

```sh
MD_IOS_TARGET=test_driver/ios_smoke.dart FLUTTER_BIN=/path/to/flutter/bin/flutter Scripts/build-md-ios.sh simulator
xcodebuild test -workspace AndroidFlutter/ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -destination 'platform=iOS Simulator,id=YOUR_IPAD_UDID' \
  -only-testing:RunnerUITests/RunnerUITests/testLandscapeLaunch \
  -parallel-testing-enabled NO ONLY_ACTIVE_ARCH=YES
```

仅在专用测试模拟器执行，检查会操作测试设备内的首次介绍、搜索历史和追更数据。报告与截图在 App 的 `Documents/ios-smoke/`；网络请求有超时，不无限等动画停止。`.github/workflows/md-ios.yml` 默认只做构建和定向回归，在线检查需手动启用。

## 仍需继续完成的边界

- iOS 系统画中画尚未接入；没有把 Android 的 JNI 入口当作 iOS 实现。
- 需要真实账号/真机继续验收：登录续期、账号切换、受限内容、收藏/投币/发送评论、消息实时性、投屏、长时间播放、缓存恢复和权限拒绝后的恢复。
- 后台音频插件已接入，仍需真机检查锁屏、来电与耳机切换。后台下载受 iOS 挂起限制，暂不承诺离开 App 后持续下载。
- 系统决定后台刷新的执行时间，15 分钟仅为最早请求时间，不等于定时任务或即时推送。
- iPad 保留多窗口能力。分屏窗口、外接屏、真实折叠设备的姿态切换和帧率尚未验收；不将模拟尺寸检查当成实机性能结论。
