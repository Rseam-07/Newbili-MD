import 'package:PiliPlus/utils/web_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const invitation =
      'https://www.bilibili.com/blackboard/era/4uNKuLdhsvPBAoe2.html?legacy_jump=staff&new_jump=staff&is_owner=0&wbType=common&aid=117308626310327';

  test(
    'official staff landing page reaches its authenticated web fallback',
    () {
      final target = resolveWebLink(Uri.parse(invitation))!;
      expect(target.host, 'member.bilibili.com');
      final route = Uri.parse(target.fragment);
      expect(route.path, '/upload-manager/article/cooperation');
      expect(route.queryParameters['aid'], '117308626310327');
      expect(route.queryParameters['is_owner'], '0');
    },
  );

  test('wrapped invitations and native staff links resolve consistently', () {
    final wrapped = Uri(
      scheme: 'bilibili',
      host: 'browser',
      queryParameters: {'url': invitation},
    );
    expect(resolveWebLink(wrapped), resolveWebLink(Uri.parse(invitation)));
    expect(
      resolveWebLink(
        Uri.parse(
          'bilibili://uper/join_up/cooperate?aid=117308626310327&is_owner=0',
        ),
      ),
      resolveWebLink(Uri.parse(invitation)),
    );
  });

  test('ordinary web links keep their hash and encoded query values', () {
    final url = Uri.parse(
      'https://example.com/form?return=%2Fedit%3Fx%3D1#step2',
    );
    expect(
      resolveWebLink(
        Uri(
          scheme: 'bilibili',
          host: 'browser',
          queryParameters: {'url': url.toString()},
        ),
      ),
      url,
    );
  });

  test('only the official landing page gets the creator fallback', () {
    expect(
      creatorCenterWebLink(
        Uri.parse(
          invitation.replaceFirst(
            'www.bilibili.com',
            'www.bilibili.com.example.org',
          ),
        ),
      ),
      isNull,
    );
    expect(
      resolveWebLink(Uri.parse('bilibili://browser?url=javascript%3Aalert(1)')),
      isNull,
    );
    expect(
      resolveWebLink(Uri.parse('bilibili://browser?url=file%3A%2F%2F%2Fetc')),
      isNull,
    );
  });

  test('WKWebView cookies have an absolute HTTPS origin', () {
    expect(
      webCookieOrigin('.bilibili.com').toString(),
      'https://bilibili.com/',
    );
    expect(
      webCookieOrigin('passport.bilibili.com').host,
      'passport.bilibili.com',
    );
  });
}
