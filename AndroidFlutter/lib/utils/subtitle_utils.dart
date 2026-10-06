import 'package:PiliPlus/models/common/enum_with_label.dart';
import 'package:collection/collection.dart' show IterableExtension;

enum SubtitleFormat implements EnumWithLabel {
  json('JSON'),
  vtt('WEBVTT'),
  srt('SRT');

  @override
  final String label;
  const SubtitleFormat(this.label);
}

abstract final class SubtitleUtils {
  static String _vttTimecode(num seconds) {
    final ms = (seconds * 1000).round();
    final h = (ms ~/ 3600000).toString().padLeft(2, '0');
    final m = (ms ~/ 60000 % 60).toString().padLeft(2, '0');
    final s = (ms ~/ 1000 % 60).toString().padLeft(2, '0');
    return '$h:$m:$s.${(ms % 1000).toString().padLeft(3, '0')}';
  }

  static String json2Vtt(List list) {
    final sb = StringBuffer('WEBVTT\n\n')
      ..writeAll(
        list
            .where(
              (item) =>
                  item['from'] is num &&
                  item['to'] is num &&
                  (item['from'] as num).isFinite &&
                  (item['to'] as num).isFinite &&
                  item['from'] >= 0 &&
                  item['to'] > item['from'] &&
                  item['content'] is String &&
                  item['content'].trim().isNotEmpty,
            )
            .map(
              (item) =>
                  '${_vttTimecode(item['from'])} --> ${_vttTimecode(item['to'])}\n${item['content'].trim()}',
            ),
        '\n\n',
      );
    return sb.toString();
  }

  /// Merge cue boundaries rather than matching line numbers. Languages often
  /// split sentences differently, so every interval keeps both active texts.
  /// Runs in an isolate when used by playback; cost is O(n log n).
  static String combineVtt(({String primary, String secondary}) tracks) {
    final first = _parseCues(tracks.primary);
    final second = _parseCues(tracks.secondary);
    final events = <({int time, int track, int id, String? text})>[];
    for (final (track, cues) in [first, second].indexed) {
      for (final (id, cue) in cues.indexed) {
        events
          ..add((time: cue.from, track: track, id: id, text: cue.text))
          ..add((time: cue.to, track: track, id: id, text: null));
      }
    }
    events.sort((a, b) => a.time.compareTo(b.time));
    final active = [<int, String>{}, <int, String>{}];
    final output = <({int from, int to, String text})>[];
    var i = 0;
    while (i < events.length) {
      final from = events[i].time;
      while (i < events.length && events[i].time == from) {
        final event = events[i++];
        if (event.text == null) {
          active[event.track].remove(event.id);
        } else {
          active[event.track][event.id] = event.text!;
        }
      }
      if (i == events.length) break;
      final to = events[i].time;
      final lines = <String>{};
      for (final cues in active) {
        for (final id in cues.keys.toList()..sort()) {
          lines.add(cues[id]!);
        }
      }
      if (lines.isEmpty || to <= from) continue;
      final text = lines.join('\n');
      if (output.isNotEmpty &&
          output.last.to == from &&
          output.last.text == text) {
        final previous = output.removeLast();
        output.add((from: previous.from, to: to, text: text));
      } else {
        output.add((from: from, to: to, text: text));
      }
    }
    return 'WEBVTT\n\n${output.map((cue) => '${_vttTimecode(cue.from / 1000)} --> ${_vttTimecode(cue.to / 1000)}\n${cue.text}').join('\n\n')}';
  }

  static List<({int from, int to, String text})> _parseCues(String source) {
    final normalized = source
        .replaceAll('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final cues = <({int from, int to, String text})>[];
    final clock = RegExp(r'^(?:(\d+):)?(\d{2}):(\d{2})[.,](\d{3})$');
    int? milliseconds(String value) {
      final match = clock.firstMatch(value);
      if (match == null) return null;
      final minutes = int.parse(match[2]!);
      final seconds = int.parse(match[3]!);
      if (seconds >= 60 || (match[1] != null && minutes >= 60)) return null;
      return ((int.parse(match[1] ?? '0') * 60 + minutes) * 60 + seconds) *
              1000 +
          int.parse(match[4]!);
    }

    for (final block in normalized.split(RegExp(r'\n\s*\n'))) {
      final lines = block.trim().split('\n');
      if (lines.isEmpty ||
          lines.first.startsWith('NOTE') ||
          lines.first == 'STYLE' ||
          lines.first == 'REGION') {
        continue;
      }
      final timing = lines.indexWhere((line) => line.contains('-->'));
      if (timing < 0) continue;
      final times = lines[timing].trim().split(RegExp(r'\s+-->\s+'));
      if (times.length != 2) continue;
      final from = milliseconds(times.first);
      final to = milliseconds(times.last.split(RegExp(r'\s+')).first);
      final text = lines.skip(timing + 1).join('\n').trim();
      if (from != null && to != null && to > from && text.isNotEmpty) {
        cues.add((from: from, to: to, text: text));
      }
    }
    if (cues.isEmpty && !normalized.trimLeft().startsWith('WEBVTT')) {
      throw const FormatException('双语字幕支持在线字幕与 VTT/SRT 文件');
    }
    return cues;
  }

  static String _srtTimecode(num seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    seconds %= 3600;
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    seconds %= 60;
    final s = seconds.toInt();
    final ms = ((seconds - s) * 1000).round().toString().padLeft(3, '0');
    return '$h:$m:${s.toString().padLeft(2, '0')},$ms';
  }

  static String json2Srt(List list) {
    final sb = StringBuffer()
      ..writeAll(
        list.mapIndexed(
          (i, e) =>
              '${i + 1}\n${_srtTimecode(e['from'])} --> ${_srtTimecode(e['to'])}\n${e['content'].trim()}',
        ),
        '\n\n',
      );
    return sb.toString();
  }
}
