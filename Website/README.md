# Newbili MD 官网

零前端依赖的静态站。实际 Flutter 界面截图，滚动仅驱动 transform / opacity；没有滚轮拦截，没有后台循环动画。尊重系统减少动态效果设置，并提供页面内开关。

本地预览：`python3 -m http.server 56646 --directory Website/dist`

Cloudflare 发布：在 Website 中执行 `npx wrangler deploy`。使用当前用户已登录的 Cloudflare 账户；不提交令牌。

图片来自项目的界面渲染验收，演示封面属于 Blender 开源短片。更换截图时在原图之外生成 WebP，并保留署名。

主入口： https://rseam-07.github.io 。GitHub Pages 仓库 `Rseam-07/rseam-07.github.io` 存放 dist 的发布镜像；Cloudflare 保留为备用。
