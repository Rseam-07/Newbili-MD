import 'package:material_ui/material_ui.dart';

class SubtitleLanguageDialog extends StatefulWidget {
  const SubtitleLanguageDialog({
    super.key,
    required this.languages,
    required this.primaryIndex,
    required this.secondaryIndex,
  });
  final List<String> languages;
  final int primaryIndex;
  final int secondaryIndex;

  @override
  State<SubtitleLanguageDialog> createState() => _SubtitleLanguageDialogState();
}

class _SubtitleLanguageDialogState extends State<SubtitleLanguageDialog> {
  late int _primary = widget.primaryIndex.clamp(0, widget.languages.length);
  late int _secondary = widget.secondaryIndex == _primary
      ? 0
      : widget.secondaryIndex.clamp(0, widget.languages.length);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('字幕语言'),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _primary,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '主字幕'),
              items: [
                const DropdownMenuItem(value: 0, child: Text('关闭字幕')),
                for (final (index, language) in widget.languages.indexed)
                  DropdownMenuItem(
                    value: index + 1,
                    child: Text(language, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() {
                _primary = value!;
                if (_primary == 0 || _primary == _secondary) _secondary = 0;
              }),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<int>(
              key: ValueKey((_primary, _secondary)),
              initialValue: _primary == 0 ? 0 : _secondary,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '第二字幕'),
              items: [
                const DropdownMenuItem(value: 0, child: Text('不显示第二字幕')),
                for (final (index, language) in widget.languages.indexed)
                  if (index + 1 != _primary)
                    DropdownMenuItem(
                      value: index + 1,
                      child: Text(language, overflow: TextOverflow.ellipsis),
                    ),
              ],
              onChanged: _primary == 0 || widget.languages.length < 2
                  ? null
                  : (value) => setState(() => _secondary = value!),
            ),
            const SizedBox(height: 16),
            Text(
              widget.languages.length < 2
                  ? '该视频只有一个字幕轨道。可在播放器更多菜单中加载 VTT/SRT 字幕。'
                  : '主字幕在上，第二字幕在下，按各自时间轴同步显示。可选择视频提供的语言或已加载的 VTT/SRT 字幕。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(
          context,
        ).pop((primary: _primary, secondary: _primary == 0 ? 0 : _secondary)),
        child: const Text('应用'),
      ),
    ],
  );
}

Future<void> showSubtitleLanguages(
  BuildContext context, {
  required List<String> languages,
  required int primaryIndex,
  required int secondaryIndex,
  required Future<void> Function(int primary, int secondary) onApply,
}) async {
  final choice = await showDialog<({int primary, int secondary})>(
    context: context,
    builder: (_) => SubtitleLanguageDialog(
      languages: languages,
      primaryIndex: primaryIndex,
      secondaryIndex: secondaryIndex,
    ),
  );
  if (choice != null && context.mounted) {
    await onApply(choice.primary, choice.secondary);
  }
}
