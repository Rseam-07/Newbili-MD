import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/common/widgets/newbili_press_feedback.dart';
import 'package:PiliPlus/utils/cache_manager.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class CacheSettingsPage extends StatefulWidget {
  const CacheSettingsPage({
    super.key,
    this.loadUsage,
    this.clearCache,
    this.updateLimit,
    this.initialLimit,
  });
  final Future<CacheUsage> Function()? loadUsage;
  final Future<void> Function()? clearCache;
  final Future<void> Function(int)? updateLimit;
  final int? initialLimit;

  @override
  State<CacheSettingsPage> createState() => _CacheSettingsPageState();
}

class _CacheSettingsPageState extends State<CacheSettingsPage> {
  CacheUsage? _usage;
  late int _limit = widget.initialLimit ?? Pref.maxCacheSize.toInt();
  bool _busy = false;
  String? _message;
  bool _error = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final request = ++_request;
    try {
      final usage = await (widget.loadUsage ?? CacheManager.usage)();
      if (mounted && request == _request) setState(() => _usage = usage);
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _error = true;
          _message = '暂时无法读取占用，请重试';
        });
      }
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => _message = success);
      await _refresh();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = '未能完成，请检查可用空间后重试';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setLimit(int bytes) => _run(() async {
    await (widget.updateLimit ?? CacheManager.setLimit)(bytes);
    if (mounted) setState(() => _limit = bytes);
  }, '上限已更新，超出的闲置图片会自动回收');

  Future<void> _customLimit() async {
    var input = (_limit >> 20).toString();
    String? error;
    final value = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, rebuild) => AlertDialog(
          title: const Text('图片缓存上限'),
          content: TextFormField(
            initialValue: input,
            onChanged: (value) => input = value,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '32–2048 MB',
              suffixText: 'MB',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final mb = int.tryParse(input.trim());
                if (mb == null || mb < 32 || mb > 2048) {
                  rebuild(() => error = '请输入 32–2048 之间的整数');
                } else {
                  Navigator.pop(context, mb << 20);
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (value != null && mounted) await _setLimit(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = NewbiliMotion.duration(context, NewbiliMotion.container);
    return Scaffold(
      appBar: AppBar(
        title: const Text('存储与缓存'),
        actions: [
          IconButton(
            tooltip: '重新统计',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.storage_rounded,
                        size: 28,
                        color: scheme.onPrimaryContainer,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '图片与临时文件',
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: (_usage?.total ?? 0).toDouble()),
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        builder: (context, bytes, _) => FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _usage == null
                                ? '正在统计…'
                                : CacheManager.formatSize(bytes),
                            style: TextStyle(
                              fontSize: 36,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                          end: ((_usage?.images ?? 0) / _limit).clamp(0.0, 1.0),
                        ),
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        builder: (_, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                          backgroundColor: scheme.onPrimaryContainer.withValues(
                            alpha: .1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '图片缓存上限 ${CacheManager.formatSize(_limit)}',
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                NewbiliFormSection(
                  children: [
                    NewbiliSettingsRow(
                      title: '图片缓存',
                      subtitle: '封面、头像和播放预览',
                      icon: Icons.photo_library_outlined,
                      value: _usage == null
                          ? '—'
                          : CacheManager.formatSize(_usage!.images),
                    ),
                    NewbiliSettingsRow(
                      title: '临时文件',
                      subtitle: '导出与上传结束后自动释放',
                      icon: Icons.insert_drive_file_outlined,
                      value: _usage == null
                          ? '—'
                          : CacheManager.formatSize(_usage!.temporary),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '图片缓存上限',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '优先保留最近浏览的图片，超过上限自动回收。',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final mb in [128, 256, 512])
                            ChoiceChip(
                              label: Text('$mb MB'),
                              selected: _limit == mb << 20,
                              onSelected: _busy
                                  ? null
                                  : (_) => _setLimit(mb << 20),
                            ),
                          ActionChip(
                            label: const Text('自定义'),
                            onPressed: _busy ? null : _customLimit,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                NewbiliPressFeedback(
                  enabled: !_busy,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _busy
                        ? null
                        : () => _run(
                            widget.clearCache ?? CacheManager.clearLibraryCache,
                            '清理完成，正在使用的图片将在稍后回收',
                          ),
                    icon: AnimatedSwitcher(
                      duration: duration,
                      child: Icon(
                        _busy
                            ? Icons.hourglass_top_rounded
                            : Icons.cleaning_services_outlined,
                        key: ValueKey(_busy),
                      ),
                    ),
                    label: Text(_busy ? '正在整理…' : '清理缓存'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '离线视频、账号和设置会保留。正在保存或上传的文件会在完成后清理。',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                AnimatedSize(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _message == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _message!,
                              style: TextStyle(
                                color: _error ? scheme.error : scheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                NewbiliFormSection(
                  children: [
                    NewbiliSettingsRow(
                      title: '管理离线视频',
                      subtitle: '查看和删除已下载的视频',
                      icon: Icons.download_done_rounded,
                      onTap: () => Get.toNamed('/download'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
