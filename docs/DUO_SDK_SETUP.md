# Duo SDK 构建环境

使用 Apple 官方的 [Xcode 27.1 RC（27A9275）](https://developer.apple.com/news/releases/?id=10052026g)。其 iOS 27.1 SDK 和 Duo 模拟器支持见 [Apple 发布说明](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)。应用下载页需要 Apple 账户登录，密码与验证码只在 Apple 页面输入。

安装要求 Apple silicon 与 macOS 26.6 或更新版本。旧 Xcode 可保留；使用项目级 `DEVELOPER_DIR` 指定新工具链，不必修改全局 `xcode-select`。

本机已安装 `/Applications/Xcode-27.1-RC.app`，Apple 软件签名与应用深层签名验证通过，实际 SDK 为 27.1，Duo 公开 API 编译检查通过。`build-md-ios.sh` 默认优先使用这个独立安装；调用方显式指定的 `DEVELOPER_DIR` 始终优先。

安装后先检查实际选中的 SDK，并要求原生 Duo API 编译通过：

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.1-RC.app/Contents/Developer
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
NEWBILI_REQUIRE_DUO_SDK=1 bash Scripts/configure-duo-sdk.sh
NEWBILI_REQUIRE_DUO_SDK=1 bash Scripts/build-md-ios.sh unsigned
```

`NEWBILI_REQUIRE_DUO_SDK=1` 禁止使用旧 SDK 的降级构建。公开声明的 Swift 编译检查失败时同样终止构建；不能仅根据版本号宣称已启用 Duo。未设置该选项时，旧 SDK 仍支持动态窗口和手动桌面观看。

模拟器需另外通过新 Xcode 安装 iOS 27.1 的 arm64 运行环境：

```sh
xcodebuild -downloadPlatform iOS -buildVersion 27.1 -architectureVariant arm64
xcrun simctl list runtimes
xcrun simctl list devicetypes
```

不额外导出运行环境副本，避免重复占用磁盘。SDK 编译、Duo 模拟器姿态验证和真机验收分别记录；模拟器通过不能替代真机播放连续性、功耗和帧时间验收。

发布下载页使用 `python3 Scripts/update-website-release.py --require-native-duo`，要求 IPA 二进制包含铰链、区域和边缘导航的原生链接。下载清单记录实际 SDK 和桥接启用状态；降级包不会被标为已启用原生能力。
