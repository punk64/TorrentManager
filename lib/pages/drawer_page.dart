import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../app/app_version.dart';
import '../app/page_style.dart';
import '../app/style_keys.dart';
import '../app/theme.dart';

import '../controllers/locale_controller.dart';
import '../controllers/theme_controller.dart';
import '../utils/app_log.dart';
import '../utils/file_export.dart';
import '../utils/i18n.dart';
import '../utils/formatter.dart';
import '../utils/theme_backup.dart';
import '../utils/update_check.dart';
import '../utils/startup_update.dart';
import '../widgets/filtered_image.dart';
import '../utils/strings.dart';

class DrawerMenu extends StatelessWidget {
  const DrawerMenu({super.key});

  static const double _childFontSize = 14;

  static const double _groupFontSize = 15;

  static Color get _fontColor => Get.find<ThemeController>().drawerFontColor;

  static Color get _titleColor => _fontColor;

  static Color get _itemColor => _fontColor.withValues(alpha: 0.87);

  static Color get _iconColor => _fontColor.withValues(alpha: 0.75);

  static Color get _subColor => _fontColor.withValues(alpha: 0.60);

  @override
  Widget build(BuildContext context) {
    final ThemeController tc = Get.find<ThemeController>();

    final LocaleController? lc = Get.isRegistered<LocaleController>()
        ? Get.find<LocaleController>()
        : null;
    final ThemeData theme = Theme.of(context);

    return Obx(() {
      tc.drawerFontColor;

      LocaleController.langRx.value;
      return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[

        Obx(() => _header(theme, tc)),

        _group(context, 
          title: S.groupTheme,
          leading: Icons.palette,
          initiallyExpanded: true,
          children: <Widget>[

            Obx(() => _button(context, 
                  icon: Icons.light_mode,
                  title: S.themeLight,
                  trailingCheck: tc.isBuiltinMode(1),
                  onTap: () => tc.applyBuiltinMode(1),
                )),
            Obx(() => _button(context, 
                  icon: Icons.dark_mode,
                  title: S.themeDark,
                  trailingCheck: tc.isBuiltinMode(2),
                  onTap: () => tc.applyBuiltinMode(2),
                )),

            Obx(() => _button(context, 
                  icon: Icons.color_lens,
                  title: S.themeCustom,
                  subtitle: '${S.themeCurrentPrefix}${tc.themeModeName}',
                  trailingCheck: tc.isCustomSelected,
                  onTap: () {
                    _push(context, '/theme');
                  },
                )),

            _dashedDivider(context),
            const _ThemeBackupButtons(),

            _PresetGroup(presets: lightPresets, tc: tc),

            _sectionLabel(context, S.themePresetWallpaperGroup),

            Obx(() => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final CustomTheme t in tc.customThemes)
                      _button(context,
                        leadingWidget: Container(
                          width: 30,
                          height: 30,
                          decoration: t.swatch,
                        ),
                        title: t.name,
                        subtitle: S.themeCustom,
                        trailingCheck: tc.isCustomThemeSelected(t),
                        onTap: () => tc.applyCustomTheme(t),

                        onLongPress: () => _customThemeMenu(context, tc, t),
                      ),
                  ],
                )),

            _PresetGroup(presets: wallpaperPresets, tc: tc),
          ],
        ),

        _group(context,
          title: S.langTitle,
          leading: Icons.translate,

          initiallyExpanded: true,
          children: <Widget>[

            Obx(() => _button(context,
                  icon: Icons.translate,
                  title: lc == null ? S.langZh : lc.currentName,
                  subtitle: S.langSwitchHint,
                  onTap: () => _pickLanguage(context),
                )),
          ],
        ),

        _group(context,
          title: S.groupShare,
          leading: Icons.ios_share,
          children: <Widget>[
            _button(context,
              icon: Icons.ios_share,
              title: S.groupShare,
              subtitle: S.shareSubtitle,
              onTap: () => _push(context, '/share'),
            ),
          ],
        ),

        _group(context, 
          title: S.aboutGroup,
          leading: Icons.contact_support,
          children: <Widget>[
            _button(context, 
              icon: Icons.mark_as_unread,
              title: S.termsTitle,

              onTap: () => Formatter.showTerms(context),
            ),
            _button(context, 
              icon: Icons.privacy_tip,
              title: S.privacyTitle,
              onTap: () => Formatter.showPrivacy(context),
            ),
            _button(context, 
              icon: Icons.source_outlined,
              title: S.openSourceTitle,
              subtitle: kProjectUrl,
              onTap: () => Formatter.showOpenSource(context),
            ),
          ],
        ),

        Divider(height: 12, color: _fontColor.withValues(alpha: 0.15)),

        ValueListenableBuilder<UpdateCheckResult?>(
          valueListenable: StartupUpdatePrompt.pendingNotifier,
          builder: (BuildContext _, UpdateCheckResult? pending, __) {
            final bool has = pending?.hasUpdate ?? false;
            final String? latest = pending?.latest;
            return _button(context, 
              icon: Icons.system_update_alt,
              title: has ? S.hasUpdate : S.aboutCheckUpdate,
              subtitle: has && latest != null && latest.isNotEmpty
                  ? 'V$latest'
                  : S.appVersionText(),
              onTap: () => has
                  ? StartupUpdatePrompt.showDetails(context)
                  : compareVersions(context),
            );
          },
        ),
        const SizedBox(height: 12),
      ],
      );
    });
  }

  Widget _menuImage(ImageProvider<Object> image, ThemeController tc) {
    return FilteredImage(
      image: image,
      brightness: tc.menuBgBrightness.value,
      fade: tc.menuBgFade.value.clamp(0.0, 1.0),
      blur: tc.menuBgBlur.value,

      fallback: const AssetImage(ThemeController.defaultMenuImage),
    );
  }

  Widget _header(ThemeData theme, ThemeController tc) {
    final bool customPanel =
        tc.panelColor.value != ThemeController.defaultPanelColor;
    final Color panelBase =
        customPanel || tc.bgModeValue != 0 ? tc.panelColor.value : tc.drawerBaseColor;
    final Color headerText = AppTheme.contrastOn(panelBase);
    final String? custom = tc.menuImagePath.value;

    final String path = (custom == null || custom.isEmpty)
        ? ThemeController.defaultMenuImage
        : custom;

    final ImageProvider<Object> image = ThemeController.imageProviderFor(path);

    return SizedBox(
      height: 150,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[

            _menuImage(image, tc),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[

                    Colors.black.withValues(alpha: 0.25),
                    panelBase.withValues(alpha: tc.panel1Alpha.value),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Text(

                    S.appNameLocalized,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: _groupFontSize,
                      fontWeight: FontWeight.bold,
                      height: 1.3,

                      color: headerText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    S.appVersionText(),
                    style: TextStyle(
                      fontSize: 9,
                      color: headerText.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 2),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.wallpaper,
            size: 14,
            color: _subColor,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: _groupFontSize - 4,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: _subColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(
    BuildContext context, {
    required String title,
    required IconData leading,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Theme(

      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        clipBehavior: Clip.antiAlias,
        initiallyExpanded: initiallyExpanded,

        leading: Icon(leading, size: 20, color: _iconColor),
        iconColor: _iconColor,
        collapsedIconColor: _iconColor,
        textColor: _titleColor,
        collapsedTextColor: _titleColor,
        title: Text(
          title,
          style: TextStyle(
            fontSize: _groupFontSize,
            fontWeight: FontWeight.bold,
            color: _titleColor,
          ),
        ),
        childrenPadding: const EdgeInsets.only(left: 12, bottom: 4),
        children: children,
      ),
    );
  }

  static Widget _button(
    BuildContext context, {
    IconData? icon,
    Widget? leadingWidget,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    bool trailingCheck = false,
    bool disabled = false,
    bool busy = false,
  }) {
    final bool inactive = disabled || busy;

    final double dim = inactive ? 0.38 : 1.0;
    final Widget tile = ListTile(
      dense: true,
      enabled: !inactive,
      leading: leadingWidget ??

          Icon(icon, size: 20, color: _iconColor.withValues(alpha: 0.75 * dim)),
      title: Text(title,
          style: TextStyle(
              fontSize: _childFontSize,
              color: _itemColor.withValues(alpha: 0.87 * dim))),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: TextStyle(
                  fontSize: 10, color: _subColor.withValues(alpha: 0.60 * dim)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,

                valueColor: AlwaysStoppedAnimation<Color>(_iconColor),
              ),
            )
          : (trailingCheck
              ? Icon(Icons.check,
                  size: 20, color: Theme.of(context).colorScheme.primary)
              : null),

      onTap: inactive ? null : onTap,
      onLongPress: onLongPress,
    );
    return busy ? Opacity(opacity: 0.6, child: tile) : tile;
  }

  static Widget _dashedDivider(BuildContext context) {
    final Color c = _fontColor.withValues(alpha: 0.3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints cts) {
          final int n = (cts.maxWidth / 8).floor().clamp(1, 200);
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(
              n,
              (_) => Container(width: 4, height: 0.5, color: c),
            ),
          );
        },
      ),
    );
  }

  static Future<void> _pickLanguage(BuildContext context) async {
    final LocaleController lc = Get.isRegistered<LocaleController>()
        ? Get.find<LocaleController>()
        : Get.put(LocaleController(), permanent: true);
    final bool isZh = !L.isEnglish;
    final String? picked = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => SimpleDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(S.langTitle, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              S.langDialogBody,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(L.zh),
            child: _langRow(ctx, isZh, S.langZh),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(L.en),
            child: _langRow(ctx, !isZh, S.langEn),
          ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    await lc.setLang(picked);
    if (context.mounted) Formatter.showToast(S.langSwitched);
  }

  static Widget _langRow(BuildContext ctx, bool selected, String label) {
    return Row(
      children: <Widget>[
        Icon(
          Icons.check,
          size: 18,
          color: selected
              ? Theme.of(ctx).colorScheme.primary
              : Colors.transparent,
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Future<void> _customThemeMenu(
    BuildContext context,
    ThemeController tc,
    CustomTheme t,
  ) async {
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => SimpleDialog(
        title: Text(t.name, style: const TextStyle(fontSize: 14)),
        children: <Widget>[

          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('edit'),
            child: Text(S.edit, style: const TextStyle(fontSize: 13)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('rename'),
            child: Text(S.renameTitle, style: const TextStyle(fontSize: 13)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('delete'),
            child: Text(S.delete,
                style: const TextStyle(fontSize: 13, color: Colors.red)),
          ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;

    if (action == 'edit') {
      tc.beginThemeEditing(load: t);

      await _push(context, '/theme');
      return;
    }

    if (action == 'delete') {
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: Text(S.deleteCustomThemeTitle,
              style: const TextStyle(fontSize: 14)),
          content: Text(S.deleteCustomThemeBody(t.name),
              style: const TextStyle(fontSize: 12)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(S.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(S.delete,
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (ok == true) {
        await tc.deleteCustomTheme(t.id);
        if (context.mounted) Formatter.showToast(S.deletedToast(t.name));
      }
      return;
    }

    final TextEditingController ctrl = TextEditingController(text: t.name);
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(S.renameTitle, style: const TextStyle(fontSize: 14)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(labelText: S.renameField),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(S.ok),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await tc.renameCustomTheme(t.id, name);
      if (context.mounted) Formatter.showToast(S.renamedToast(name));
    }
    ctrl.dispose();
  }

  static Widget _presetSwatch(
      BuildContext context, ThemePreset p, bool selected) {
    final BorderRadius br = BorderRadius.circular(AppTheme.radius);

    final Widget fill = p.bgImage == null
        ? DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  p.seed,

                  Color.lerp(p.seed, p.gradient2, 0.45) ?? p.seed,
                ],
              ),
            ),
          )
        : Image.asset(p.bgImage!, fit: BoxFit.cover, gaplessPlayback: true);
    return Container(
      width: 20,
      height: 20,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: br,
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary

              : _fontColor.withValues(alpha: 0.55),
          width: selected ? 2 : 1,
        ),
      ),

      child: fill,
    );
  }

  Future<void> _push(BuildContext context, String route) async {
    final ScaffoldState? scaffold = Scaffold.maybeOf(context);
    scaffold?.closeDrawer();

    await Future<void>.delayed(const Duration(milliseconds: 280));
    await Get.toNamed<dynamic>(route);
    scaffold?.openDrawer();
  }

  // ignore: unused_element
  Future<void> _showLink(
    BuildContext context,
    String title,
    String url, {
    String? note,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(note, style: const TextStyle(fontSize: 12)),
              ),
            SelectableText(url, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              Formatter.showToast(S.copyUrlHint);
            },
            child: Text(S.copyDone),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.ok),
          ),
        ],
      ),
    );
  }
}

class _ThemeBackupButtons extends StatefulWidget {
  const _ThemeBackupButtons();

  @override
  State<_ThemeBackupButtons> createState() => _ThemeBackupButtonsState();
}

class _ThemeBackupButtonsState extends State<_ThemeBackupButtons> {
  bool _exporting = false;
  bool _importing = false;

  bool get _busy => _exporting || _importing;

  ThemeController get _tc => Get.find<ThemeController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int n = _tc.customThemes.length;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DrawerMenu._button(
            context,
            icon: Icons.file_upload_outlined,
            title: _importing ? S.themeImporting : S.themeImport,
            subtitle: S.themeImportSub,
            busy: _importing,
            disabled: _exporting,
            onTap: _import,
          ),
          DrawerMenu._button(
            context,
            icon: Icons.file_download_outlined,
            title: _exporting ? S.themeExporting : S.themeExport,
            subtitle: n == 0
                ? S.themeExportEmpty
                : '${S.themeExportCountPrefix}$n${S.themeExportCountSuffix}',
            busy: _exporting,

            disabled: n == 0 || _importing,
            onTap: _export,
          ),
          if (_busy) const SizedBox(height: 4),
        ],
      );
    });
  }

  Future<void> _export() async {
    final ThemeController tc = _tc;
    if (tc.customThemes.isEmpty) {
      Formatter.showToast(S.themeExportEmpty, isError: true);
      return;
    }
    setState(() => _exporting = true);
    try {
      final int count = tc.customThemes.length;
      final String path = await FileExport.writeText(
        fileName: tc.exportPackFileName(),
        content: tc.buildExportPack(),
      );

      final String name = path.split(RegExp(r'[/\\]')).last;
      Formatter.showToast(
        '${S.themeExportOkPrefix}$count${S.themeExportOkInfix}$name',
      );
      AppLog.instance.op('导出主题配置：$name（共 $count 套）');
    } catch (e) {
      Formatter.showToast(
        '${S.themeExportFailedPrefix}${Formatter.safeErr(e)}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final PickedTextFile? file = await FileExport.pickText();
      if (file == null) {
        Formatter.showToast(S.themeImportCancelled);
        return;
      }
      if (!mounted) return;
      final ThemePackResult r = ThemeBackup.parse(file.content);

      for (final String s in r.skipped) {
        AppLog.instance.warn(s);
      }
      if (!r.ok) {
        await _showImportError(r.error!, r.hint);
        return;
      }
      final ThemePack pack = r.pack!;
      if (!mounted) return;

      final List<String> conflicts = _tc.conflictingNames(pack.themes);
      bool overwrite = true;
      if (conflicts.isNotEmpty) {
        final String? action = await _askConflict(conflicts.length);
        if (action == null) {
          Formatter.showToast(S.themeImportCancelled);
          return;
        }
        overwrite = action == 'overwrite';
      }

      final ThemeImportOutcome out =
          await _tc.applyImportedThemes(pack.themes, overwrite: overwrite);

      final CustomTheme? first = out.first;
      if (first != null) _tc.applyCustomTheme(first);

      Formatter.showToast(
        r.skipped.isEmpty
            ? S.themeImportOk(out.total)
            : S.themeImportPartial(out.total, r.skipped.length),
      );
    } catch (e) {
      Formatter.showToast(
        '${S.themeImportReadFailed}：${Formatter.safeErr(e)}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<String?> _askConflict(int n) => showDialog<String>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('主题同名', style: TextStyle(fontSize: 14)),
          content: Text(
            S.themeImportConflictBody(n),
            style: const TextStyle(fontSize: 12),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(S.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('both'),
              child: Text(S.themeImportKeepBoth),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('overwrite'),
              child: Text(S.themeImportOverwrite),
            ),
          ],
        ),
      );

  Future<void> _showImportError(String reason, String? hint) => showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: Text(
            reason,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(ctx).colorScheme.error,
            ),
          ),
          content: Text(
            hint ?? S.themeImportBadSourceHint,
            style: const TextStyle(fontSize: 12),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(S.ok),
            ),
          ],
        ),
      );
}

Future<void> compareVersions(BuildContext context) async {
  UpdateCheckResult? result;                 
  bool started = false;

  await showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => StatefulBuilder(
      builder: (BuildContext ctx, StateSetter setState) {
        if (!started) {
          started = true;

          unawaited(Future<void>.microtask(() async {
            final UpdateCheckResult r = await UpdateChecker().check();
            if (!ctx.mounted) return;
            if (r.status == UpdateCheckStatus.failed) {
              AppLog.instance.net('检查更新失败（按已是最新处理）：${r.reason}',
                  level: 'WARN');
            } else if (r.hasUpdate) {
              AppLog.instance.net('发现新版本 V${r.latest}（本地 V$kAppVersion）');
            }
            setState(() => result = r);
          }));
        }

        final UpdateCheckResult? r = result;
        return AlertDialog(
          title: Text(r != null && r.hasUpdate ? S.hasUpdate : S.aboutCheckUpdate),
          content: Text(
            r == null
                ? S.checkingUpdate
                : (r.hasUpdate
                    ? '${S.hasUpdate}: V${r.latest}\n${S.appVersionText()}'
                    : '${S.appVersionText()}（${S.noUpdate}）'),
            style: const TextStyle(fontSize: 12),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(S.ok),
            ),
          ],
        );
      },
    ),
  );
}

const int kPresetCollapsedCount = 2;

class _PresetGroup extends StatefulWidget {
  const _PresetGroup({
    required this.presets,
    required this.tc,
  });

  final List<ThemePreset> presets;
  final ThemeController tc;

  @override
  State<_PresetGroup> createState() => _PresetGroupState();
}

class _PresetGroupState extends State<_PresetGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bool collapsible = widget.presets.length > kPresetCollapsedCount;
    final List<ThemePreset> shown = (_expanded || !collapsible)
        ? widget.presets
        : widget.presets.take(kPresetCollapsedCount).toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final ThemePreset p in shown)
          Obx(() => DrawerMenu._button(
                context,
                leadingWidget: DrawerMenu._presetSwatch(
                    context, p, widget.tc.currentPreset.value == p.id),

                title: L.t(p.name),
                subtitle: L.t(p.descriptor),
                trailingCheck: widget.tc.currentPreset.value == p.id,
                onTap: () => widget.tc.applyPreset(p),
              )),
        if (collapsible)
          Obx(() => DrawerMenu._button(
                context,
                icon: _expanded ? Icons.expand_less : Icons.expand_more,
                title: _expanded ? S.themeShowLess : S.themeShowMore,
                onTap: () => setState(() => _expanded = !_expanded),
              )),
      ],
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController tc = Get.find<ThemeController>();
    return AppPageTheme(
      page: AppPageKey.drawer,
      applyCardBackground: true,

      child: Obx(() {
        final bool customBg = tc.pageColor(AppPageKey.drawer, AppStyleSlot.background) != null;
        final bool solid = tc.bgModeValue == 0;
        final Decoration? deco = (customBg || solid)
            ? null
            : BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[tc.gradient1, tc.gradient2],
                ),
              );
        return Container(
          decoration: deco,
          child: Drawer(
            backgroundColor: deco == null ? tc.drawerBaseColor : Colors.transparent,
            child: const SafeArea(child: DrawerMenu()),
          ),
        );
      }),
    );
  }
}

class DrawerPage extends StatelessWidget {
  const DrawerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.menuTitle)),
      body: const SafeArea(child: DrawerMenu()),
    );
  }
}
