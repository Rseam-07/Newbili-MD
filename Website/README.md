# Newbili MD 官网

零前端依赖的静态站。实际 Flutter 界面截图，滚动仅驱动 transform / opacity；没有滚轮拦截，没有后台循环动画。尊重系统减少动态效果设置，并提供页面内开关。

本地预览：`python3 -m http.server 56646 --directory Website/dist`

Cloudflare 发布：在 Website 中执行 `npx wrangler deploy`。使用当前用户已登录的 Cloudflare 账户；不提交令牌。

图片来自项目的界面渲染验收，演示封面属于 Blender 开源短片。更换截图时在原图之外生成 WebP，并保留署名。

主入口： https://rseam-07.github.io 。GitHub Pages 仓库 `Rseam-07/rseam-07.github.io` 存放 dist 的发布镜像；Cloudflare 保留为备用。

## 外观与下载

- `appearance.js` 在首屏样式之前设置主题，默认跟随系统。手动选择保存在本机，跨页、跨标签同步；存储不可用时仍可切换。
- 下载与更新日志在 `/downloads/`。主按钮使用 GitHub Pages 同域静态文件，GitHub Releases 为备用；不通过公共代理或短链转发 APK。
- APK 存放在 Pages 镜像仓库的 `downloads/files/`，不放进 Cloudflare 静态目录（单文件限额不同）。两个官网的下载按钮都指向 Pages 直链。
- 暂未使用国内 CDN，不能承诺中国大陆全部网络可达。

发布流程：先用 `Scripts/package-android-apk.sh` 验证并签名三份 APK，并用 `Scripts/build-md-ios.sh unsigned` 生成同版本 IPA；再执行 `python3 Scripts/update-website-release.py --date YYYY-MM-DD`。脚本从实际文件生成版本、大小、SHA-256、静态下载页与 `releases.json`，任一平台文件缺失或 IPA 内部版本不匹配会停止。默认发布标签为 `v版本-build.构建号`，可用 `--tag` 指定已有标签。两端版本统一读取 `AndroidFlutter/pubspec.yaml`，详见 `docs/RELEASE_POLICY.md`。`--pending` 仅用于本地设计预览，不得作为正式下载页发布。

同步 `Website/dist/` 到 Pages 镜像仓库（保留其 `.git` 和 `downloads/files`），把对应 APK 与校验清单放入 `downloads/files/` 后提交。页面更新不应触发 Android 构建。Cloudflare 在 Website 目录用当前账户执行 `wrangler deploy`。

新版本发布前，在 `downloads.template.html` 维护本次变更并将上一版条目保留在历史区，然后生成元数据与下载页。
