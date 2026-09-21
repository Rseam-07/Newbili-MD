import 'package:PiliPlus/utils/update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only newer semantic releases trigger an update', () {
    expect(isNewerReleaseVersion('v1.1.1', '1.1.0'), isTrue);
    expect(isNewerReleaseVersion('v1.2.0', '1.1.9'), isTrue);
    expect(isNewerReleaseVersion('v2.0.0', '1.9.9'), isTrue);
    expect(isNewerReleaseVersion('v1.1.0', '1.1.0'), isFalse);
    expect(isNewerReleaseVersion('v1.0.9', '1.1.0'), isFalse);
    expect(isNewerReleaseVersion('latest', '1.1.0'), isFalse);
    expect(
      isNewerReleaseVersion('android-preview-2026.09.15', '1.1.0'),
      isFalse,
    );
    expect(isNewerReleaseVersion('v1.1.0+13', '1.1.0+12'), isTrue);
    expect(isNewerReleaseVersion('v1.1.0+12', '1.1.0+12'), isFalse);
  });
  test('Android updates select a newer APK, not date tags or iOS releases', () {
    final installedPreview = {
      'tag_name': 'android-preview-2026.09.15',
      'assets': [
        {'name': 'Newbili-Android-1.0.9-12-arm64-v8a-test.apk'},
      ],
    };
    final nextPreview = {
      'tag_name': 'android-preview-2026.09.16',
      'assets': [
        {'name': 'Newbili-MD-1.0.10-13-arm64-v8a.apk'},
      ],
    };
    final ios = {
      'tag_name': 'v2.0.0',
      'assets': [
        {'name': 'Newbili.ipa'},
      ],
    };
    expect(
      findNewerRelease([installedPreview, ios], '1.0.9+12', android: true),
      isNull,
    );
    expect(
      findNewerRelease(
        [installedPreview, nextPreview, ios],
        '1.0.9+12',
        android: true,
      ),
      same(nextPreview),
    );
    expect(findNewerRelease([nextPreview], '1.0.10+13', android: true), isNull);
    expect(
      findNewerRelease(
        [
          {...nextPreview, 'draft': true},
        ],
        '1.0.9+12',
        android: true,
      ),
      isNull,
    );
  });
  test(
    'iOS updates use IPA build metadata and ignore Android-only releases',
    () {
      final android = {
        'tag_name': 'v9.0.0',
        'assets': [
          {'name': 'Newbili-MD-9.0.0-99-arm64-v8a.apk'},
        ],
      };
      final preview = {
        'tag_name': 'v1.1.0-ios-preview.2',
        'assets': [
          {'name': 'Newbili-MD-1.1.0-18-iOS-unsigned.ipa'},
        ],
      };
      expect(findNewerRelease([android], '1.1.0+17', ios: true), isNull);
      expect(
        findNewerRelease([android, preview], '1.1.0+17', ios: true),
        same(preview),
      );
      expect(findNewerRelease([preview], '1.1.0+18', ios: true), isNull);
      expect(
        findNewerRelease(
          [
            {...preview, 'draft': true},
          ],
          '1.1.0+17',
          ios: true,
        ),
        isNull,
      );
    },
  );
}
