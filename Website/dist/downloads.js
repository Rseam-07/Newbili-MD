'use strict';
document.querySelectorAll('.copy-hash').forEach(button => {
  button.addEventListener('click', async () => {
    const text = document.getElementById(button.dataset.copy).textContent.trim();
    const status = document.querySelector('.copy-status');
    if (!/^[a-f0-9]{64}$/.test(text)) { status.textContent = '安装包发布后会提供校验值。'; return; }
    try {
      await navigator.clipboard.writeText(text);
      status.textContent = '已复制 SHA-256 校验值。';
    } catch (_) {
      status.textContent = '浏览器暂不允许复制，请长按或选中上面的校验值复制。';
    }
  });
});
document.querySelectorAll('a[data-apk]').forEach(link => {
  link.addEventListener('click', () => {
    document.getElementById('download-notice').textContent = '浏览器将开始下载。若没有响应，可使用 GitHub 备用入口。';
  });
});
document.querySelectorAll('a[href="#architectures"]').forEach(link => {
  link.addEventListener('click', () => { document.getElementById('architectures').open = true; });
});
