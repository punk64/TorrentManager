library;

import '../utils/i18n.dart';

enum AppPageKey {
  drawer,
  serverList,
  serverCard,
  torrentList,
  torrentCard,
  torrentDetail,
  settings,
  log,
  logQb,
}

enum AppStyleSlot {
  background,

  title,

  text;

  String get shortName => name;
}

class PageStyleSpec {
  const PageStyleSpec({
    required this.key,
    required this.title,
    this.backgroundLabel,
    this.titleLabel,
    this.textLabel,
    this.help,
  });

  final AppPageKey key;

  final String title;

  final String? backgroundLabel;
  final String? titleLabel;
  final String? textLabel;

  final String? help;

  String slotKey(AppStyleSlot slot) =>
      'torrentmanager.pageStyle.${key.name}.${slot.shortName}';

  List<AppStyleSlot> get slots => <AppStyleSlot>[
        if (backgroundLabel != null) AppStyleSlot.background,
        if (titleLabel != null) AppStyleSlot.title,
        if (textLabel != null) AppStyleSlot.text,
      ];

  String labelOf(AppStyleSlot slot) {
    switch (slot) {
      case AppStyleSlot.background:
        return L.t(backgroundLabel ?? '背景');
      case AppStyleSlot.title:
        return L.t(titleLabel ?? '标题颜色');
      case AppStyleSlot.text:
        return L.t(textLabel ?? '文字颜色');
    }
  }

  String get titleLocalized => L.t(title);

  String? get helpLocalized => help == null ? null : L.t(help!);
}

const List<PageStyleSpec> kPageStyles = <PageStyleSpec>[
  PageStyleSpec(
    key: AppPageKey.drawer,
    title: '抽屉菜单',
    backgroundLabel: '抽屉背景',
    textLabel: '抽屉文字',
    help: '抽屉顶部图片的选取见下方「抽屉顶部图片」。',
  ),
  PageStyleSpec(
    key: AppPageKey.serverList,
    title: '服务器页',
    backgroundLabel: '页面背景',
    titleLabel: '标题颜色',
    textLabel: '文字颜色',
  ),
  PageStyleSpec(
    key: AppPageKey.serverCard,
    title: '服务器卡片',
    backgroundLabel: '卡片背景',
    textLabel: '卡片文字',
  ),
  PageStyleSpec(
    key: AppPageKey.torrentList,
    title: '种子列表页',
    backgroundLabel: '页面背景',
    titleLabel: '标题颜色',
    textLabel: '文字颜色',
  ),
  PageStyleSpec(
    key: AppPageKey.torrentCard,
    title: '种子卡片',
    backgroundLabel: '卡片背景',
    textLabel: '卡片文字',
  ),
  PageStyleSpec(
    key: AppPageKey.torrentDetail,
    title: '种子详情页',
    backgroundLabel: '页面背景',
    textLabel: '文字颜色',
  ),
  PageStyleSpec(
    key: AppPageKey.settings,
    title: '设置页',
    backgroundLabel: '页面背景',
    textLabel: '文字颜色',
  ),
  PageStyleSpec(
    key: AppPageKey.log,
    title: '日志',
    backgroundLabel: '页面背景',
    textLabel: '文字颜色',
  ),
  PageStyleSpec(
    key: AppPageKey.logQb,
    title: '服务器日志',
    backgroundLabel: '页面背景',
    textLabel: '文字颜色',
  ),
];

PageStyleSpec specOf(AppPageKey key) => kPageStyles.firstWhere(
      (PageStyleSpec e) => e.key == key,
      orElse: () => PageStyleSpec(key: key, title: ''),
    );
