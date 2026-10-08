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
  });
  final PlPlayerController controller;
  final VoidCallback onSubtitles;
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
    final playing = c.playerStatus.isPlaying;
    final value = (_scrub ?? c.position.value.toDouble()).clamp(
      0.0,
      duration.toDouble(),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: playing ? '暂停' : '播放',
            onPressed: !ready
                ? null
                : () => _perform(playing ? c.pause : c.play),
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
            onPressed: c.triggerFullScreen,
            icon: Icon(
              c.isFullScreen.value
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
            ),
          ),
        ],
      ),
    );
  });
}
