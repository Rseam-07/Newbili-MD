import 'package:PiliPlus/utils/subtitle_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String vtt(List<Map<String, dynamic>> cues) => SubtitleUtils.json2Vtt(cues);
  Map<String, dynamic> cue(num from, num to, String text) => {
    'from': from,
    'to': to,
    'content': text,
  };

  test('different language boundaries retain both texts, including gaps', () {
    final merged = SubtitleUtils.combineVtt((
      primary: vtt([cue(0, 2, '你好'), cue(2, 4, '世界'), cue(5, 6, '再见')]),
      secondary: vtt([cue(1, 3, 'Hello world'), cue(3, 4, 'Good day')]),
    ));
    expect(
      merged,
      'WEBVTT\n\n'
      '00:00:00.000 --> 00:00:01.000\n你好\n\n'
      '00:00:01.000 --> 00:00:02.000\n你好\nHello world\n\n'
      '00:00:02.000 --> 00:00:03.000\n世界\nHello world\n\n'
      '00:00:03.000 --> 00:00:04.000\n世界\nGood day\n\n'
      '00:00:05.000 --> 00:00:06.000\n再见',
    );
  });

  test(
    'identical translations coalesce without blinking at cue boundaries',
    () {
      final merged = SubtitleUtils.combineVtt((
        primary: vtt([cue(0, 4, 'Bilibili')]),
        secondary: vtt([cue(0, 2, 'Bilibili'), cue(2, 4, 'Bilibili')]),
      ));
      expect(merged, 'WEBVTT\n\n00:00:00.000 --> 00:00:04.000\nBilibili');
    },
  );

  test('overlapping cues, multiline SRT and VTT cue settings stay ordered', () {
    final merged = SubtitleUtils.combineVtt((
      primary: '\uFEFFWEBVTT\r\n\r\nfirst\r\n00:01.000 --> 00:03.000 align:start\r\n第一行\r\n第二行\r\n\r\n00:02.000 --> 00:04.000\r\n补充',
      secondary: '1\n00:00:01,500 --> 00:00:03,000\nFirst line\nSecond line',
    ));
    expect(
      merged,
      contains(
        '00:00:02.000 --> 00:00:03.000\n第一行\n第二行\n补充\nFirst line\nSecond line',
      ),
    );
    expect(merged, contains('00:00:03.000 --> 00:00:04.000\n补充'));
  });

  test('millisecond rounding carries across seconds, minutes and hours', () {
    expect(
      vtt([cue(59.9999, 3600.0001, 'rounded')]),
      'WEBVTT\n\n00:01:00.000 --> 01:00:00.000\nrounded',
    );
  });

  test('malformed and non-finite JSON cues are skipped', () {
    expect(
      vtt([
        cue(-1, 2, 'bad'),
        cue(2, 1, 'bad'),
        cue(double.nan, 5, 'bad'),
        cue(0, double.infinity, 'bad'),
        cue(0, 1, ' '),
        cue(0, 1, 'valid'),
      ]),
      'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nvalid',
    );
  });

  test('valid empty track leaves the other language unchanged', () {
    final primary = vtt([cue(0, 1, '保留')]);
    expect(
      SubtitleUtils.combineVtt((primary: primary, secondary: 'WEBVTT\n\n')),
      primary,
    );
  });

  test('ASS and unknown formats report a useful error', () {
    expect(
      () => SubtitleUtils.combineVtt((
        primary: 'WEBVTT',
        secondary: '[Script Info]\nTitle: ASS',
      )),
      throwsA(isA<FormatException>()),
    );
  });

  test('invalid clocks and NOTE blocks do not become captions', () {
    final merged = SubtitleUtils.combineVtt((
      primary: 'WEBVTT\n\nNOTE\n00:00:01.000 --> 00:00:02.000\nnote\n\n00:00:60.000 --> 00:01:02.000\ninvalid\n\n00:00:01.000 --> 00:00:02.000\nvalid',
      secondary: 'WEBVTT',
    ));
    expect(merged, 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nvalid');
  });
}
