import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// The stable lower surface in tabletop mode. Scrubbing never recreates or
/// pauses the player; the preview value is local until the gesture commits.
class FoldablePlaybackDock extends StatefulWidget {
  const FoldablePlaybackDock({
    super.key,
    required this.controller,
    required this.onSubtitles,
    this.title,
    this.onStart,
  });
  final PlPlayerController controller;
  final VoidCallback onSubtitles;
  final String? title;
  final Future<void> Function()? onStart;
  @override
  State<FoldablePlaybackDock> createState() => _FoldablePlaybackDockState();
}

class _FoldablePlaybackDockState extends State<FoldablePlaybackDock> {
  double? _scrub;
  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) SmartDialog.showToast('操作未完成，请重试');
    }
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final c = widget.controller;
    final duration = c.duration.value;
    final ready = c.videoPlayerController != null;
    final playing = ready && c.playerStatus.isPlaying;
    final value = (_scrub ?? c.position.value.toDouble()).clamp(
      0.0,
      duration.toDouble(),
    );
    final controls = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: playing ? '暂停' : '播放',
            onPressed: !ready && widget.onStart == null
                ? null
                : () => _perform(
                    !ready
                        ? widget.onStart!
                        : playing
                        ? c.pause
                        : c.play,
                  ),
            icon: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 28,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Slider(
                  value: value,
                  max: duration > 0 ? duration.toDouble() : 1,
                  label: DurationUtils.formatDuration(value.round()),
                  onChangeStart: !ready || duration <= 0
                      ? null
                      : (v) => setState(() => _scrub = v),
                  onChanged: !ready || duration <= 0
                      ? null
                      : (v) => setState(() => _scrub = v),
                  onChangeEnd: (v) {
                    setState(() => _scrub = null);
                    _perform(() => c.seekTo(Duration(seconds: v.round())));
                  },
                ),
                Text(
                  '${DurationUtils.formatDuration(value.round())} / ${DurationUtils.formatDuration(duration)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '字幕与双语字幕',
            onPressed: widget.onSubtitles,
            icon: const Icon(Icons.subtitles_outlined),
          ),
          PopupMenuButton<double>(
            tooltip: '播放速度',
            icon: const Icon(Icons.speed_rounded),
            initialValue: c.playbackSpeed,
            onSelected: (speed) => _perform(() => c.setPlaybackSpeed(speed)),
            itemBuilder: (_) => [
              for (final speed in const [.5, .75, 1.0, 1.25, 1.5, 2.0])
                CheckedPopupMenuItem(
                  value: speed,
                  checked: c.playbackSpeed == speed,
                  child: Text('${speed}x'),
                ),
            ],
          ),
          IconButton(
            tooltip: c.isFullScreen.value ? '退出全屏' : '全屏',
            onPressed: () => c.triggerFullScreen(status: !c.isFullScreen.value),
            icon: Icon(
              c.isFullScreen.value
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxHeight < 160) return controls;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight - 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.title?.isNotEmpty == true) ...[
                  Text(
                    widget.title!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
                SizedBox(height: 80, child: controls),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: '后退 10 秒',
                      icon: const Icon(Icons.replay_10_rounded),
                      onPressed: !ready
                          ? null
                          : () => _perform(
                              () => c.seekTo(
                                Duration(
                                  seconds: (c.position.value - 10).clamp(
                                    0,
                                    duration,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      tooltip: '前进 10 秒',
                      icon: const Icon(Icons.forward_10_rounded),
                      onPressed: !ready
                          ? null
                          : () => _perform(
                              () => c.seekTo(
                                Duration(
                                  seconds: (c.position.value + 10).clamp(
                                    0,
                                    duration,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  });
}
