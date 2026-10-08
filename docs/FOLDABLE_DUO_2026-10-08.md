# 折叠屏适配 · 1.2.0 / Build 22

Android 与 iOS / iPadOS 继续共用 MD 应用。以可调整大小的窗口和系统提供的区域为依据，覆盖外屏、展开、书本式半折、桌面观看、系统分屏和画中画挤压窗口后的布局。

## 实际行为

- 播放页使用同一个播放器、内容卡片和标签控制器。展开／合拢、窗口缩小和全屏往返只调整布局，保留选中的简介／评论／动态、评论滚动位置和播放状态，不重新请求视频源。
- 外屏或窄窗口将内容排在视频下方；展开后并排显示。物理铰链或有效的半折区域划分两部分：书本姿态在左右两侧排布，桌面姿态在上半屏播放，下半屏提供进度、播放／暂停、字幕、倍速与全屏操作。
- 播放页“观看布局”可选择自动、并排或桌面观看。无铰链接口的设备也能手动使用桌面观看；检测到实际分隔区域时优先保证避让，不凭型号或角度猜测铰链尺寸。
- 首页在 iOS 系统要求竖向操作栏时，将导航放到指定的 leading / trailing 边缘，预留系统安全区；大字体或可用高度较小时可以滚动导航。普通平板继续使用原有顶栏。
- 推荐网格保持同一条懒加载列表和滚动状态。单张封面与触控目标不跨越竖向铰链；处理 RTL、最后一行和零尺寸窗口。
- 布局过渡从当前画面继续，可打断；减少动态效果时直接到达目标状态。隐藏内容关闭 ticker；未增加逐帧软件绘制或后台轮询。iOS 保留 ProMotion 的系统帧调度配置，字体、指针／键盘输入和手写输入沿用现有 Flutter 控件支持。
- 两端版本为 1.2.0+22。Android 沿用原包名与测试渠道签名；iOS 未签名 IPA 仍需自行签名。

## iPhone Duo 原生接口与当前安装包边界

苹果的公开设计规范说明：外屏为 compact width，内屏为 regular width；适配应依据窗口、size class、安全区域和 reserved regions，不能只按某款手机的分辨率或固定宽度判断。系统分屏与多实例场景是不同能力，本轮支持与其他 App 分屏使用，未启用多个独立 Newbili 引擎实例。

公开的 `UIView.reservedRegions`、`UIHingeInteraction` 和 `UITraitCollection.verticalBarEdge` 从 **iOS 27.1** 提供。本机为 **Xcode 27.0 / iOS SDK 27.0**，也没有 Duo 模拟器。因此本次发布 IPA **没有启用自动铰链识别、Duo 原生竖向栏边缘信号**，可用部分是动态窗口／size class、安全区、内外屏连续布局和手动桌面观看。不得将这个包宣称为已经通过 Duo 真机验收。

`Scripts/configure-duo-sdk.sh` 在 SDK 27.1 或以上时用 Swift 编译器验证公开声明，成功才生成本机构建标志，启用 `SceneDelegate.swift` 中的原生桥接；声明不匹配时构建失败，避免静默发布不可用的识别功能。该分支已按公开文档实现，当前机器无法完成其编译及真机验证。

桥接读取当前 scene 的 Flutter view，而非 `UIScreen.main`；合并一轮布局通知，并去掉相同快照。Flutter 接受与当前窗口一致的区域数据，拒绝尺寸尚未同步的旧快照，尤其避免比例相同的内外屏转换错误。UI 缩放在应用现有 MediaQuery 层统一处理。

双面相机预览需要活动的拍摄会话；本轮没有为视频浏览客户端额外启动相机或新增相机配件场景。系统画中画启动能力与本轮“画中画挤压窗口后重新布局”的支持应分别验收。

## 验证

- 新增折叠几何、旧快照拒绝、懒加载网格避让测试。
- 交互覆盖外屏→内屏→书本→桌面→全屏→窄分屏，断言播放器 State、评论选项、滚动位置和交互状态保留；同时覆盖手动桌面布局、大字体、安全区及左右边缘导航。
- 复用并验证原有平板标签滑动、全屏中途反向、评论详情返回顺序。
- 只运行以上受影响测试；两端原生编译、包身份、签名、启动与在线下载结果另记于发布附件。Duo 自动识别和真机播放／功耗／120Hz 帧时间仍待新 SDK 和设备验收。

## 依据

- [Apple：Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/)
- [Apple：Strike a pose with adaptive layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/)
- [Apple：Leverage multiple displays and scenes on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111464/)
- [UIView.ReservedRegion](https://developer.apple.com/documentation/uikit/uiview/reservedregion)
- [UIHingeInteraction](https://developer.apple.com/documentation/uikit/uihingeinteraction)
