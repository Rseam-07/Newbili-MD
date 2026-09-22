import 'dart:io' show Platform;

import 'package:PiliPlus/common/widgets/route_aware_mixin.dart'
    show routeObserver;
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/selection_text.dart';
import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/main.dart' show webViewEnvironment;
import 'package:PiliPlus/models/common/webview_menu_type.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/cache_manager.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/login_utils.dart';
import 'package:PiliPlus/utils/ios_file_download.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:PiliPlus/utils/web_link.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class WebviewPage extends StatefulWidget {
  const WebviewPage({
    super.key,
    this.url,
    this.oid,
    this.title,
    this.windowId,
  });

  final String? url;

  // note
  final int? oid;
  final String? title;
  final int? windowId;

  @override
  State<WebviewPage> createState() => _WebviewPageState();
}

class _WebviewPageState extends State<WebviewPage> with RouteAware {
  late final String _url;
  late final String userAgent;
  late final RxString _title;
  final RxDouble _progress = 1.0.obs;
  final RxnString _loadError = RxnString();
  bool _inApp = false;
  bool _off = false;

  InAppWebViewController? _webViewController;

  static final _prefixRegex = RegExp(
    r'^(?!(https?://))\S+://',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    final parameters = Get.parameters;
    final requested =
        (widget.url ?? parameters['url'] ?? 'about:blank').http2https;
    _url = resolveWebLink(Uri.parse(requested))?.toString() ?? requested;
    _title = _url.obs;
    userAgent = switch (parameters['uaType']) {
      'pc' => BrowserUa.pc,
      'mob' => BrowserUa.mob,
      _ => BrowserUa.platform,
    };
    if (Get.arguments case final Map map) {
      _inApp = map['inApp'] ?? false;
      _off = map['off'] ?? false;
    }

    if (Platform.isAndroid) {
      routeObserver.subscribe(this, Get.routing.route as GetPageRoute);
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) routeObserver.unsubscribe(this);
    _webViewController = null;
    super.dispose();
  }

  bool _isPop = false;

  Future<void> _loadPage() async {
    _loadError.value = null;
    _progress.value = 0;
    try {
      // WKWebView must receive the account cookies before the first request,
      // otherwise authenticated invitation pages redirect to a logged-out page.
      await LoginUtils.setWebCookie();
      if (!mounted || _webViewController == null) return;
      await _webViewController!.loadUrl(
        urlRequest: URLRequest(url: WebUri(_url)),
      );
    } catch (_) {
      if (!mounted) return;
      _progress.value = 1;
      _loadError.value = '网页暂时无法加载，请重试';
    }
  }

  @override
  void didPop() {
    setState(() {
      _webViewController = null;
      _isPop = true;
    });
    super.didPop();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isLinux) {
      return SimpleScaffold(
        appBar: AppBar(),
        body: Center(
          child: TextButton(
            onPressed: () => PageUtils.launchURL(_url),
            child: const Text('unsupported'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: widget.url != null && widget.windowId == null
          ? null
          : AppBar(
              title: Obx(
                () => Text(
                  _title.value.isNotEmpty ? _title.value : _url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: Size.zero,
                child: Obx(
                  () => _progress.value < 1
                      ? LinearProgressIndicator(value: _progress.value)
                      : const SizedBox.shrink(),
                ),
              ),
              actions: _isPop
                  ? null
                  : [
                      PopupMenuButton(
                        onSelected: (item) async {
                          switch (item) {
                            case WebviewMenuItem.refresh:
                              _loadError.value = null;
                              if (_webViewController != null) {
                                await _webViewController!.reload();
                              }
                              break;
                            case WebviewMenuItem.copy:
                              WebUri? uri = await _webViewController?.getUrl();
                              if (uri != null) {
                                Utils.copyText(uri.toString());
                              }
                              break;
                            case WebviewMenuItem.openInBrowser:
                              WebUri? uri = await _webViewController?.getUrl();
                              if (uri != null) {
                                PageUtils.launchURL(uri.toString());
                              }
                              break;
                            case WebviewMenuItem.clearCache:
                              try {
                                await InAppWebViewController.clearAllCache();
                                await _webViewController?.clearHistory();
                                SmartDialog.showToast('已清理');
                              } catch (e) {
                                SmartDialog.showToast(e.toString());
                              }
                              break;
                            case WebviewMenuItem.goBack:
                              if (await _webViewController?.canGoBack() ==
                                  true) {
                                _webViewController?.goBack();
                              } else {
                                Get.back();
                              }
                              break;
                            case WebviewMenuItem.resetCookie:
                              await LoginUtils.setWebCookie();
                              SmartDialog.showToast('设置成功，刷新或重新打开网页');
                              break;
                          }
                        },
                        itemBuilder: (context) =>
                            <PopupMenuEntry<WebviewMenuItem>>[
                              ...WebviewMenuItem.values
                                  .take(WebviewMenuItem.values.length - 1)
                                  .map(
                                    (item) => PopupMenuItem(
                                      value: item,
                                      child: Text(item.title),
                                    ),
                                  ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: WebviewMenuItem.goBack,
                                child: Text(
                                  WebviewMenuItem.goBack.title,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                      ),
                    ],
            ),
      body: _isPop
          ? null
          : SafeArea(
              child: Stack(
                children: [
                  InAppWebView(
                    windowId: widget.windowId,
                    webViewEnvironment: webViewEnvironment,
                    initialSettings: InAppWebViewSettings(
                      clearCache: true,
                      javaScriptEnabled: true,
                      javaScriptCanOpenWindowsAutomatically: true,
                      supportMultipleWindows: true,
                      domStorageEnabled: true,
                      sharedCookiesEnabled: true,
                      forceDark: ForceDark.AUTO,
                      useHybridComposition: true,
                      algorithmicDarkeningAllowed: true,
                      useShouldOverrideUrlLoading: true,
                      useOnDownloadStart: true,
                      userAgent: userAgent,
                      mixedContentMode:
                          MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    ),
                    onWebViewCreated: (InAppWebViewController controller) {
                      _webViewController = controller
                        ..addJavaScriptHandler(
                          handlerName: 'finishButtonClicked',
                          callback: (args) {
                            Get.back();
                          },
                        )
                        ..addJavaScriptHandler(
                          handlerName: 'infoBarClicked',
                          callback: (args) async {
                            WebUri? uri = await controller.getUrl();
                            if (uri != null) {
                              String? oid = uri.queryParameters['oid'];
                              if (oid != null) {
                                PiliScheme.videoPush(int.parse(oid), null);
                              }
                            }
                          },
                        );
                      if (widget.windowId == null) _loadPage();
                    },
                    onCreateWindow: (controller, action) async {
                      if (!mounted) return false;
                      Get.to(
                        () => WebviewPage(
                          url: action.request.url?.toString() ?? 'about:blank',
                          windowId: action.windowId,
                        ),
                        preventDuplicates: false,
                      );
                      return true;
                    },
                    onLoadStart: (controller, uri) {
                      _loadError.value = null;
                      _progress.value = 0;
                    },
                    onReceivedError: (controller, request, error) {
                      if (request.isForMainFrame != true ||
                          error.type.toNativeValue() == -999) {
                        return;
                      }
                      _progress.value = 1;
                      _loadError.value = '网页加载失败，请检查网络后重试';
                    },
                    onReceivedHttpError: (controller, request, response) {
                      if (request.isForMainFrame != true) return;
                      _progress.value = 1;
                      _loadError.value =
                          '网页暂时不可用（${response.statusCode}），请稍后重试';
                    },
                    onProgressChanged: (controller, progress) {
                      _progress.value = progress / 100;
                    },
                    onTitleChanged: (controller, title) {
                      _title.value = title ?? '';
                    },
                    onCloseWindow: (controller) => Get.back(),
                    onLoadStop: (controller, uri) {
                      final url = uri.toString();
                      if (url.startsWith(
                        'https://www.bilibili.com/h5/note-app',
                      )) {
                        controller
                          ..evaluateJavascript(
                            source: """
document.querySelector('.finish-btn').addEventListener('click', function() {
    window.flutter_inappwebview.callHandler('finishButtonClicked');
});
""",
                          )
                          ..evaluateJavascript(
                            source: """
document.querySelector('.info-bar').addEventListener('click', function() {
    window.flutter_inappwebview.callHandler('infoBarClicked');
});
""",
                          );
                      } else if (url.startsWith('https://live.bilibili.com')) {
                        controller.evaluateJavascript(
                          source: '''
document.styleSheets[0].insertRule('div.open-app-btn.bili-btn-warp {display:none;}', 0);
document.styleSheets[0].insertRule('#app__display-area > div.control-panel {display:none;}', 0);
                  ''',
                        );
                      }
                      // _webViewController?.evaluateJavascript(
                      //   source: '''
                      //     document.querySelector('#internationalHeader').remove();
                      //     document.querySelector('#message-navbar').remove();
                      //   ''',
                      // );
                    },
                    onDownloadStartRequest:
                        (Platform.isAndroid || Platform.isIOS)
                        ? (controller, request) {
                            showDialog(
                              context: context,
                              builder: (context) {
                                String suggestedFilename = webDownloadFilename(
                                  Uri.parse(request.url.toString()),
                                  request.suggestedFilename,
                                );
                                final fileSize = CacheManager.formatSize(
                                  request.contentLength,
                                );
                                try {
                                  suggestedFilename = Uri.decodeComponent(
                                    suggestedFilename,
                                  );
                                } catch (e) {
                                  if (kDebugMode) debugPrint(e.toString());
                                }
                                final url = request.url.toString();
                                return AlertDialog(
                                  title: Text(
                                    '下载文件: $suggestedFilename ?',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  content: SelectionText(url),
                                  actions: [
                                    TextButton(
                                      onPressed: Get.back,
                                      child: Text(
                                        '取消',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Get.back();
                                        if (Platform.isIOS) {
                                          try {
                                            final cookies =
                                                await CookieManager.instance()
                                                    .getCookies(
                                                      url: request.url,
                                                    );
                                            await IosFileDownload.save(
                                              url: Uri.parse(url),
                                              filename: suggestedFilename,
                                              userAgent: userAgent,
                                              cookie: cookies
                                                  .map(
                                                    (c) =>
                                                        '${c.name}=${c.value}',
                                                  )
                                                  .join('; '),
                                            );
                                          } catch (_) {
                                            SmartDialog.showToast('无法开始下载，请重试');
                                          }
                                        } else {
                                          PageUtils.launchURL(url);
                                        }
                                      },
                                      child: Text('确定 ($fileSize)'),
                                    ),
                                  ],
                                );
                              },
                            );
                            _progress.value = 1;
                          }
                        : null,
                    shouldInterceptAjaxRequest:
                        (controller, ajaxRequest) async {
                          String url = ajaxRequest.url.toString();
                          if (url.startsWith('//api.bilibili.com/x/note/add') &&
                              widget.title != null) {
                            return ajaxRequest
                              ..data = ajaxRequest.data.toString().replaceFirst(
                                '&title=--&',
                                '&title=${widget.title}&',
                              );
                          }
                          return null;
                        },
                    shouldOverrideUrlLoading:
                        (controller, navigationAction) async {
                          final uri = navigationAction.request.url?.uriValue;
                          if (uri == null) return .CANCEL;
                          // Subframes belong to their page and must not push app routes.
                          if (!navigationAction.isForMainFrame) {
                            return .ALLOW;
                          }
                          final web = resolveWebLink(uri);
                          if (web != null && web != uri) {
                            await controller.loadUrl(
                              urlRequest: URLRequest(url: WebUri.uri(web)),
                            );
                            return .CANCEL;
                          }
                          if (uri.scheme == 'about' || uri.scheme == 'blob') {
                            return .ALLOW;
                          }
                          if (!_inApp) {
                            final hasMatch = await PiliScheme.routePush(
                              navigationAction.request.url?.uriValue ?? Uri(),
                              selfHandle: true,
                              off: _off,
                            );
                            // if (kDebugMode) debugPrint('webview: [$url], [$hasMatch]');
                            if (hasMatch) {
                              _progress.value = 1;
                              return .CANCEL;
                            }
                          }
                          final url = navigationAction.request.url.toString();
                          if (_prefixRegex.hasMatch(url)) {
                            if (context.mounted) {
                              final snackBar = SnackBar(
                                persist: false,
                                showCloseIcon: true,
                                content: const Text('当前网页将要打开外部链接，是否打开'),
                                action: SnackBarAction(
                                  label: '打开',
                                  onPressed: () => PageUtils.launchURL(url),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            }
                            _progress.value = 1;
                            return .CANCEL;
                          }

                          return .ALLOW;
                        },
                  ),
                  Obx(() {
                    final error = _loadError.value;
                    if (error == null) return const SizedBox.shrink();
                    return Positioned.fill(
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.surface,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cloud_off_rounded, size: 40),
                                const SizedBox(height: 16),
                                Text(error, textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _loadPage,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('重新加载'),
                                ),
                                TextButton(
                                  onPressed: () => PageUtils.launchURL(_url),
                                  child: const Text('在浏览器中打开'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
