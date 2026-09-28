# Newbili MD 工作约定

- MD 应用入口为 `AndroidFlutter/`，Android 与 iOS 共用 Flutter 实现；根目录 `Newbili/` 是继承的原生 iOS 参考工程。
- 用户要求后续默认全平台更新：Android、iOS / iPadOS 都要维护、打包并在官网和 GitHub 提供下载。不要因为当前反馈来自某个平台而漏掉共享改动的另一个平台。
- 两端版本与构建号统一读取 `AndroidFlutter/pubspec.yaml`。发布流程与验收边界见 `docs/RELEASE_POLICY.md`。
- 用户要求避免反复跑测试。只验证改动涉及的逻辑和平台；已通过且源码未变的共享检查复用结果，打包及发布检查另行记录。
- 保留 Material Design、连续可打断动效、减少动态效果支持及性能约束。缓存清理必须保护账号、离线视频和正在使用的文件。
