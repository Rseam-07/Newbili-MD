/// Unwrap Bilibili's browser links without accepting executable URL schemes.
/// Uri.queryParameters already performs the one required URL decode.
Uri? resolveWebLink(Uri uri) {
  for (var depth = 0; depth < 4; depth++) {
    final creator = creatorCenterWebLink(uri);
    if (creator != null) return creator;
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return uri;
    }
    if (uri.scheme.isEmpty && uri.host.isNotEmpty) {
      return uri.replace(scheme: 'https');
    }
    if (!{'bilibili', 'newbili-md'}.contains(uri.scheme) ||
        !{'browser', 'webview'}.contains(uri.host)) {
      return null;
    }
    final target = uri.queryParameters['url'];
    if (target == null || target.isEmpty) return null;
    final nested = Uri.tryParse(target);
    if (nested == null || nested == uri) return null;
    uri = nested;
  }
  return null;
}

/// The official notification landing page waits indefinitely for
/// biliBridge.getContainerInfo outside the official app. Use the web fallback
/// declared by that same page, retaining the invitation's archive and role.
Uri? creatorCenterWebLink(Uri uri) {
  String? destination;
  if ((uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host == 'www.bilibili.com' &&
      uri.path == '/blackboard/era/4uNKuLdhsvPBAoe2.html') {
    destination =
        uri.queryParameters['legacy_jump'] ?? uri.queryParameters['new_jump'];
  } else if (uri.scheme == 'bilibili' && uri.host == 'uper') {
    destination = switch (uri.path) {
      '/join_up/cooperate' => 'staff',
      '/user_center/archive_list' => 'archive',
      _ => null,
    };
  }
  if (destination != 'staff' && destination != 'archive') return null;
  final query = <String, String>{'wbType': 'common'};
  final aid = uri.queryParameters['aid'];
  if (aid != null && RegExp(r'^\d+$').hasMatch(aid)) query['aid'] = aid;
  final owner = uri.queryParameters['is_owner'];
  if (owner == '0' || owner == '1') query['is_owner'] = owner!;
  return Uri(
    scheme: 'https',
    host: 'member.bilibili.com',
    path: '/v2',
    fragment:
        '/upload-manager/article${destination == 'staff' ? '/cooperation' : ''}?${Uri(queryParameters: query).query}',
  );
}

Uri webCookieOrigin(String? domain) => Uri(
  scheme: 'https',
  host: (domain == null || domain.isEmpty ? 'bilibili.com' : domain)
      .replaceFirst(RegExp(r'^\.'), ''),
  path: '/',
);
