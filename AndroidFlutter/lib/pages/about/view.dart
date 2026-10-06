import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/build_config.dart';
import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/common/widgets/dialog/export_import.dart';
import 'package:PiliPlus/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/setting/cache_page.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/android/android_helper.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/cache_manager.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/login_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/update.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, this.showAppBar = true, this.loadCacheSize});

  final bool showAppBar;
  final Future<int> Function()? loadCacheSize;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final currentVersion =
      '${BuildConfig.versionName}+${BuildConfig.versionCode}';
  RxString cacheSize = ''.obs;

  late int _pressCount = 0;

  @override
  void initState() {
    super.initState();
    getCacheSize();
  }

  @override
  void dispose() {
    cacheSize.close();
    super.dispose();
  }

  void getCacheSize() {
    (widget.loadCacheSize ?? CacheManager.loadApplicationCache)()
        .then((res) {
          if (mounted) {
            cacheSize.value = CacheManager.formatSize(res);
          }
        })
        .catchError((Object _) {
          if (mounted) cacheSize.value = '暂时无法读取';
        });
  }

  void _showDialog() => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      constraints: Style.dialogFixedConstraints,
      content: TextField(
        autofocus: true,
        onSubmitted: (value) {
          Get.back();
          if (value.isNotEmpty) {
            PiliScheme.routePushFromUrl(value);
          }
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const style = TextStyle(fontSize: 15);
    final outline = theme.colorScheme.outline;
    final subTitleStyle = TextStyle(fontSize: 13, color: outline);
    final showAppBar = widget.showAppBar;
    final padding = MediaQuery.viewPaddingOf(context);
    return SimpleScaffold(
      appBar: showAppBar ? AppBar(title: const Text('关于')) : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: EdgeInsets.only(
              left: padding.left + 16,
              right: padding.right + 16,
              bottom: padding.bottom + 100,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (++_pressCount == 5) {
                          _pressCount = 0;
                          _showDialog();
                        }
                      },
                      child: Image.asset(
                        Assets.logo,
                        width: 96,
                        height: 96,
                        cacheWidth: 96.cacheSize(context),
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      Constants.appName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '用 Material Design，发现喜欢的内容',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '面向 Android、iPhone 与 iPad 的 B 站第三方客户端',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: outline,
                      ),
                    ),
                  ],
                ),
              ),
              NewbiliFormSection(
                title: '版本',
                children: [
                  ListTile(
                    onTap: () => Update.checkUpdate(false),
                    onLongPress: () => Utils.copyText(currentVersion),
                    onSecondaryTap: PlatformUtils.isMobile
                        ? null
                        : () => Utils.copyText(currentVersion),
                    title: const Text('当前版本'),
                    leading: const Icon(Icons.commit_outlined),
                    trailing: Text(
                      currentVersion,
                      style: subTitleStyle,
                    ),
                  ),
                  if (BuildConfig.buildTime > 0 ||
                      BuildConfig.commitHash != 'N/A')
                    NewbiliSettingsRow(
                      title: '构建信息',
                      icon: Icons.info_outline,
                      subtitle: [
                        if (BuildConfig.buildTime > 0)
                          DateFormatUtils.format(
                            BuildConfig.buildTime,
                            format: DateFormatUtils.longFormatDs,
                          ),
                        if (BuildConfig.commitHash != 'N/A')
                          BuildConfig.commitHash,
                      ].join(' · '),
                      onTap: BuildConfig.commitHash == 'N/A'
                          ? null
                          : () => PageUtils.launchURL(
                              '${Constants.sourceCodeUrl}/commit/${BuildConfig.commitHash}',
                            ),
                    ),
                ],
              ),
              NewbiliFormSection(
                title: '项目与支持',
                children: [
                  NewbiliSettingsRow(
                    title: '官方网站',
                    icon: Icons.language_rounded,
                    subtitle: '介绍、安装说明与更新日志',
                    onTap: () =>
                        PageUtils.launchURL('https://rseam-07.github.io/'),
                  ),
                  NewbiliSettingsRow(
                    title: '下载与更新日志',
                    icon: Icons.system_update_rounded,
                    subtitle: 'Android 与 iOS 版本',
                    onTap: () => PageUtils.launchURL(
                      'https://rseam-07.github.io/downloads/',
                    ),
                  ),
                  ListTile(
                    onTap: () => PageUtils.launchURL(Constants.sourceCodeUrl),
                    leading: const Icon(Icons.code),
                    title: const Text('源代码'),
                    subtitle: Text(
                      Constants.sourceCodeUrl,
                      style: subTitleStyle,
                    ),
                  ),
                  if (Platform.isAndroid)
                    ListTile(
                      onTap: PiliAndroidHelper.openLinkVerifySettings,
                      leading: const Icon(MdiIcons.linkBoxOutline),
                      title: const Text('打开受支持的链接'),
                      trailing: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: outline,
                      ),
                    ),
                  ListTile(
                    onTap: () => PageUtils.launchURL(
                      '${Constants.sourceCodeUrl}/issues',
                    ),
                    leading: const Icon(Icons.feedback_outlined),
                    title: const Text('问题反馈'),
                    trailing: Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: outline,
                    ),
                  ),
                  ListTile(
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: Constants.appName,
                      applicationVersion: currentVersion,
                    ),
                    leading: const Icon(Icons.balance_outlined),
                    title: const Text('开源许可'),
                    subtitle: Text('查看 Flutter 与第三方组件许可', style: subTitleStyle),
                    trailing: Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: outline,
                    ),
                  ),
                ],
              ),
              NewbiliFormSection(
                title: '存储与诊断',
                children: [
                  ListTile(
                    onTap: () => Get.toNamed('/logs'),
                    onLongPress: LoggerUtils.clearLogs,
                    onSecondaryTap: PlatformUtils.isMobile
                        ? null
                        : LoggerUtils.clearLogs,
                    leading: const Icon(Icons.bug_report_outlined),
                    title: const Text('错误日志'),
                    subtitle: Text('长按清除日志', style: subTitleStyle),
                    trailing: Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: outline,
                    ),
                  ),
                  ListTile(
                    onTap: () async {
                      await Get.to(() => const CacheSettingsPage());
                      if (mounted) getCacheSize();
                    },
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('存储与缓存'),
                    subtitle: Obx(
                      () => Text(
                        '图片与临时文件 ${cacheSize.value}',
                        style: subTitleStyle,
                      ),
                    ),
                  ),
                ],
              ),
              NewbiliFormSection(
                title: '数据与设置',
                children: [
                  ListTile(
                    title: const Text('导入/导出登录信息'),
                    leading: const Icon(Icons.import_export_outlined),
                    onTap: () => showImportExportDialog<Map>(
                      context,
                      title: '登录信息',
                      localFileName: () => 'account',
                      onExport: () =>
                          Utils.jsonEncoder.convert(Accounts.account.toMap()),
                      onImport: (json) async {
                        final res = json.map(
                          (key, value) =>
                              MapEntry(key, LoginAccount.fromJson(value)),
                        );
                        await Accounts.account.putAll(res);
                        await Accounts.refresh();
                        MineController.anonymity.value =
                            !Accounts.heartbeat.isLogin;
                        if (Accounts.main.isLogin) {
                          await LoginUtils.onLoginMain();
                        }
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('导入/导出设置'),
                    dense: false,
                    leading: const Icon(Icons.import_export_outlined),
                    onTap: () => showImportExportDialog<Map<String, dynamic>>(
                      context,
                      title: '设置',
                      localFileName: () =>
                          'setting_${DeviceUtils.platformName}',
                      onExport: GStorage.exportAllSettings,
                      onImport: GStorage.importAllJsonSettings,
                    ),
                  ),
                  ListTile(
                    title: const Text('重置所有设置'),
                    leading: const Icon(Icons.settings_backup_restore_outlined),
                    onTap: () => showDialog(
                      context: context,
                      builder: (context) {
                        return SimpleDialog(
                          clipBehavior: Clip.hardEdge,
                          title: const Text('是否重置所有设置？'),
                          children: [
                            DialogOption(
                              onPressed: () async {
                                Get.back();
                                await Future.wait([
                                  GStorage.setting.clear(),
                                  GStorage.video.clear(),
                                ]);
                                SmartDialog.showToast('重置成功');
                              },
                              child: const Text('重置可导出的设置', style: style),
                            ),
                            DialogOption(
                              onPressed: () async {
                                Get.back();
                                await GStorage.clear();
                                SmartDialog.showToast('重置成功');
                              },
                              child: const Text('重置所有数据（含登录信息）', style: style),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
