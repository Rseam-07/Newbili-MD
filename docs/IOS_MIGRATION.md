# iOS / iPadOS 迁移

MD 版使用 `AndroidFlutter/ios/Runner.xcworkspace`。根目录的原生 Swift 工程是继承的参考实现，不参与 MD 构建。

## 已接入

- 和 Android 相同的 Flutter 页面、MD 主题、播放控制、评论、动态、搜索、收藏、消息、下载业务。
- iOS 原生插件：media_kit 视频、audio_service 后台音频与锁屏控制、WebView、相册/相机、分享、文件选择、屏幕亮度。
- Hive 账号数据的随机 256-bit 密钥由 Keychain 保存；不会因为读取失败退回明文。
- 原生追更：分 P 追更、关注 UP 新投稿、首次建立基线、最近更新、取消与撤销；后台刷新使用 BGAppRefreshTask，同账号配置变化会使在途结果失效。
- iPad 全方向与窗口缩放，不锁定全屏；普通大屏保留侧边内容卡片。Android 折叠屏使用 displayFeatures 中的铰链与半折信息，不假设 iOS 存在尚未验证的折叠硬件 API。

## 构建

```sh
flutter config --no-enable-swift-package-manager
FLUTTER_BIN=/path/to/flutter/bin/flutter Scripts/prepare-android-flutter.sh
cd AndroidFlutter
flutter build ios --simulator --debug --no-codesign --no-pub
```

最低 iOS 15。真机安装需自己的 Apple 开发者签名，在 Xcode 的 Runner target 中设置 Team。未签名模拟器构建不等同于可安装 IPA。

## 必须继续验收的边界

- iPhone / iPad 真机：登录续期、受限内容、长时间播放、投屏、缓存恢复、相册权限拒绝及恢复、系统后台调度和通知点击。
- iOS 系统画中画尚未接入；Android 画中画继续使用现有实现。后台下载仍受 iOS 挂起限制，不声称离开 App 后持续下载。
- iOS 系统决定后台刷新时机；设置 15 分钟是最早请求时间，不是固定执行周期或即时推送。
- 折叠布局先做确定性铰链/窗口测试；性能和姿态连续性仍需折叠屏实机验收。模拟尺寸不代表已做设备帧率测量。

官网明确标记“迁移预览”，暂不提供 App Store / TestFlight 的虚假入口。
